#!/usr/bin/env python3
"""Launch, inspect, or gracefully stop a prepared exponential C++ run."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import time
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys


def write_json(path, value):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def now():
    return datetime.now(timezone.utc).isoformat()


def running(state):
    pid = state.get("pid")
    if not pid or state.get("status") != "running":
        return False
    result = subprocess.run(["ps", "-p", str(pid), "-o", "command="], capture_output=True, text=True)
    return result.returncode == 0 and state["runner"] in result.stdout and state.get("activeRequest", state["request"]) in result.stdout


def monitor(directory, final=False):
    folder = str(Path(__file__).resolve().parent).replace("'", "''")
    target = str(directory).replace("'", "''")
    expression = f"addpath('{folder}'); MonitorEddyTideExponentialRun('{target}',snapshots={'true' if final else 'false'});"
    subprocess.run(["matlab", "-batch", expression], check=True, stdin=subprocess.DEVNULL)


def segment_targets(final_time, segment_seconds, completed):
    if not segment_seconds:
        return [final_time] if completed < final_time else []
    first = math.floor(completed / segment_seconds) + 1
    return [min(i * segment_seconds, final_time) for i in range(first, math.ceil(final_time / segment_seconds) + 1)]


def supervise(directory):
    state_path = directory / "process.json"
    state = json.loads(state_path.read_text())
    stop = directory / ".run.lock/stop"
    timings_path = directory / "segments.json"
    timings = json.loads(timings_path.read_text()) if timings_path.exists() else []
    state["supervisorPid"] = os.getpid()
    try:
        request = json.loads(Path(state["request"]).read_text())
        segmented = bool(state.get("segmentSeconds"))
        completed = 0
        if segmented:
            state.update(status="monitoring", pid=None)
            write_json(state_path, state)
            monitor(directory)
            completed = json.loads((directory / "energy.json").read_text())["completedDay"] * 86400
        for target in segment_targets(state["finalTime"], state.get("segmentSeconds"), completed):
            if stop.exists():
                break
            stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
            report_path = directory / (f"segment-{target / 86400:g}-{stamp}-report.json" if segmented else "run-report.json")
            active_request = Path(state["request"])
            if segmented:
                request["integration"]["finalTime"] = target
                request["report"] = str(report_path)
                active_request = directory / f"segment-{target / 86400:g}-{stamp}.json"
                write_json(active_request, request)
            started = time.monotonic()
            with subprocess.Popen([state["runner"], "--request", str(active_request)], stdin=subprocess.DEVNULL) as process:
                state.update(pid=process.pid, activeRequest=str(active_request), status="running", targetDay=target/86400)
                write_json(state_path, state)
                signaled = False
                while True:
                    if stop.exists() and not signaled and process.poll() is None:
                        process.send_signal(signal.SIGINT)
                        signaled = True
                    try:
                        code = process.wait(timeout=1)
                        break
                    except subprocess.TimeoutExpired:
                        pass
            report = json.loads(report_path.read_text())
            state.update(pid=None, exitCode=code, reportStatus=report.get("status"), latestReport=str(report_path))
            if code or report.get("status") != "complete":
                state["status"] = "paused" if stop.exists() or report.get("status") == "stopped" else "failed"
                break
            integrator = report["integrator"]
            policy = report["variableKernelPolicy"]
            if (report["provider"]["id"] != "native-fftw" or integrator["id"] != "adaptive-rk78"
                    or integrator["relativeTolerance"] != 1e-3 or integrator["absoluteTolerance"] != 1e-6
                    or policy["selection"] != "compact-native-accelerate"
                    or policy["horizontalSchedule"] != "streaming-pruned-tile16" or not policy["noFallback"]):
                raise RuntimeError("Native execution settings differ from the pinned optimized defaults.")
            if report["state"]["finalTime"] != target:
                raise RuntimeError("Segment did not reach its requested boundary.")
            if segmented:
                state["status"] = "monitoring"
                write_json(state_path, state)
                monitor(directory, final=target == 600*86400)
                timings.append(dict(initialTime=report["state"]["initialTime"], finalTime=target, wallSeconds=time.monotonic()-started, report=str(report_path), finishedAt=now()))
                write_json(timings_path, timings)
                elapsed = sum(item["wallSeconds"] for item in timings)
                simulated = sum(item["finalTime"]-item["initialTime"] for item in timings)
                remaining = (state["finalTime"]-target)*elapsed/simulated
                state.update(completedDay=target/86400, estimatedRemainingSeconds=remaining, estimatedFinish=datetime.fromtimestamp(time.time()+remaining, timezone.utc).isoformat())
            state["status"] = "finished" if target == state["finalTime"] else "between-segments"
            write_json(state_path, state)
        if stop.exists():
            state["status"] = "paused"
        elif completed >= state["finalTime"]:
            reports = [json.loads(path.read_text()) for path in directory.glob("segment-*-report.json")]
            if not any(report.get("status") == "complete" and report.get("state", {}).get("finalTime") == state["finalTime"] for report in reports):
                raise RuntimeError("Final checkpoint has no successful final execution report.")
            if state["finalTime"] == 600*86400:
                monitor(directory, final=True)
            state["status"] = "finished"
        state["finishedAt"] = now()
        write_json(state_path, state)
    except Exception as error:
        state.update(status="failed", error=str(error), finishedAt=now(), pid=None)
        write_json(state_path, state)
        raise
    finally:
        stop.unlink(missing_ok=True)
        (directory / ".run.lock").rmdir()


def main():
    default_directory = Path(__file__).resolve().parents[1] / "model-output/exponential-Nxy256-depth4000-shift0"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["start", "status", "stop", "_run"])
    parser.add_argument("directory", nargs="?", type=Path, default=default_directory)
    parser.add_argument("--segment-days", type=float, default=0, help="Integrate and monitor in segments; default is uninterrupted.")
    args = parser.parse_args()
    if not math.isfinite(args.segment_days) or args.segment_days < 0 or args.segment_days % 0.25:
        parser.error("segment-days must be a nonnegative multiple of 0.25")
    directory = args.directory.resolve()
    state_path = directory / "process.json"
    if args.action == "_run":
        supervise(directory)
        return
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    if args.action == "status":
        print(json.dumps(state or {"status": "not launched"}, indent=2))
        energy = directory / "energy.json"
        if energy.exists():
            print(energy.read_text())
        if running(state):
            subprocess.run(["ps", "-p", str(state["pid"]), "-o", "pid=,etime=,%cpu=,rss=,command="])
        output = directory / "eddy-tide-exponential.nc"
        if output.exists():
            print(f"Model file: {output.stat().st_size / 2**30:.3f} GiB")
        if (directory / ".run.lock").exists() and not running(state):
            print("Run lock is present; the supervisor may be starting or needs inspection.")
        return
    if args.action == "stop":
        if not (directory / ".run.lock").exists():
            raise RuntimeError("No run lock exists.")
        (directory / ".run.lock/stop").touch()
        print("Requested graceful stop at a complete checkpoint; wait for the runner to exit.")
        return

    provenance = json.loads((directory / "provenance.json").read_text())
    environment = provenance["environment"]
    runner = Path(environment["runner"])
    source = environment["modelSource"]
    commit = subprocess.check_output(["git", "-C", source, "rev-parse", "HEAD"], text=True).strip()
    changes = subprocess.check_output(["git", "-C", source, "status", "--porcelain", "--untracked-files=no"], text=True).strip()
    if commit != environment["modelCommit"] or changes:
        raise RuntimeError("The pinned model checkout has changed; refusing to launch.")
    if hashlib.sha256(runner.read_bytes()).hexdigest() != environment["runnerSHA256"]:
        raise RuntimeError("The native executable differs from the prepared run's provenance.")
    request_path = directory / "run.json"
    request = json.loads(request_path.read_text())
    if request["integration"]["finalTime"] <= 0:
        raise RuntimeError("Invalid final time.")
    report = directory / "run-report.json"
    if report.exists():
        previous = json.loads(report.read_text())
        if previous.get("state", {}).get("finalTime", -1) >= request["integration"]["finalTime"]:
            raise RuntimeError("The requested final time has already been reached; prepare a later maxT to extend it.")
    records = 1 + request["integration"]["finalTime"] / provenance["configuration"]["outputInterval"]
    estimated_size = records * provenance["resolved"]["coefficientBytesPerRecord"]
    existing_size = (directory / "eddy-tide-exponential.nc").stat().st_size
    required_space = max(0, 1.25 * estimated_size - existing_size) + 20 * 2**30
    if shutil.disk_usage(directory).free < required_space:
        raise RuntimeError(f"Need at least {required_space / 2**30:.1f} GiB free, including output overhead and reserve.")
    lock = directory / ".run.lock"
    lock.mkdir()  # Atomic exclusion of duplicate launches and preparation.
    try:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        log = directory / f"integration-{stamp}.log"
        state = dict(segmentSeconds=args.segment_days*86400, status="starting", startedAt=now(), runner=str(runner), request=str(request_path), log=str(log), finalTime=request["integration"]["finalTime"], requestSHA256=hashlib.sha256(request_path.read_bytes()).hexdigest(), runnerSHA256=environment["runnerSHA256"])
        state["scriptSHA256"] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in [Path(__file__).resolve(), Path(__file__).with_name("MonitorEddyTideExponentialRun.m")]}
        write_json(state_path, state)
        if report.exists():
            report.rename(directory / f"previous-report-{stamp}.json")
        with log.open("w") as stream:
            supervisor = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "_run", str(directory)], stdin=subprocess.DEVNULL, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        print(f"Started supervisor PID {supervisor.pid}. Log: {log}")
    except Exception:
        lock.rmdir()
        raise


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))

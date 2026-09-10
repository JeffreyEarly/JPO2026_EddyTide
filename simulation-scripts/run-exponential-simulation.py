#!/usr/bin/env python3
"""Launch, inspect, or gracefully stop a prepared exponential C++ run."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
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
    return result.returncode == 0 and state["runner"] in result.stdout and state["request"] in result.stdout


def supervise(directory):
    state_path = directory / "process.json"
    state = json.loads(state_path.read_text())
    try:
        with subprocess.Popen([state["runner"], "--request", state["request"]], stdin=subprocess.DEVNULL) as process:
            state.update(pid=process.pid, supervisorPid=os.getpid(), status="running")
            write_json(state_path, state)
            state["exitCode"] = process.wait()
        state.update(status="finished", finishedAt=now())
        report = directory / "run-report.json"
        if report.exists():
            state["reportStatus"] = json.loads(report.read_text()).get("status")
        write_json(state_path, state)
    except Exception as error:
        state.update(status="failed", error=str(error), finishedAt=now())
        write_json(state_path, state)
        raise
    finally:
        (directory / ".run.lock").rmdir()


def main():
    default_directory = Path(__file__).resolve().parents[1] / "model-output/exponential-Nxy256-depth4000-shift0"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["start", "status", "stop", "_run"])
    parser.add_argument("directory", nargs="?", type=Path, default=default_directory)
    args = parser.parse_args()
    directory = args.directory.resolve()
    state_path = directory / "process.json"
    if args.action == "_run":
        supervise(directory)
        return
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    if args.action == "status":
        print(json.dumps(state or {"status": "not launched"}, indent=2))
        if running(state):
            subprocess.run(["ps", "-p", str(state["pid"]), "-o", "pid=,etime=,%cpu=,rss=,command="])
        output = directory / "eddy-tide-exponential.nc"
        if output.exists():
            print(f"Model file: {output.stat().st_size / 2**30:.3f} GiB")
        if (directory / ".run.lock").exists() and not running(state):
            print("Run lock is present; the supervisor may be starting or needs inspection.")
        return
    if args.action == "stop":
        if not running(state):
            raise RuntimeError("No matching native runner is active.")
        os.kill(state["pid"], signal.SIGINT)
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
        state = dict(status="starting", startedAt=now(), runner=str(runner), request=str(request_path), log=str(log), finalTime=request["integration"]["finalTime"], requestSHA256=hashlib.sha256(request_path.read_bytes()).hexdigest(), runnerSHA256=environment["runnerSHA256"])
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

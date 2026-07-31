#!/usr/bin/env bash
set -u

SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_PATH="$SCRIPT_DIRECTORY/$(basename -- "${BASH_SOURCE[0]}")"
REPOSITORY_ROOT=$(cd -- "$SCRIPT_DIRECTORY/.." && pwd)
DEFAULT_OUTPUT_DIRECTORY="$REPOSITORY_ROOT/model-output"
ALL_CASES=(
    hiron-moderate-eddy hiron-moderate-control shakespeare-moderate-eddy shakespeare-moderate-control
    hiron-strong-eddy hiron-strong-control shakespeare-strong-eddy shakespeare-strong-control
    hiron-weak-eddy hiron-weak-control shakespeare-weak-eddy shakespeare-weak-control
)
SUITES=(hiron shakespeare)
FORCINGS=(strong moderate weak)

usage() {
    cat <<'EOF'
Usage:
  run-pseudo-topographic-suite.sh start [options]
  run-pseudo-topographic-suite.sh status [configuration options]
  run-pseudo-topographic-suite.sh pause [configuration options]
  run-pseudo-topographic-suite.sh resume [configuration options]

Scientific selection options for start:
  --suite all|hiron|shakespeare             Suite selection (default: all)
  --initial-condition both|eddy|control     Initial-condition selection (default: both)
  --forcing all|strong|moderate|weak        Forcing selection (default: all)

Configuration options:
  --nxy N                                    Horizontal resolution (default: 128)
  --target-day DAY                           Final model day (default: 600)
  --max-workers N                            Concurrent simulation workers (default: 3)
  --minimum-topographic-wavelength-km KM    Terrain cutoff (default: 20)
  --output-directory PATH                    Model output root (default: repository model-output)
  --matlab-command PATH                      MATLAB executable (default: matlab)

start adds the selected cases to an existing stopped campaign and never
removes completed work. pause prevents new jobs from starting but lets active
NetCDF writers finish. resume retries the persisted enabled case set.
EOF
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

is_positive_number() {
    awk -v value="$1" 'BEGIN { exit !(value + 0 == value && value > 0) }'
}

is_positive_integer() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

parse_options() {
    NXY=128
    TARGET_DAY=600
    MAX_WORKERS=3
    MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM=20
    OUTPUT_DIRECTORY="$DEFAULT_OUTPUT_DIRECTORY"
    MATLAB_COMMAND=${MATLAB_COMMAND:-matlab}
    SELECTED_SUITE=all
    SELECTED_INITIAL_CONDITION=both
    SELECTED_FORCING=all

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --suite)
                [[ $# -ge 2 ]] || fail "--suite requires a value"
                SELECTED_SUITE=$2
                shift 2
                ;;
            --initial-condition)
                [[ $# -ge 2 ]] || fail "--initial-condition requires a value"
                SELECTED_INITIAL_CONDITION=$2
                shift 2
                ;;
            --forcing)
                [[ $# -ge 2 ]] || fail "--forcing requires a value"
                SELECTED_FORCING=$2
                shift 2
                ;;
            --nxy)
                [[ $# -ge 2 ]] || fail "--nxy requires a value"
                NXY=$2
                shift 2
                ;;
            --target-day)
                [[ $# -ge 2 ]] || fail "--target-day requires a value"
                TARGET_DAY=$2
                shift 2
                ;;
            --max-workers)
                [[ $# -ge 2 ]] || fail "--max-workers requires a value"
                MAX_WORKERS=$2
                shift 2
                ;;
            --minimum-topographic-wavelength-km)
                [[ $# -ge 2 ]] || fail "--minimum-topographic-wavelength-km requires a value"
                MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM=$2
                shift 2
                ;;
            --output-directory)
                [[ $# -ge 2 ]] || fail "--output-directory requires a value"
                OUTPUT_DIRECTORY=$2
                shift 2
                ;;
            --matlab-command)
                [[ $# -ge 2 ]] || fail "--matlab-command requires a value"
                MATLAB_COMMAND=$2
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                fail "unknown option '$1'"
                ;;
        esac
    done

    is_positive_integer "$NXY" || fail "Nxy must be a positive integer"
    is_positive_number "$TARGET_DAY" || fail "target day must be positive"
    is_positive_integer "$MAX_WORKERS" || fail "max workers must be a positive integer"
    is_positive_number "$MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM" || fail "minimum topographic wavelength must be positive"
    [[ "$SELECTED_SUITE" == all || "$SELECTED_SUITE" == hiron || "$SELECTED_SUITE" == shakespeare ]] || fail "suite must be all, hiron, or shakespeare"
    [[ "$SELECTED_INITIAL_CONDITION" == both || "$SELECTED_INITIAL_CONDITION" == eddy || "$SELECTED_INITIAL_CONDITION" == control ]] || fail "initial condition must be both, eddy, or control"
    [[ "$SELECTED_FORCING" == all || "$SELECTED_FORCING" == strong || "$SELECTED_FORCING" == moderate || "$SELECTED_FORCING" == weak ]] || fail "forcing must be all, strong, moderate, or weak"
    if [[ "$OUTPUT_DIRECTORY" != /* ]]; then
        OUTPUT_DIRECTORY="$PWD/$OUTPUT_DIRECTORY"
    fi

    local target_token=${TARGET_DAY//./p}
    local wavelength_token=${MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM//./p}
    CAMPAIGN_NAME="pseudo-topographic-Nxy${NXY}-day${target_token}-lmin${wavelength_token}km"
    SUITE_ROOT="$OUTPUT_DIRECTORY/suites/$CAMPAIGN_NAME"
    SUITE_HASH=$(printf '%s' "$SUITE_ROOT" | cksum | awk '{print $1}')
    ENABLED_CASES_PATH="$SUITE_ROOT/enabled-cases.txt"
}

write_config() {
    mkdir -p "$SUITE_ROOT/cases" "$SUITE_ROOT/analysis" "$SUITE_ROOT/logs"
    local temporary_path
    temporary_path=$(mktemp "$SUITE_ROOT/campaign-config.XXXXXX")
    {
        printf 'NXY=%q\n' "$NXY"
        printf 'TARGET_DAY=%q\n' "$TARGET_DAY"
        printf 'MAX_WORKERS=%q\n' "$MAX_WORKERS"
        printf 'MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM=%q\n' "$MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM"
        printf 'OUTPUT_DIRECTORY=%q\n' "$OUTPUT_DIRECTORY"
        printf 'MATLAB_COMMAND=%q\n' "$MATLAB_COMMAND"
        printf 'CAMPAIGN_NAME=%q\n' "$CAMPAIGN_NAME"
        printf 'SUITE_ROOT=%q\n' "$SUITE_ROOT"
        printf 'SUITE_HASH=%q\n' "$SUITE_HASH"
        printf 'ENABLED_CASES_PATH=%q\n' "$ENABLED_CASES_PATH"
        printf 'OUTPUT_INTERVAL=%q\n' 21600
    } > "$temporary_path"
    mv -f "$temporary_path" "$SUITE_ROOT/campaign-config.env"
}

load_config() {
    local requested_root=$1
    [[ -f "$requested_root/campaign-config.env" ]] || fail "campaign configuration not found at $requested_root/campaign-config.env"
    # shellcheck source=/dev/null
    source "$requested_root/campaign-config.env"
}

initialize_or_validate_config() {
    if [[ ! -f "$SUITE_ROOT/campaign-config.env" ]]; then
        write_config
        return
    fi
    local requested_nxy=$NXY requested_day=$TARGET_DAY requested_wavelength=$MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM
    local requested_output=$OUTPUT_DIRECTORY requested_workers=$MAX_WORKERS requested_matlab=$MATLAB_COMMAND
    load_config "$SUITE_ROOT"
    [[ "$NXY" == "$requested_nxy" && "$TARGET_DAY" == "$requested_day" && "$MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM" == "$requested_wavelength" && "$OUTPUT_DIRECTORY" == "$requested_output" ]] || fail "existing campaign scientific configuration does not match the requested options"
    MAX_WORKERS=$requested_workers
    MATLAB_COMMAND=$requested_matlab
    write_config
}

case_is_enabled() {
    local case_id=$1
    [[ -f "$ENABLED_CASES_PATH" ]] && grep -Fxq "$case_id" "$ENABLED_CASES_PATH"
}

case_matches_selection() {
    local case_id=$1 suite forcing initial_condition remainder
    suite=${case_id%%-*}
    remainder=${case_id#*-}
    forcing=${remainder%%-*}
    initial_condition=${case_id##*-}
    [[ "$SELECTED_SUITE" == all || "$SELECTED_SUITE" == "$suite" ]] || return 1
    [[ "$SELECTED_FORCING" == all || "$SELECTED_FORCING" == "$forcing" ]] || return 1
    [[ "$SELECTED_INITIAL_CONDITION" == both || "$SELECTED_INITIAL_CONDITION" == "$initial_condition" ]]
}

merge_enabled_cases() {
    local temporary_path new_count=0 case_id enabled_case_ids
    temporary_path=$(mktemp "$SUITE_ROOT/enabled-cases.XXXXXX")
    for case_id in "${ALL_CASES[@]}"; do
        if case_is_enabled "$case_id" || case_matches_selection "$case_id"; then
            printf '%s\n' "$case_id" >> "$temporary_path"
            if ! case_is_enabled "$case_id"; then
                new_count=$((new_count + 1))
            fi
        fi
    done
    mv -f "$temporary_path" "$ENABLED_CASES_PATH"
    enabled_case_ids=$(paste -sd, "$ENABLED_CASES_PATH")
    write_text_marker "$SUITE_ROOT/campaign-manifest.txt" \
        "campaign=$CAMPAIGN_NAME" \
        "enabled_cases=$(number_of_enabled_cases)" \
        "enabled_case_ids=$enabled_case_ids" \
        "updated_at=$(date -Iseconds)" \
        "repository=$REPOSITORY_ROOT"
    printf '%d' "$new_count"
}

number_of_enabled_cases() {
    if [[ -f "$ENABLED_CASES_PATH" ]]; then
        awk 'NF {count++} END {print count+0}' "$ENABLED_CASES_PATH"
    else
        printf '0'
    fi
}

required_analysis_jobs() {
    local suite forcing eddy_case control_case
    for suite in "${SUITES[@]}"; do
        for forcing in "${FORCINGS[@]}"; do
            eddy_case="${suite}-${forcing}-eddy"
            control_case="${suite}-${forcing}-control"
            if case_is_enabled "$eddy_case" && case_is_enabled "$control_case"; then
                printf 'pair-%s-%s\n' "$suite" "$forcing"
            elif case_is_enabled "$eddy_case"; then
                printf 'single-%s\n' "$eddy_case"
            elif case_is_enabled "$control_case"; then
                printf 'single-%s\n' "$control_case"
            fi
        done
    done
}

session_is_running() {
    local session_name=$1
    screen -ls 2>/dev/null | grep -F ".${session_name}" | grep -vq 'Dead'
}

worker_session_name() {
    local job_id=$1
    printf 'ptw-%s-%s' "$SUITE_HASH" "$job_id"
}

number_of_active_workers() {
    screen -ls 2>/dev/null | grep -F ".ptw-${SUITE_HASH}-" | grep -v 'Dead' | awk 'END {print NR+0}'
}

write_text_marker() {
    local path=$1
    shift
    local temporary_path="${path}.tmp-$$"
    printf '%s\n' "$@" > "$temporary_path"
    mv -f "$temporary_path" "$path"
}

archive_marker() {
    local path=$1
    if [[ -f "$path" ]]; then
        mv -f "$path" "${path%.txt}-$(date '+%Y%m%d-%H%M%S').txt"
    fi
}

run_preflight() {
    command -v screen >/dev/null 2>&1 || fail "screen is required for detached workers"
    command -v "$MATLAB_COMMAND" >/dev/null 2>&1 || fail "MATLAB executable '$MATLAB_COMMAND' was not found"
    mkdir -p "$SUITE_ROOT/logs" "$OUTPUT_DIRECTORY"
    local preflight_log="$SUITE_ROOT/logs/preflight.log"
    if ! env PSEUDOTOPO_ACTION=preflight PSEUDOTOPO_OUTPUT_DIRECTORY="$OUTPUT_DIRECTORY" PSEUDOTOPO_SCRIPT_DIRECTORY="$SCRIPT_DIRECTORY" "$MATLAB_COMMAND" -batch "addpath(getenv('PSEUDOTOPO_SCRIPT_DIRECTORY')); EddyTidePseudoTopographicSuiteWorker" > "$preflight_log" 2>&1; then
        tail -n 40 "$preflight_log" >&2
        fail "MATLAB preflight failed; see $preflight_log"
    fi
}

manager_is_running() {
    [[ -f "$SUITE_ROOT/manager.pid" ]] || return 1
    local manager_pid
    manager_pid=$(cat "$SUITE_ROOT/manager.pid")
    if [[ ! "$manager_pid" =~ ^[1-9][0-9]*$ ]] || ! kill -0 "$manager_pid" 2>/dev/null; then
        rm -f "$SUITE_ROOT/manager.pid"
        return 1
    fi
    return 0
}

start_manager() {
    if manager_is_running; then
        printf 'Campaign manager is already running with process ID %s.\n' "$(cat "$SUITE_ROOT/manager.pid")"
        return
    fi
    rm -f "$SUITE_ROOT/manager.pid"
    nohup /bin/bash "$SCRIPT_PATH" _manage "$SUITE_ROOT" >> "$SUITE_ROOT/logs/manager-session.log" 2>&1 < /dev/null &
    local manager_pid=$!
    write_text_marker "$SUITE_ROOT/manager.pid" "$manager_pid"
    printf 'Started campaign manager process %s.\n' "$manager_pid"
    printf 'Campaign root: %s\n' "$SUITE_ROOT"
}

start_action() {
    initialize_or_validate_config
    if manager_is_running || [[ $(number_of_active_workers) -gt 0 ]]; then
        fail "the campaign is active; pause it and wait for current workers before adding cases"
    fi
    local new_count
    new_count=$(merge_enabled_cases)
    if [[ "$new_count" -gt 0 ]]; then
        archive_marker "$SUITE_ROOT/campaign-complete.txt"
        printf 'Enabled %s new campaign cases.\n' "$new_count"
    fi
    run_preflight
    if campaign_is_complete; then
        printf 'All enabled campaign work is already complete: %s\n' "$SUITE_ROOT"
        return
    fi
    start_manager
}

resume_action() {
    load_config "$SUITE_ROOT"
    run_preflight
    rm -f "$SUITE_ROOT/pause-requested.txt" "$SUITE_ROOT/campaign-paused.txt"
    archive_marker "$SUITE_ROOT/campaign-failed.txt"
    archive_marker "$SUITE_ROOT/storage-blocked.txt"
    local case_id analysis_job
    while IFS= read -r case_id; do
        [[ -n "$case_id" ]] && archive_marker "$SUITE_ROOT/cases/$case_id/failed.txt"
    done < "$ENABLED_CASES_PATH"
    while IFS= read -r analysis_job; do
        [[ -n "$analysis_job" ]] && archive_marker "$SUITE_ROOT/analysis/$analysis_job/failed.txt"
    done < <(required_analysis_jobs)
    start_manager
}

pause_action() {
    load_config "$SUITE_ROOT"
    write_text_marker "$SUITE_ROOT/pause-requested.txt" "requested_at=$(date -Iseconds)" "behavior=active workers continue; queued workers remain unlaunched"
    printf 'Pause requested. Active workers will continue normally.\n'
}

case_status() {
    local case_id=$1 case_directory session_name stage
    if ! case_is_enabled "$case_id"; then
        printf 'disabled'
        return
    fi
    case_directory="$SUITE_ROOT/cases/$case_id"
    session_name=$(worker_session_name "$case_id")
    if [[ -f "$case_directory/quicklook-complete.txt" ]]; then
        printf 'complete'
    elif [[ -f "$case_directory/failed.txt" ]]; then
        printf 'failed'
    elif session_is_running "$session_name"; then
        stage=$(marker_value "$case_directory/stage.txt" stage 2>/dev/null || true)
        [[ "$stage" == quicklook ]] && printf 'quicklook' || printf 'running'
    elif [[ -f "$case_directory/simulation-complete.txt" ]]; then
        printf 'simulation-complete'
    else
        printf 'queued'
    fi
}

analysis_job_for_pair() {
    local suite=$1 forcing=$2 eddy_case control_case
    eddy_case="${suite}-${forcing}-eddy"
    control_case="${suite}-${forcing}-control"
    if case_is_enabled "$eddy_case" && case_is_enabled "$control_case"; then
        printf 'pair-%s-%s' "$suite" "$forcing"
    elif case_is_enabled "$eddy_case"; then
        printf 'single-%s' "$eddy_case"
    elif case_is_enabled "$control_case"; then
        printf 'single-%s' "$control_case"
    fi
}

analysis_status() {
    local suite=$1 forcing=$2 job_id directory session_name
    job_id=$(analysis_job_for_pair "$suite" "$forcing")
    if [[ -z "$job_id" ]]; then
        printf 'disabled'
        return
    fi
    directory="$SUITE_ROOT/analysis/$job_id"
    session_name=$(worker_session_name "$job_id")
    if [[ -f "$directory/analysis-complete.txt" ]]; then
        printf 'complete'
    elif [[ -f "$directory/failed.txt" ]]; then
        printf 'failed'
    elif session_is_running "$session_name"; then
        printf 'analyzing'
    else
        printf 'queued'
    fi
}

marker_value() {
    local path=$1 key=$2
    [[ -f "$path" ]] || return 1
    sed -n "s/^${key}=//p" "$path" | tail -n 1
}

status_action() {
    load_config "$SUITE_ROOT"
    printf 'Campaign: %s\n' "$CAMPAIGN_NAME"
    printf 'Root: %s\n' "$SUITE_ROOT"
    printf 'Configuration: Nxy=%s, target day=%s, max workers=%s, terrain cutoff=%s km\n' "$NXY" "$TARGET_DAY" "$MAX_WORKERS" "$MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM"
    printf 'Enabled cases: %s of 12\n' "$(number_of_enabled_cases)"
    printf 'Manager: %s\n' "$(manager_is_running && printf running || printf stopped)"
    printf 'Storage: %s\n' "$(df -h "$OUTPUT_DIRECTORY" | awk 'NR==2 {print $4 " available of " $2}')"
    local suite forcing
    for suite in "${SUITES[@]}"; do
        printf '\n%s suite\n' "$(printf '%s' "$suite" | tr '[:lower:]' '[:upper:]')"
        printf '%-10s %-20s %-20s %-20s\n' FORCING EDDY CONTROL ENERGY-ANALYSIS
        for forcing in "${FORCINGS[@]}"; do
            printf '%-10s %-20s %-20s %-20s\n' "$forcing" \
                "$(case_status "${suite}-${forcing}-eddy")" \
                "$(case_status "${suite}-${forcing}-control")" \
                "$(analysis_status "$suite" "$forcing")"
        done
    done

    local job_id log_path latest
    printf '\nActive worker estimates\n'
    for job_id in "${ALL_CASES[@]}"; do
        if session_is_running "$(worker_session_name "$job_id")"; then
            log_path="$SUITE_ROOT/logs/${job_id}.log"
            latest=$(tr -d '\b\r' < "$log_path" | grep 'model time t=' | tail -n 1 || true)
            printf '%s: %s\n' "$job_id" "${latest:-log: $log_path}"
        fi
    done
    while IFS= read -r job_id; do
        if session_is_running "$(worker_session_name "$job_id")"; then
            log_path="$SUITE_ROOT/logs/${job_id}.log"
            latest=$(tr -d '\b\r' < "$log_path" | tail -n 1 || true)
            printf '%s: %s\n' "$job_id" "${latest:-log: $log_path}"
        fi
    done < <(required_analysis_jobs)

    if [[ -f "$SUITE_ROOT/campaign-failed.txt" ]]; then
        printf '\nScheduling is halted by %s\n' "$SUITE_ROOT/campaign-failed.txt"
    elif [[ -f "$SUITE_ROOT/storage-blocked.txt" ]]; then
        printf '\nScheduling is blocked by %s\n' "$SUITE_ROOT/storage-blocked.txt"
    elif [[ -f "$SUITE_ROOT/pause-requested.txt" || -f "$SUITE_ROOT/campaign-paused.txt" ]]; then
        printf '\nScheduling is paused.\n'
    elif [[ -f "$SUITE_ROOT/campaign-complete.txt" ]]; then
        printf '\nAll enabled simulations and analyses are complete.\n'
    fi
}

number_of_incomplete_simulations() {
    local count=0 case_id
    while IFS= read -r case_id; do
        [[ -n "$case_id" && ! -f "$SUITE_ROOT/cases/$case_id/quicklook-complete.txt" ]] && count=$((count + 1))
    done < "$ENABLED_CASES_PATH"
    printf '%d' "$count"
}

number_of_incomplete_analyses() {
    local count=0 job_id
    while IFS= read -r job_id; do
        [[ -n "$job_id" && ! -f "$SUITE_ROOT/analysis/$job_id/analysis-complete.txt" ]] && count=$((count + 1))
    done < <(required_analysis_jobs)
    printf '%d' "$count"
}

campaign_is_complete() {
    [[ $(number_of_enabled_cases) -gt 0 && $(number_of_incomplete_simulations) -eq 0 && $(number_of_incomplete_analyses) -eq 0 ]]
}

storage_gate() {
    local incomplete available_kb required_kb
    incomplete=$(number_of_incomplete_simulations)
    available_kb=$(df -Pk "$OUTPUT_DIRECTORY" | awk 'NR==2 {print $4}')
    required_kb=$(awk -v cases="$incomplete" -v nxy="$NXY" -v days="$TARGET_DAY" 'BEGIN { perCaseGiB=4*(nxy/128)^3*(days/600); if (perCaseGiB < 0.25) perCaseGiB=0.25; printf "%.0f", (20+cases*perCaseGiB)*1024*1024 }')
    if (( available_kb < required_kb )); then
        write_text_marker "$SUITE_ROOT/storage-blocked.txt" "blocked_at=$(date -Iseconds)" "available_kib=$available_kb" "required_kib=$required_kb" "incomplete_cases=$incomplete"
        return 1
    fi
    return 0
}

job_failure_path() {
    local job_id=$1
    if [[ "$job_id" == pair-* || "$job_id" == single-* ]]; then
        printf '%s/analysis/%s/failed.txt' "$SUITE_ROOT" "$job_id"
    else
        printf '%s/cases/%s/failed.txt' "$SUITE_ROOT" "$job_id"
    fi
}

find_failed_job() {
    local case_id job_id failure_path
    while IFS= read -r case_id; do
        failure_path=$(job_failure_path "$case_id")
        [[ -f "$failure_path" ]] && { printf '%s' "$case_id"; return; }
    done < "$ENABLED_CASES_PATH"
    while IFS= read -r job_id; do
        failure_path=$(job_failure_path "$job_id")
        [[ -f "$failure_path" ]] && { printf '%s' "$job_id"; return; }
    done < <(required_analysis_jobs)
}

launch_job() {
    local job_id=$1 session_name
    session_name=$(worker_session_name "$job_id")
    if [[ "$job_id" == pair-* || "$job_id" == single-* ]]; then
        mkdir -p "$SUITE_ROOT/analysis/$job_id"
    else
        mkdir -p "$SUITE_ROOT/cases/$job_id"
    fi
    screen -dmS "$session_name" /bin/bash "$SCRIPT_PATH" _worker "$SUITE_ROOT" "$job_id"
    printf '[%s] Launched %s in %s.\n' "$(date -Iseconds)" "$job_id" "$session_name" >> "$SUITE_ROOT/logs/manager.log"
}

manage_action() {
    local requested_root=$1
    load_config "$requested_root"
    local wait_count
    for wait_count in {1..50}; do
        [[ -f "$SUITE_ROOT/manager.pid" ]] && break
        sleep 0.1
    done
    trap 'rm -f "$SUITE_ROOT/manager.pid"' EXIT
    rm -f "$SUITE_ROOT/campaign-paused.txt"
    printf '[%s] Manager started with %s simulation worker slots.\n' "$(date -Iseconds)" "$MAX_WORKERS" >> "$SUITE_ROOT/logs/manager.log"
    while true; do
        if [[ -f "$SUITE_ROOT/pause-requested.txt" ]]; then
            write_text_marker "$SUITE_ROOT/campaign-paused.txt" "paused_at=$(date -Iseconds)" "behavior=active workers continue"
            printf '[%s] Manager paused; active workers continue.\n' "$(date -Iseconds)" >> "$SUITE_ROOT/logs/manager.log"
            return
        fi

        local failed_job
        failed_job=$(find_failed_job)
        if [[ -n "$failed_job" ]]; then
            write_text_marker "$SUITE_ROOT/campaign-failed.txt" "failed_at=$(date -Iseconds)" "job_id=$failed_job" "behavior=no additional queued jobs launched"
            printf '[%s] Scheduling halted after failure in %s.\n' "$(date -Iseconds)" "$failed_job" >> "$SUITE_ROOT/logs/manager.log"
            return 1
        fi

        if campaign_is_complete; then
            write_text_marker "$SUITE_ROOT/campaign-complete.txt" \
                "completed_at=$(date -Iseconds)" \
                "cases=$(number_of_enabled_cases)" \
                "analyses=$(required_analysis_jobs | awk 'END {print NR+0}')" \
                "target_day=$TARGET_DAY"
            printf '[%s] All enabled campaign work completed.\n' "$(date -Iseconds)" >> "$SUITE_ROOT/logs/manager.log"
            return
        fi

        local active_workers case_id job_id
        active_workers=$(number_of_active_workers)
        if [[ $(number_of_incomplete_simulations) -gt 0 ]]; then
            while IFS= read -r case_id; do
                (( active_workers >= MAX_WORKERS )) && break
                [[ -z "$case_id" || -f "$SUITE_ROOT/cases/$case_id/quicklook-complete.txt" ]] && continue
                session_is_running "$(worker_session_name "$case_id")" && continue
                if ! storage_gate; then
                    printf '[%s] Storage gate blocked new workers.\n' "$(date -Iseconds)" >> "$SUITE_ROOT/logs/manager.log"
                    return 1
                fi
                launch_job "$case_id"
                active_workers=$((active_workers + 1))
            done < "$ENABLED_CASES_PATH"
        elif [[ "$active_workers" -eq 0 ]]; then
            while IFS= read -r job_id; do
                [[ -z "$job_id" || -f "$SUITE_ROOT/analysis/$job_id/analysis-complete.txt" ]] && continue
                launch_job "$job_id"
                break
            done < <(required_analysis_jobs)
        fi
        sleep 5
    done
}

lock_ids_for_job() {
    local job_id=$1 pair_id
    if [[ "$job_id" == pair-* ]]; then
        pair_id=${job_id#pair-}
        printf '%s-eddy\n%s-control\n' "$pair_id" "$pair_id"
    elif [[ "$job_id" == single-* ]]; then
        printf '%s\n' "${job_id#single-}"
    else
        printf '%s\n' "$job_id"
    fi
}

acquire_model_lock() {
    local case_id=$1 lock_root lock_directory owner_pid
    lock_root="$OUTPUT_DIRECTORY/.pseudo-topographic-locks"
    lock_directory="$lock_root/${case_id}-Nxy${NXY}-lmin${MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM}km.lock"
    mkdir -p "$lock_root"
    if ! mkdir "$lock_directory" 2>/dev/null; then
        owner_pid=$(cat "$lock_directory/owner.pid" 2>/dev/null || true)
        if [[ "$owner_pid" =~ ^[1-9][0-9]*$ ]] && kill -0 "$owner_pid" 2>/dev/null; then
            return 1
        fi
        rm -f "$lock_directory/owner.pid"
        rmdir "$lock_directory" 2>/dev/null || return 1
        mkdir "$lock_directory" || return 1
    fi
    printf '%s\n' "$$" > "$lock_directory/owner.pid"
    ACQUIRED_LOCKS+=("$lock_directory")
}

release_model_locks() {
    local lock_directory
    (( ${#ACQUIRED_LOCKS[@]} > 0 )) || return
    for lock_directory in "${ACQUIRED_LOCKS[@]}"; do
        rm -f "$lock_directory/owner.pid"
        rmdir "$lock_directory" 2>/dev/null || true
    done
}

worker_action() {
    local requested_root=$1 job_id=$2 case_id failure_path
    load_config "$requested_root"
    ACQUIRED_LOCKS=()
    while IFS= read -r case_id; do
        if ! acquire_model_lock "$case_id"; then
            failure_path=$(job_failure_path "$job_id")
            mkdir -p "$(dirname "$failure_path")"
            write_text_marker "$failure_path" "job_id=$job_id" "stage=lock" "failed_at=$(date -Iseconds)" "identifier=PseudoTopographicCampaign:ModelLocked" "message=model lock is owned by another live process"
            release_model_locks
            return 1
        fi
    done < <(lock_ids_for_job "$job_id")
    trap release_model_locks EXIT

    local log_path="$SUITE_ROOT/logs/${job_id}.log"
    export PSEUDOTOPO_ACTION=run
    export PSEUDOTOPO_SCRIPT_DIRECTORY="$SCRIPT_DIRECTORY"
    export PSEUDOTOPO_JOB_ID="$job_id"
    export PSEUDOTOPO_SUITE_ROOT="$SUITE_ROOT"
    export PSEUDOTOPO_OUTPUT_DIRECTORY="$OUTPUT_DIRECTORY"
    export PSEUDOTOPO_NXY="$NXY"
    export PSEUDOTOPO_TARGET_DAY="$TARGET_DAY"
    export PSEUDOTOPO_OUTPUT_INTERVAL="$OUTPUT_INTERVAL"
    export PSEUDOTOPO_MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM="$MINIMUM_TOPOGRAPHIC_WAVELENGTH_KM"
    "$MATLAB_COMMAND" -batch "addpath(getenv('PSEUDOTOPO_SCRIPT_DIRECTORY')); EddyTidePseudoTopographicSuiteWorker" >> "$log_path" 2>&1
    local matlab_status=$?
    release_model_locks
    trap - EXIT
    return "$matlab_status"
}

[[ $# -ge 1 ]] || { usage; exit 1; }
ACTION=$1
shift

case "$ACTION" in
    start)
        parse_options "$@"
        start_action
        ;;
    status)
        parse_options "$@"
        status_action
        ;;
    pause)
        parse_options "$@"
        pause_action
        ;;
    resume)
        parse_options "$@"
        resume_action
        ;;
    _manage)
        [[ $# -eq 1 ]] || fail "internal manager action requires the campaign root"
        manage_action "$1"
        ;;
    _worker)
        [[ $# -eq 2 ]] || fail "internal worker action requires the campaign root and job ID"
        worker_action "$1" "$2"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        fail "unknown action '$ACTION'"
        ;;
esac

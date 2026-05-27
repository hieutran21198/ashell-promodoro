{
  pkgs,
  lib,
  ...
}:
pkgs.writeShellApplication {
  name = "promodoro";

  runtimeInputs = with pkgs; [
    coreutils
  ];

  text = ''
    set -euo pipefail

    state_dir="''${XDG_RUNTIME_DIR:-/tmp}/promodoro"
    state_file="$state_dir/state"

    work_secs="''${PROMODORO_WORK:-1500}"
    break_secs="''${PROMODORO_BREAK:-300}"
    long_break_secs="''${PROMODORO_LONG_BREAK:-900}"
    rounds_per_cycle="''${PROMODORO_ROUNDS:-4}"

    mkdir -p "$state_dir"

    now() { date +%s; }

    load_state() {
      if [[ -f $state_file ]]; then
        # shellcheck disable=SC1090
        source "$state_file"
      else
        phase=idle
        phase_end=0
        round=0
      fi
    }

    save_state() {
      printf 'phase=%s\nphase_end=%s\nround=%s\n' \
        "$phase" "$phase_end" "$round" > "$state_file"
    }

    advance() {
      case "$phase" in
        work)
          round=$((round + 1))
          if (( round % rounds_per_cycle == 0 )); then
            phase=long_break
            phase_end=$(( $(now) + long_break_secs ))
          else
            phase=break
            phase_end=$(( $(now) + break_secs ))
          fi
          ;;
        *)
          phase=work
          phase_end=$(( $(now) + work_secs ))
          ;;
      esac
    }

    cmd_start() {
      load_state
      if [[ $phase == idle || $phase == paused ]]; then
        advance
        save_state
      fi
      cmd_status
    }

    cmd_pause() {
      load_state
      if [[ $phase != idle && $phase != paused ]]; then
        remaining=$(( phase_end - $(now) ))
        phase=paused
        phase_end=$remaining
        save_state
      fi
      cmd_status
    }

    cmd_reset() {
      rm -f "$state_file"
      phase=idle
      phase_end=0
      round=0
      cmd_status
    }

    cmd_tick() {
      load_state
      if [[ $phase != idle && $phase != paused && $(now) -ge $phase_end ]]; then
        advance
        save_state
      fi
      cmd_status
    }

    cmd_status() {
      load_state
      if [[ $phase == idle ]]; then
        echo "idle"
        return
      fi
      if [[ $phase == paused ]]; then
        remaining=$phase_end
      else
        remaining=$(( phase_end - $(now) ))
        (( remaining < 0 )) && remaining=0
      fi
      mm=$(( remaining / 60 ))
      ss=$(( remaining % 60 ))
      printf '%s %02d:%02d (round %d)\n' "$phase" "$mm" "$ss" "$round"
    }

    cmd=''${1:-status}
    shift || true

    case "$cmd" in
      start)  cmd_start ;;
      pause)  cmd_pause ;;
      reset)  cmd_reset ;;
      tick)   cmd_tick ;;
      status) cmd_status ;;
      *)
        echo "usage: promodoro {start|pause|reset|tick|status}" >&2
        exit 2
        ;;
    esac
  '';

  meta = with lib; {
    description = "Tiny pomodoro timer designed as an ashell custom-module source";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "promodoro";
  };
}

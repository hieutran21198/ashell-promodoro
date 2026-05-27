# ashell-promodoro

A tiny pomodoro state-machine CLI designed to feed an [ashell](https://github.com/MalpenZibo/ashell) custom module. Fires a desktop notification at every phase boundary, with optional "Lock now / Cancel" actions when work ends.

The canonical implementation is a plain bash script (`bin/promodoro`, bash 3.2+ — runs on Linux and macOS). It's packaged as a Nix flake so NixOS users can pin it; non-Nix users install it via `install.sh`.

## Install

### Nix flake

```nix
{
  inputs.ashell-promodoro = {
    url = "github:hieutran21198/ashell-promodoro";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

The package is `inputs.ashell-promodoro.packages.${system}.default`. The Nix derivation wraps the script with `libnotify` and `systemd` on `PATH`, so `notify-send` and `loginctl lock-session` work out of the box.

```nix
home.packages = [ inputs.ashell-promodoro.packages.${pkgs.system}.default ];
```

### Without Nix

```sh
git clone https://github.com/hieutran21198/ashell-promodoro
cd ashell-promodoro
PROMODORO_PREFIX=$HOME/.local ./install.sh
```

Runtime dependencies for the optional features (notifications + screen lock) are looked up in `PATH` and gracefully skipped if absent:

| Feature                 | Requires           |
| ----------------------- | ------------------ |
| Desktop notifications   | `notify-send` (libnotify) |
| Default Lock-now action | `loginctl` (systemd-logind) — overridable via `PROMODORO_LOCK_CMD` |

## CLI

```
promodoro start    # start work / resume from pause; no-op if already running
promodoro pause    # freeze remaining time
promodoro toggle   # start if idle/paused, pause if running (designed for click-to-toggle)
promodoro reset    # clear state, return to idle
promodoro tick     # advance state if current phase expired, then print status
promodoro status   # print current status (default if no arg)
```

Status output is one line:

```
work 24:59 (round 0)
break 04:30 (round 1)
long_break 14:00 (round 4)
paused 12:34 (round 1)
idle
```

`tick` is the call you want from polling integrations: it advances the state machine when a phase expires, fires the right notification, then prints the current status. `status` only reads state.

## Notifications

When `tick` rolls the state machine to a new phase it fires `notify-send`:

| Transition              | Urgency | Actions               |
| ----------------------- | ------- | --------------------- |
| `work` → `break`        | normal  | `Lock now`, `Cancel`  |
| `work` → `long_break`   | normal  | `Lock now`, `Cancel`  |
| `break` → `work`        | low     | none                  |
| `long_break` → `work`   | low     | none                  |

Clicking `Lock now` invokes `${PROMODORO_LOCK_CMD:-loginctl lock-session}`. `Cancel` simply dismisses. The notification is fired in a backgrounded `notify-send --wait` so the script returns immediately; the action handler keeps running until the user clicks or the notification times out.

If `notify-send` isn't on `PATH`, the script silently skips the notification — no error.

## Configuration

All via environment variables:

| Variable               | Default                | Meaning                                                          |
| ---------------------- | ---------------------- | ---------------------------------------------------------------- |
| `PROMODORO_WORK`       | `1500`                 | work phase (seconds)                                             |
| `PROMODORO_BREAK`      | `300`                  | short break (seconds)                                            |
| `PROMODORO_LONG_BREAK` | `900`                  | long break (seconds)                                             |
| `PROMODORO_ROUNDS`     | `4`                    | work rounds before a long break                                  |
| `PROMODORO_LOCK_CMD`   | `loginctl lock-session`| shell command to run on the "Lock now" notification action       |

State file: `${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/promodoro/state`. Survives across `start`/`pause`/`tick` and is cleared by `reset`.

## ashell wiring

ashell's `custom_modules` runs `listen_cmd` via `bash -c` and expects newline-delimited JSON with `text` and `alt` fields. Pair that with `promodoro tick` in a polling loop, and use `command` to wire left-click to `toggle`.

`~/.config/ashell/config.toml`:

```toml
[[custom_modules]]
name = "Promodoro"
type = "Button"
icon = "🍅"
command = "promodoro toggle"
listen_cmd = """
while :; do
  out=$(promodoro tick)
  printf '{"text":"%s","alt":"%s"}\\n' "$out" "$out"
  sleep 1
done
"""

[modules]
center = ["Promodoro"]
```

In Nix (e.g. inside `(pkgs.formats.toml { }).generate`):

```nix
custom_modules = [
  {
    name = "Promodoro";
    type = "Button";
    icon = "🍅";
    command = "${pkgs.ashell-promodoro}/bin/promodoro toggle";
    listen_cmd = ''
      while :; do
        out=$(${pkgs.ashell-promodoro}/bin/promodoro tick)
        printf '{"text":"%s","alt":"%s"}\n' "$out" "$out"
        sleep 1
      done
    '';
  }
];
```

Interpolating the absolute store path keeps the loop working under systemd user units that don't inherit your interactive `PATH`.

### Right-click "show detail"

ashell's `CustomModuleDef` (as of this writing) only exposes a left-click `command` — no right-click or scroll bindings. Workarounds:

- **Bind a keychord in your compositor.** For niri:

  ```kdl
  binds {
    Mod+P { spawn "sh" "-c" "notify-send 'Pomodoro' \"$(promodoro status)\""; }
  }
  ```

- **Enrich `listen_cmd` output** so the bar text always carries the detail you'd otherwise pop on right-click (e.g. include the upcoming phase and total rounds in the status line).

## License

MIT.

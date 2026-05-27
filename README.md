# ashell-promodoro

A tiny pomodoro state-machine CLI designed to feed an [ashell](https://github.com/MalpenZibo/ashell) custom module.

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

The package is `inputs.ashell-promodoro.packages.${system}.default` (aliased from `packages.${system}.promodoro`). A typical home-manager wiring:

```nix
home.packages = [ inputs.ashell-promodoro.packages.${pkgs.system}.default ];
```

### Without Nix

```sh
git clone https://github.com/hieutran21198/ashell-promodoro
cd ashell-promodoro
PROMODORO_PREFIX=$HOME/.local ./install.sh    # → $PREFIX/bin/promodoro
```

`PROMODORO_PREFIX` defaults to `~/.local`. The installer warns if `$PREFIX/bin` is not on `PATH`.

## CLI

```
promodoro start    # start work / resume from pause; no-op if already running
promodoro pause    # freeze remaining time
promodoro reset    # clear state, return to idle
promodoro tick     # advance state if current phase expired, then print status
promodoro status   # print current status (default if no arg)
```

Output is one line:

```
work 24:59 (round 0)
break 04:30 (round 1)
long_break 14:00 (round 4)
paused 12:34 (round 1)
idle
```

`tick` is the call you want from polling integrations: it advances the state machine when a phase expires, then prints the current status. `status` only reads state without advancing.

## Configuration

All via environment variables:

| Variable               | Default | Meaning                          |
| ---------------------- | ------- | -------------------------------- |
| `PROMODORO_WORK`       | `1500`  | work phase (seconds)             |
| `PROMODORO_BREAK`      | `300`   | short break (seconds)            |
| `PROMODORO_LONG_BREAK` | `900`   | long break (seconds)             |
| `PROMODORO_ROUNDS`     | `4`     | work rounds before a long break  |

State file: `${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/promodoro/state`. It survives across `start`/`pause`/`tick` invocations and is cleared by `reset`.

## ashell wiring

ashell's `custom_modules` runs `listen_cmd` via `bash -c` and expects newline-delimited JSON objects with `text` and `alt` fields. Pair that with `promodoro tick` in a polling loop:

`~/.config/ashell/config.toml`:

```toml
[[custom_modules]]
name = "Promodoro"
type = "Text"
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
    type = "Text";
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

## License

MIT.

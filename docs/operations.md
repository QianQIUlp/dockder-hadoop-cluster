# Operations and recovery

## State transitions

| Intent | Command | Hadoop data |
|---|---|---|
| Start first lesson | `./hadoop-lab up standalone` | reused |
| Start role/failure labs | `./hadoop-lab up cluster` | reused |
| Stop | `./hadoop-lab stop all` | kept |
| Recreate runtime | `./hadoop-lab reset MODE` | kept |
| Erase one mode | `./hadoop-lab reset MODE --data` | deleted after confirmation |
| Inspect | `./hadoop-lab status` | unchanged |
| Collect support evidence | `./hadoop-lab diagnose` | unchanged |

`reset --data --yes` is intended for CI or an already-confirmed disposable lab.
It targets only volumes declared by the selected Compose mode.

## Exit codes

- `doctor` exits non-zero for missing Docker, unreachable engine or invalid
  Compose configuration.
- `status` exits non-zero when a container or expected daemon is missing.
- `lesson check` exits non-zero until its observable result is present.

That behavior makes the same commands useful to students, teachers and CI.

## Diagnostic bundle

`./hadoop-lab diagnose` writes a timestamped archive under `diagnostics/`. It
contains tool versions, selected container state, status output and recent
logs. It deliberately excludes `.env` and full container environment values.
Review any bundle before sharing it.

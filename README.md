# Omarchy Backrest

An Omarchy bar widget that shows the state of your
[Backrest](https://github.com/garethgeorge/backrest) (restic) backups.

The icon uses your theme's colors:

- **green** — last backup succeeded and is recent.
- **spinning** (accent color) — a backup is running; it pops once when done.
- **yellow** — the last successful backup is older than 3 hours, or the last
  run finished with warnings.
- **red, pulsing** — the last run failed or `backrest.service` is not running.
- The tooltip shows a one-line summary.
- Left-click opens a popup with schedule, last run details (duration, data
  added, files) and buttons to open the Backrest web UI or refresh.
- Right-click refreshes immediately; otherwise it refreshes every 30 seconds.

The widget reads Backrest's operation log
(`~/.local/share/backrest/oplog.sqlite`) read-only, so it needs no API
credentials and does not touch the repository.

## Requirements

- Omarchy with the Quickshell-based bar
- Backrest running as the systemd user unit `backrest.service`
- `python3`

## Installation

```bash
omarchy plugin add https://github.com/xela-io/omarchy-backrest.git --enable --yes
```

## Removal

```bash
omarchy plugin remove xela.backrest --yes
```

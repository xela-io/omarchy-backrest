# Omarchy Backrest

An Omarchy bar widget that shows the state of your
[Backrest](https://github.com/garethgeorge/backrest) (restic) backups.

- `󰁯` — last backup succeeded and is recent.
- `󰁯 …` — a backup is running.
- `󰁯 !` (urgent color) — the last run failed, the last successful backup is
  older than 3 hours, or `backrest.service` is not running.
- The tooltip shows the last successful backup, the next scheduled run and
  any error message.
- Left-click opens the Backrest web UI (`http://127.0.0.1:9898`).
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

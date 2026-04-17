# Runtime actions added

Installer should support not only planning/scaffold but also direct operator actions:
- install bot now
- install cabinet now
- update bot now
- update cabinet now

Current implementation uses:
- repo checkout in final `/opt/...` directory
- bundle env/config copied into repo dir
- docker compose run from repo/bundle paths
- update path via `git pull --ff-only`

This matches the desired production ops model from user voice note.

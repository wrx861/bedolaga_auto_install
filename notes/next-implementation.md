# Next implementation plan

## Immediate next code steps
1. Extend host bootstrap stage with broader package/repo compatibility checks
2. Improve automatic reuse of suggested free ports when defaults are busy
3. Keep coexist-safe behavior for existing hosts
   - detect `/opt/remnawave*`
   - preserve unrelated open ports by default
   - additive firewall changes only
3. Wire deploy menu action to `lib/deploy.sh`
4. Add repo clone/pull functions for:
   - BEDOLAGA-DEV/remnawave-bedolaga-telegram-bot
   - BEDOLAGA-DEV/bedolaga-cabinet
5. Add compose materialization strategy:
   - upstream repo untouched where possible
   - generated `.env`
   - generated override compose files
6. Add reverse-proxy template selection:
   - caddy first
   - nginx later
7. Add health verification functions
8. Add safe rerun/update path

## Product goal
One command from GitHub -> bootstrap -> interactive menu -> minimal answers -> generated production scaffold -> deploy -> verify.

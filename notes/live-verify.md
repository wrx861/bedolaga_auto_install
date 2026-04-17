# Live verify notes

Current live verification draft:
- bot: `docker compose ps` + `curl /health` with `X-API-Key`
- cabinet: `curl http://127.0.0.1:${CABINET_PORT}/`

This is intentionally simple for now.
Next iterations can add:
- container health status parsing
- richer diagnostics on failure
- API route verification for cabinet + backend
- reverse-proxy verification

# rate-limiting-advanced debug-log filter — demo

A working example of a custom nginx template that silences the
`rate-limiting-advanced` sync-timer debug lines
(`start sync` / `empty sync, do fetch` / `end sync`) while leaving all
other debug output untouched.

---

## READ FIRST

- **Demonstration only.** This is a reference for the technique. It is
  not a drop-in fix. You must build, test, and support your own version.
- **Version.** Tested on Kong Gateway **3.10.0.10**. You are on an
  unsupported 3.5.X.X build. The mechanism should carry over, but the
  bundled nginx template layout can differ between versions; re-verify
  before relying on it.
- **Not officially supported.** This is a local customization of a
  stock plugin's logging. Kong Support is not obligated to support it.
- **Not load-tested.** The `ngx.log` wrapper adds a Lua substring scan
  to every DEBUG call. It has not been benchmarked under production
  traffic. Measure before deploying.

---

## Prerequisites

- Docker + Docker Compose v2
- A Kong Enterprise license file

## Setup

Drop your license JSON at `license/license.json`:

```bash
cp /path/to/your/license.json license/license.json
```

## Run

```bash
docker compose up -d --build
./test.sh 15
```

Expected:

```
=== RLA sync debug lines in last 15s ===
  baseline (no custom template): ~90+
  filtered (Option B template):  0
```

Other debug lines (including non-sync RLA debug) continue to flow on
`kong-filtered`.

## Teardown

```bash
docker compose down -v
```

## What the demo does

- `kong-baseline` (port 8000): stock image, debug level, no filter.
- `kong-filtered` (port 8010): same image, launched with
  `kong prepare --nginx-conf /etc/kong/custom_nginx.template`.
- `build-template.sh` merges Kong's bundled `nginx.lua` and
  `nginx_kong.lua` into a single template and injects
  `dofile('/etc/kong/log_filter.lua')` at the top of
  `init_by_lua_block`.
- `log_filter.lua` reassigns `ngx.log` to a wrapper that drops DEBUG
  messages matching the three RLA sync patterns and forwards everything
  else to the original.

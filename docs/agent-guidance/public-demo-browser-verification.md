# Public demo browser verification guidance

## Zoidbot operational corrections — public demo / browser verification

These corrections are mandatory for ImmoGestion public-route, frontend, Cloudflare, and demo-readiness work. They do not override issue-scoped execution instructions for live product/debug/deploy issues; in those runs, follow the issue description and latest authoritative comments first and only use browser-verification guidance when the issue itself asks for it.

- HTTP 200 / curl is not enough for public demo readiness.
- Use `/paperclip/ImmoGestion/scripts/browser-check.js https://app.immogestion.app/` for real browser checks.
- Blank page, empty body text, CSP/CanvasKit/WASM/font/dynamic import, console/page errors, or failed requests that block Flutter rendering mean the public demo is not ready.
- Normal OS/browser DNS and unforced HTTPS are decisive; Cloudflare API, DoH-only, `curl --resolve`, localhost, and origin-container health are diagnostic only.
- Cloudflare/API success and frontend usability are separate.
- `paperclip.immogestion.app` must stay private.
- Christopher corrections must be reconciled into active issue/instructions immediately.

Last updated by Zoidbot/Hermes after live white-screen/CSP debugging.
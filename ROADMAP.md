# cot.land Roadmap

## What's Done

Phases 1-6 from the original plan are complete. The registry server runs, handles HTTP requests, persists data, serves a REST API and web UI, validates publishes, and serves source files.

| Component | Status | Files |
|-----------|--------|-------|
| HTTP server (accept loop + body read) | Done | `server.cot` |
| Router (`:param` matching) | Done | `router.cot` |
| Request parsing | Done | `request.cot` |
| Response builders | Done | `response.cot` |
| Package/Version models | Done | `package.cot`, `user.cot` |
| In-memory registry + JSON persistence | Done | `registry.cot` |
| Package file storage on disk | Done | `files.cot` |
| Package API (list, get, create, publish) | Done | `api_packages.cot`, `api_versions.cot` |
| Search (API + index) | Done | `api_search.cot`, `search_index.cot` |
| Bearer token auth (check only) | Done | `api_auth.cot` |
| Web UI (landing, list, detail, search, version) | Done | `web_pages.cot`, `web_templates.cot` |
| Static file serving | Done | `web_static.cot` |
| Semver validation on publish | Done | `semver_check.cot` |
| Immutable versions (409 Conflict) | Done | `api_versions.cot` |
| SHA-256 checksums on publish | Done | `api_versions.cot` |
| Manifest validation (name/version match) | Done | `api_versions.cot` |
| cot.json storage on publish | Done | `api_versions.cot`, `files.cot` |
| Source file listing + serving API | Done | `api_versions.cot` |
| Version detail web page | Done | `web_pages.cot` |
| Content-Length body reading | Done | `server.cot` |
| 42 inline tests | Done | across all modules |

## What's Next

### Phase 5: Publish Validation + Immutability -- DONE

1. ~~Validate cot.json on publish~~ -- manifest name/version must match URL
2. ~~Enforce semver~~ -- manual validation (can't use std/semver due to parse() name collision)
3. ~~Immutable versions~~ -- 409 Conflict on re-publish
4. ~~Store cot.json~~ -- saved to `data/packages/{name}/{version}/cot.json`
5. ~~Checksum~~ -- SHA-256 computed and stored in version metadata
6. ~~Dependency recording~~ -- extracted from manifest body and stored

**Note:** Cannot use `std/semver` because its `parse()` collides with `std/json`'s `parse()` in the flat symbol namespace. Used manual semver validation instead. See `PKG_COMPILER_BUGS.md` Bug #4.

### Phase 6: Source File Serving -- DONE

1. ~~File listing endpoint~~ -- `GET /api/packages/:name/:version/files` returns JSON array
2. ~~File serving endpoint~~ -- `GET /api/packages/:name/:version/files/:path` returns source
3. ~~Version detail page~~ -- `/packages/:name/:version` shows metadata, dependencies, files, install command
4. Source view page -- deferred (files served as plain text for now)
5. ~~Directory listing~~ -- uses `listDir` from `std/fs`

Also fixed: HTTP server now reads POST bodies correctly using Content-Length header loop (was single-read before).

### Phase 7: CLI Tool (`pkg`) -- DONE

Built as a separate Cot binary in `cli/`. Uses `std/http` tcpConnect for HTTP client calls to the registry API.

All commands working:
- ~~`pkg init`~~ — creates cot.json scaffold
- ~~`pkg search <query>`~~ — searches registry, displays results
- ~~`pkg info <name>`~~ — shows package details and versions
- ~~`pkg publish`~~ — reads cot.json, creates package + publishes version
- ~~`pkg add <name>[@version]`~~ — fetches latest, downloads files to `~/.cache/cot/packages/`, updates cot.json
- ~~`pkg install`~~ — installs all dependencies from cot.json to global cache
- ~~`pkg remove <name>`~~ — removes dependency from cot.json
- ~~`pkg list`~~ — lists dependencies from cot.json
- ~~`pkg login <token>`~~ — stores token at `~/.cot/credentials`

Packages install to a global cache at `~/.cache/cot/packages/{name}/{version}/` (like Zig's `~/.cache/zig/` and Deno's cache). No per-project `node_modules`-style directory.

### Phase 8: Compiler Integration

The Cot compiler needs to know about packages. Two pieces:

1. **Import resolution** — when `import "json-utils"` isn't found in `src/` or `stdlib/`, look in `~/.cache/cot/packages/json-utils/{version}/`
2. **`cot pkg` subcommand** — `cot pkg add`, `cot pkg publish`, etc. spawn the `pkg` binary (or inline the logic later)

This is a Zig compiler change, not a Cot change.

### Phase 9: Dependency Resolution -- DONE

1. ~~**Semver range matching**~~ — `^`, `~`, `>=`, exact match in `cli/src/semver.cot`
2. ~~**Transitive dependency resolution**~~ — recursive resolution with constraint accumulation in `cli/src/resolver.cot`
3. ~~**Conflict detection**~~ — errors when no version satisfies all accumulated constraints
4. ~~**Lock file**~~ — `cot.lock` records exact resolved versions; `pkg install` uses lock when current
5. ~~**Caret ranges by default**~~ — `pkg add foo@1.2.3` stores `^1.2.3` in cot.json

Flat dependency tree, no duplicates allowed. One version per package, error on conflict.

### Phase 10: Auth + User Accounts

The current auth is a placeholder (any Bearer token is accepted). Real auth needs:

1. **User registration** — `POST /api/users` or via web UI
2. **Token generation** — HMAC-SHA256 signed tokens with expiration
3. **Token validation** — verify signature and check expiration on publish
4. **Package ownership** — only the user who created a package can publish new versions
5. **Scoped tokens** — read-only vs publish tokens
6. **`pkg login`** — authenticate via CLI, store token at `~/.cot/credentials`

For initial deployment, consider GitHub OAuth for user identity (like JSR uses GitHub/Google SSO).

### Phase 11: Production Hardening

Before deploying to `cot.land`:

1. **Rate limiting** — prevent abuse on publish and search endpoints
2. **Request size limits** — enforce max upload size for published packages
3. **Error handling** — graceful error responses for all edge cases
4. **Logging** — structured request logging (method, path, status, duration)
5. **HTTPS** — TLS termination (reverse proxy via nginx/caddy, or native TLS if stdlib supports it)
6. **Persistence** — consider SQLite via FFI instead of JSON file (concurrent access, crash safety)
7. **Async I/O** — switch from single-threaded accept loop to `std/async` event loop for concurrent connections

### Phase 12: Fly.io Deployment

Deploy the registry to `cot.land` on Fly.io.

1. **Build pipeline** — Dockerfile that installs the Cot compiler, runs `cot build src/main.cot -o pkg`, and copies the binary into a minimal runtime image
2. **Persistent volume** — Fly volume mounted at `/data` for `registry.json` and `data/packages/` (package files). Registry must survive deploys and restarts
3. **fly.toml** — app config: internal port 8080, auto-stop disabled (always-on), single machine (single-threaded server), health check on `GET /`
4. **HTTPS** — Fly handles TLS termination automatically; no code changes needed
5. **DNS** — point `cot.land` to the Fly app (CNAME or A record)
6. **Health check endpoint** — `GET /` already returns the landing page (200 OK), usable as-is
7. **CLI registry URL** — update `cli/src/commands.cot` REGISTRY_HOST/PORT to point to `cot.land:443` (HTTPS), or make configurable via env var
8. **Backup** — periodic snapshot of the Fly volume (Fly supports volume snapshots)

**Blockers:**
- Phase 11 (production hardening) should come first — rate limiting, request size limits, logging
- The register allocator crash (Bug #1 in MEMORY) must be fixed to build the server binary
- CLI currently uses raw TCP on port 8080 — needs HTTPS support or a reverse proxy approach for talking to the production registry

## Priority Order

| Priority | Phase | Status |
|----------|-------|--------|
| ~~1~~ | ~~Phase 5: Publish validation~~ | DONE |
| ~~2~~ | ~~Phase 7: CLI tool~~ | DONE |
| 3 | Phase 8: Compiler integration | Next |
| ~~4~~ | ~~Phase 6: Source file serving~~ | DONE |
| ~~5~~ | ~~Phase 9: Dependency resolution~~ | DONE |
| 6 | Phase 10: Auth | Needed before public deployment |
| 7 | Phase 11: Production hardening | Needed before public deployment |
| 8 | Phase 12: Fly.io deployment | Blocked by Phase 11 + regalloc bug |

## Reference

Architecture modeled after [JSR](https://jsr.io) (the JavaScript/TypeScript registry):
- Immutable published versions
- Semver enforcement at publish time
- Source files served individually (not tarballs)
- Publish-time validation of package manifest
- Simple REST API + server-rendered web UI

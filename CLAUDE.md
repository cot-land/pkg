# cot.land Package Registry — AI Session Instructions

## ABSOLUTE #1 RULE — NEVER WORKAROUND, NEVER SIMPLIFY

**NEVER implement workarounds for missing Cot language features.** If the Cot compiler doesn't support a pattern you need, **STOP and tell the user** so they can implement the missing feature in the Zig compiler first. This is a dogfooding project — every workaround is tech debt that defeats the purpose.

- **NO** restructuring code to avoid a language limitation
- **NO** extracting logic to helper functions just because a construct doesn't compile
- **NO** falling back to if-else chains because switch doesn't support something
- **NO** simplifying data structures because generics don't work for a case
- **ALWAYS** identify the exact compiler limitation and report it to the user
- The user will fix the Zig compiler. That is the correct workflow.

## CRITICAL RULES

### 1. Never Invent — Port Reference Implementations

When implementing a component, **ALWAYS find the reference implementation FIRST**, read and understand it, then translate to Cot. Don't invent patterns — port them.

| Component | Reference Implementation |
|-----------|------------------------|
| HTTP server loop | Go `net/http.Server.Serve()` |
| Router / mux | Go `net/http.ServeMux` (Go 1.22 pattern matching) |
| Request parsing | Go `net/http.ReadRequest()` |
| JSON API | Go `encoding/json` + `net/http` handler pattern |
| Package registry | JSR `references/jsr/api/` (Rust backend) |
| Registry API design | JSR `references/jsr/api/src/api/` (endpoint structure) |
| Web UI | JSR `references/jsr/frontend/` (page structure) |
| Semver parsing | Go `golang.org/x/mod/semver` |
| URL query parsing | Go `net/url.ParseQuery()` |
| HTML templating | Go `html/template` (string concat equivalent) |
| Tar archive | Go `archive/tar` |
| File serving | Go `net/http.FileServer` |

### Reference Code

`references/jsr/` contains a shallow clone of the JSR registry (jsr.io) — the gold standard for modern package registries. Key directories:
- `references/jsr/api/src/` — Rust API backend (registry logic, publish, search)
- `references/jsr/frontend/` — Frontend (page layouts, components)
- Architecture decisions to copy: immutable versions, semver enforcement, publish-time validation

### 2. Cot Language Reference Is ~/cotlang/cot

The Cot compiler lives at `~/cotlang/cot`. When you need syntax examples, read `~/cotlang/cot/self/*.cot` for real working code. Read `~/cotlang/cot/docs/syntax.md` for the full syntax reference. **Never use archive folders.**

### 3. @safe Mode Enabled Project-Wide

This project uses `"safe": true` in `cot.json`. This enables:
- **Colon struct init**: `Type { field: value }` (not `.field = value`)
- **Implicit self**: methods get `self` injected automatically (no `self: *Type` parameter)
- **Auto-ref**: pass structs without `&`
- **`static fn`** constructors (no self injection)
- `/// doc comments`
- `test "name" { }` inline tests at bottom of files

### 4. Stdlib via Symlink

The Cot stdlib is resolved via a local symlink: `stdlib -> ~/cotlang/cot/stdlib`. This keeps the project always using the latest compiler stdlib. The symlink is gitignored.

**Setup (one-time):**
```bash
cd ~/cot-land/pkg
ln -s ~/cotlang/cot/stdlib stdlib
```

## Project Overview

**cot.land** is the official package registry for the Cot programming language. It's a web server + REST API + web UI written entirely in Cot, serving as the ultimate dogfooding exercise — proving the language can build real web services.

**Model:** Early deno.land/x with lessons learned — semver from day one, centralized hosting, immutable published versions. JSR proved that simple publish-time validation + static serving is the right architecture.

## CLI

```
# Registry server
cot check src/main.cot              # Type-check the full project
cot test src/router.cot             # Run router tests
cot test src/request.cot            # Run request parsing tests
cot build src/main.cot -o pkg       # Build the server binary
./pkg                               # Start server on port 8080

# CLI tool
cd cli/
cot check src/main.cot              # Type-check CLI
cot build src/main.cot -o pkg-cli   # Build CLI binary
./pkg-cli help                      # Show CLI usage
```

## Architecture

```
src/main.cot              Entry point — starts HTTP server, route dispatch
src/server.cot            HTTP server loop (accept, parse, route, respond)
src/router.cot            URL pattern matching + :param extraction
src/request.cot           Request struct, query string parsing
src/response.cot          Response builders (JSON, HTML, status codes)
src/package.cot           Package, Version, Dependency structs
src/user.cot              User, ApiToken structs
src/registry.cot          Package metadata store (in-memory + JSON persistence)
src/files.cot             Package file storage (on disk)
src/search_index.cot      Search index (in-memory text matching)
src/api_packages.cot      GET/POST /api/packages, GET /api/packages/:name
src/api_versions.cot      GET /api/packages/:name/:version, publish
src/api_search.cot        GET /api/search?q=...
src/api_auth.cot          Token validation, Bearer auth
src/web_pages.cot         HTML pages (landing, package list, detail, search)
src/web_templates.cot     HTML template helpers (head, nav, footer, layout)
src/web_static.cot        Static file serving (CSS)
src/semver_check.cot      Semver validation (manual, avoids std/semver name collision)

cli/src/main.cot          CLI entry point, argument parsing
cli/src/commands.cot      All CLI commands (init, publish, add, search, etc.)
cli/src/http_client.cot   HTTP client for registry API calls
```

**Note:** All source files are flat in `src/` because Cot resolves imports relative to the importing file's directory. No `..` import paths. This matches cotty's pattern.

```
HTTP Request → server.cot (accept + read)
  → request.cot (parse into Request struct)
  → router.cot (match route pattern, extract params)
  → main.cot dispatch() (handler ID switch)
    → api_packages.cot / api_versions.cot / api_search.cot (API handlers)
    → web_pages.cot (HTML page handlers)
    → registry.cot / files.cot (data access)
    → response.cot (build Response)
  → server.cot (write response, close connection)
```

## Reference File Map

| pkg File | Go Reference |
|----------|-------------|
| `src/server.cot` | `net/http/server.go` (Server.Serve, conn.serve) |
| `src/router.cot` | `net/http/routing_tree.go` (ServeMux pattern matching) |
| `src/request.cot` | `net/http/request.go` (ReadRequest, parseForm) |
| `src/response.cot` | `net/http/server.go` (response.Write, WriteHeader) |
| `src/registry.cot` | Go module index (in-memory map + JSON persistence) |
| `src/files.cot` | Go module cache (package file storage on disk) |

## Testing

```bash
cot test src/router.cot            # Router pattern matching (15 tests)
cot test src/request.cot           # Query string parsing (7 tests)
cot test src/response.cot          # Response building (5 tests)
cot test src/registry.cot          # Registry persistence (8 tests)
cot test src/search_index.cot      # Search matching (10 tests)
cot test src/semver_check.cot      # Semver validation (2 tests)
cot check src/main.cot             # Full type-check (all files)
```

Every file has inline `test "name" { }` blocks. Run `cot test <file>` to execute them. 42 unique tests across all modules. Note: `cot test` runs tests from imported modules transitively, so counts above include transitive tests.

## Documents

| Document | Purpose |
|----------|---------|
| `~/cotlang/cot/claude/PKG_COMPILER_BUGS.md` | Compiler bugs found during pkg development (all fixed) |
| `references/jsr/` | Shallow clone of JSR registry — reference architecture |

## Behavioral Guidelines

**DO:**
- Find the Go reference implementation before writing ANY component
- Copy `~/cotlang/cot/self/` code patterns exactly (colon init, implicit self, static fn)
- Write inline tests for every module
- Use `cot check` and `cot test` to verify changes
- Make incremental changes, verify each one
- Report missing Cot features to the user immediately

**DO NOT:**
- Invent patterns — port reference implementations
- Work around compiler limitations
- Skip testing
- Use period-prefix struct init (`.field = value`) — use colon syntax (`field: value`)
- Comment out failing tests or leave TODOs
- Read from archive folders — always use `~/cotlang/cot`

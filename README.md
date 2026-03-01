# cot.land

The official package registry for the [Cot](https://github.com/cotlang/cot) programming language.

Written entirely in Cot as a dogfooding exercise — proving the language can build real web services.

## Status

**v0.1.0** — Early development. Registry server and CLI tool are working end-to-end.

Working:
- HTTP server with route matching and `:param` extraction
- REST API: list, get, search, create, and publish packages
- Web UI: landing page, package list, package detail, version detail, search
- In-memory registry with JSON file persistence
- Package file storage on disk with source file serving
- Semver validation and immutable versions on publish
- SHA-256 checksums on published content
- Bearer token auth on publish/create endpoints
- CLI tool: init, publish, add, install, remove, search, info, list, login
- 42 inline tests passing

## Quick Start

```bash
# Link the Cot stdlib (one-time setup)
ln -s ~/cotlang/cot/stdlib stdlib
ln -s ~/cotlang/cot/stdlib cli/stdlib

# Build registry server
cot build src/main.cot -o pkg

# Build CLI tool
cd cli && cot build src/main.cot -o pkg-cli && cd ..

# Start registry
./pkg
# => cot.land registry v0.1.0
# => cot.land registry listening on :8080
```

Visit `http://localhost:8080` for the web UI.

## CLI Tool

```bash
pkg-cli init                  # Create cot.json
pkg-cli publish               # Publish current package
pkg-cli add <name>            # Add latest version as dependency
pkg-cli add <name>@<version>  # Add specific version
pkg-cli install               # Install all dependencies to global cache
pkg-cli remove <name>         # Remove dependency
pkg-cli search <query>        # Search registry
pkg-cli info <name>           # Show package details
pkg-cli list                  # List dependencies
pkg-cli login <token>         # Store auth token
```

## API

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/packages` | List all packages |
| `GET` | `/api/packages/:name` | Get package metadata |
| `GET` | `/api/packages/:name/:version` | Get version metadata |
| `POST` | `/api/packages` | Create a package (auth required) |
| `POST` | `/api/packages/:name/:version` | Publish a version (auth required) |
| `GET` | `/api/search?q=term` | Search packages |
| `GET` | `/api/packages/:name/:version/files` | List published files |
| `GET` | `/api/packages/:name/:version/files/:path` | Serve source file |

### Examples

```bash
# Create a package
curl -X POST http://localhost:8080/api/packages \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name": "hello", "description": "A hello world package"}'

# Publish a version
curl -X POST http://localhost:8080/api/packages/hello/1.0.0 \
  -H "Authorization: Bearer <token>" \
  -d '<package source>'

# List packages
curl http://localhost:8080/api/packages

# Search
curl http://localhost:8080/api/search?q=hello
```

## Project Structure

```
src/
  main.cot              Entry point, route registration, dispatch
  server.cot            TCP accept loop, HTTP read/write
  router.cot            URL pattern matching with :param extraction
  request.cot           HTTP request parsing, query strings
  response.cot          Response builders (JSON, HTML, status codes)
  package.cot           Package + Version data models
  registry.cot          In-memory registry with JSON persistence
  files.cot             Package file storage on disk
  search_index.cot      Text search over packages
  api_packages.cot      Package API handlers
  api_versions.cot      Version + publish API handlers
  api_search.cot        Search API handler
  api_auth.cot          Bearer token auth
  web_pages.cot         HTML page rendering
  web_templates.cot     HTML layout helpers
  web_static.cot        Static file serving
  semver_check.cot      Semver validation
  user.cot              User + API token models

cli/
  src/main.cot          CLI entry point, argument parsing
  src/commands.cot      All CLI commands
  src/http_client.cot   HTTP client for registry API calls
```

## Testing

```bash
cot test src/router.cot        # 15 tests
cot test src/request.cot       # 7 tests
cot test src/response.cot      # 5 tests
cot test src/registry.cot      # 8 tests
cot test src/search_index.cot  # 10 tests
cot test src/semver_check.cot  # 2 tests
cot check src/main.cot         # full type-check
```

## Architecture

The server is a single-threaded accept loop ported from Go's `net/http.Server.Serve`. The router uses Go 1.22-style pattern matching (`GET /api/packages/:name`). Handlers return response strings — no function pointers, just handler-ID dispatch via an if-chain in `main.cot`.

Registry data is kept in memory and persisted to `data/registry.json`. Package source files are stored under `data/packages/{name}/{version}/`.

Packages are installed to a global cache at `~/.cache/cot/packages/{name}/{version}/` (similar to Zig and Deno), not per-project like `node_modules`.

## License

MIT

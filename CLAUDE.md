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

### 2. Cot Language Reference

See the **Cot Language Quick Reference** section at the bottom of this file. For working code examples, read `~/cotlang/cot/self/*.cot`. For the full syntax reference, read `~/cotlang/cot/docs/syntax.md`. **Never use archive folders.**

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
./pkg token create <owner>          # Generate auth token for owner

# CLI tool
cd cli/
cot check src/main.cot              # Type-check CLI
cot build src/main.cot -o pkg-cli   # Build CLI binary
./pkg-cli help                      # Show CLI usage

# Deployment
cot build src/main.cot -o pkg --target=amd64-linux  # Cross-compile for Fly.io
fly deploy                          # Deploy to Fly.io
```

## Architecture

```
src/main.cot              Entry point — server, route dispatch, token CLI, env config
src/server.cot            HTTP server loop (accept, parse, route, respond)
src/router.cot            URL pattern matching + :param extraction
src/request.cot           Request struct, query string parsing
src/response.cot          Response builders (JSON, HTML, status codes, status extraction)
src/db.cot                SQLite storage (packages, versions, deps, tokens)
src/package.cot           Package, Version, Dependency structs
src/user.cot              User, ApiToken structs
src/files.cot             Package file storage (on disk)
src/search_index.cot      Search index (in-memory text matching)
src/api_packages.cot      GET/POST /api/packages, GET /api/packages/:name
src/api_versions.cot      GET /api/packages/:name/:version, publish
src/api_search.cot        GET /api/search?q=...
src/api_auth.cot          Token validation, Bearer auth, DB-backed token verification
src/web_pages.cot         HTML pages (landing, package list, detail, search)
src/web_templates.cot     HTML template helpers (head, nav, footer, layout)
src/web_static.cot        Static file serving (CSS)
src/semver_check.cot      Semver validation (manual, avoids std/semver name collision)

cli/src/main.cot          CLI entry point, argument parsing
cli/src/commands.cot      All CLI commands (init, publish, add, search, etc.)
cli/src/http_client.cot   HTTP client for registry API calls
cli/src/semver.cot        Semver parsing, comparison, range matching (^, ~, >=, exact)
cli/src/resolver.cot      Transitive dependency resolution with constraint accumulation
```

**Note:** All source files are flat in `src/` because Cot resolves imports relative to the importing file's directory. No `..` import paths. This matches cotty's pattern.

```
HTTP Request → server.cot (accept + read)
  → request.cot (parse into Request struct)
  → router.cot (match route pattern, extract params)
  → main.cot dispatch() (handler ID switch)
    → api_packages.cot / api_versions.cot / api_search.cot (API handlers)
    → api_auth.cot (token validation via DB)
    → web_pages.cot (HTML page handlers)
    → db.cot / files.cot (data access)
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
| `src/db.cot` | Go module index (SQLite-backed) |
| `src/files.cot` | Go module cache (package file storage on disk) |
| `src/api_auth.cot` | JSR `api/src/token.rs` (token validation) |

## Testing

```bash
cot test src/db.cot                # DB operations + token auth (26 tests)
cot test src/router.cot            # Router pattern matching (15 tests)
cot test src/request.cot           # Query string parsing (7 tests)
cot test src/response.cot          # Response building (6 tests)
cot test src/api_auth.cot          # Auth + token validation (3 tests)
cot test src/search_index.cot      # Search matching (10 tests)
cot test src/semver_check.cot      # Semver validation (2 tests)
cot check src/main.cot             # Full type-check (all files)
```

Every file has inline `test "name" { }` blocks. Run `cot test <file>` to execute them. Note: `cot test` runs tests from imported modules transitively, so counts above include transitive tests.

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

---

## Cot Language Quick Reference

### CLI

```
cot build <file.cot>           # Compile to executable
cot run <file.cot> [-- args]   # Compile + run
cot test <file.cot>            # Run tests
cot check <file.cot>           # Type-check only
```

### Critical Facts

- **No semicolons** — newlines terminate statements
- **`string` is `[]u8`** (a slice) — use `.len` for length, `[i]` for indexing
- **`print`/`println` are compiler builtins** — no import needed, work with string, int, float, bool
- **String interpolation uses `${}`** — `"value: ${x}"`, NOT `{x}`
- **`++` for concatenation** — strings, arrays, slices. `+` on strings is an error (use `++`)
- **Parens required** on `if`/`while` — `if (x > 0) { ... }`
- **`and`/`or`/`not`** keywords (or `&&`/`||`/`!`)

### Types

```
i8 i16 i32 i64          // signed integers
u8 u16 u32 u64          // unsigned integers
f32 f64                  // floating point
bool                     // true / false
string                   // alias for []u8
int                      // alias for i64
float                    // alias for f64
*T  ?T  E!T  !T         // pointer, optional, error union
[]T  [N]T  [K]V  [T]    // slice, array, map, list
```

### Variables

```cot
const x = 10             // immutable
var y = 20               // mutable
```

### Functions

```cot
fn add(a: i64, b: i64) i64 { return a + b }
fn noop() void { }
```

### Structs

```cot
struct Point { x: i64, y: i64 }

// Stack init (period + equals):
var p = Point { .x = 10, .y = 20 }

// Heap init (new, colon, no period):
var p = new Point { x: 10, y: 20 }

// Methods inside struct body:
struct Counter {
    value: i64

    fn increment(self: *Counter) void {
        self.value = self.value + 1
    }

    static fn zero() Counter {
        return Counter { .x = 0, .y = 0 }
    }
}
```

### @safe Mode

Projects with `"safe": true` in cot.json get TypeScript-like ergonomics:
- Colon struct init: `Point { x: 10, y: 20 }` (no period, no equals)
- Implicit self: `fn getX() i64 { return self.x }` (self injected)
- Auto-ref: `foo(myStruct)` — no `&` needed, structs passed by reference
- Field shorthand: `new Point { x, y }` → `new Point { x: x, y: y }`

### Print (compiler builtins — NO import needed)

```cot
print(value)             // stdout, no newline
println(value)           // stdout + newline
eprint(value)            // stderr, no newline
eprintln(value)          // stderr + newline

// Works with: string, int, float, bool
println("hello")
println(42)
println(3.14)
println(true)

// String interpolation:
println("x = ${x}, y = ${y}")
```

### Error Handling

```cot
const MyError = error { Fail, NotFound }

fn mayFail(x: i64) MyError!i64 {
    if (x < 0) { return error.Fail }
    return x * 2
}

var x = try mayFail(5)          // propagate error
var y = mayFail(-1) catch 99    // handle with fallback
```

### Control Flow

```cot
if (x > 0) { ... } else { ... }
while (x < 10) { x = x + 1 }
for item in collection { ... }
for i in 0..10 { ... }

// Optional unwrap:
if (optional) |val| { use(val) }

// Switch:
switch (x) {
    1 => result1,
    2, 3 => result2,
    else => default,
}
```

### Imports & Stdlib

```cot
import "std/list"        // List(T) dynamic array
import "std/map"         // Map(K,V) hash map
import "std/string"      // string utilities (indexOf, split, trim, etc.)
import "std/fs"          // File I/O
import "std/os"          // exit, args
import "std/json"        // JSON parse/encode
import "std/http"        // TCP sockets, HTTP
import "std/fmt"         // ANSI colors, formatting
import "std/time"        // timestamps
import "std/io"          // buffered I/O
import "std/math"        // math functions
import "std/sys"         // low-level: alloc, dealloc, fd_write, fd_read
```

### Testing

```cot
test "my test" {
    @assertEq(1 + 1, 2)
    @assert(true)
}
```

Run: `cot test file.cot`

### Generics

```cot
fn max(T)(a: T, b: T) T {
    if (a > b) { return a }
    return b
}
max(i64)(3, 7)
```

### Memory

```cot
var ptr = new Foo { x: 42 }     // heap-allocated, ARC managed
defer dealloc(addr)              // manual cleanup for raw alloc
ptr.*                            // dereference
&expr                            // address-of
```

### Common Builtins

```
@sizeOf(T)               // size of type in bytes
@intCast(T, value)       // integer cast
@ptrOf(s)                // raw pointer from string
@lenOf(s)                // length from string (prefer s.len)
@intToPtr(*T, addr)      // integer to pointer
@ptrToInt(ptr)           // pointer to integer
@assert(cond)            // assert (test-only)
@assertEq(a, b)          // assert equal (test-only)
@trap()                  // unreachable/abort
```

### Full Reference

See https://github.com/cotlang/cot/blob/main/docs/syntax.md

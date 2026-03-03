# Package Ecosystem Vision

The design of Cot's package registry, dependency management, and native library integration.

---

## Architecture: Port JSR

cot.land is a full JSR port — not a simplified clone. The reference implementation is `references/jsr/` (Rust API backend, Postgres, GCS). Every component maps 1:1:

| JSR (Reference) | cot.land (Target) | Bootstrap (Current) |
|------------------|--------------------|---------------------|
| Rust API backend | Cot API backend | Cot API backend |
| Postgres | Postgres (via registry package) | SQLite (via `std/sqlite`) |
| GCS file storage | Cloud storage | Local disk (`data/packages/`) |
| Cloudflare CDN | CDN | Direct serving |
| OAuth + API tokens | API tokens | API tokens |

The "Bootstrap" column is what exists today to get cot.land running. The "Target" column is the full JSR-equivalent architecture.

---

## Package Types

### Standard Library (`std/*`)

Ships with the Cot compiler. Core language essentials only:

- Collections: `std/list`, `std/map`
- I/O: `std/fs`, `std/io`, `std/os`, `std/sys`
- Networking: `std/http`, `std/net`
- Data: `std/json`, `std/string`, `std/math`
- Dev: `std/log`, `std/time`, `std/fmt`
- Crypto: `std/crypto`, `std/random`

**Rule:** If most projects don't need it, it doesn't belong in std.

### Registry Packages (`cot.land/*`)

Hosted on cot.land. Installed via `cot add`. Can bundle C source files for native library bindings.

Examples:
- `sqlite` — SQLite bindings (bundles `sqlite3.c` amalgamation)
- `postgres` — Postgres bindings (bundles libpq or a pure-Cot wire protocol)
- `image` — Image processing (bundles stb_image)
- `compression` — zlib/gzip (bundles miniz)
- `yaml`, `toml`, `csv` — Format parsers (pure Cot)

---

## C Source Bundling

### The Design

The Cot compiler can compile C source files that a package provides. The compiler itself ships no C code — packages bring their own.

```json
{
  "name": "sqlite",
  "version": "1.0.0",
  "c_sources": ["vendor/sqlite3.c"],
  "c_flags": ["-DSQLITE_OMIT_LOAD_EXTENSION", "-DSQLITE_THREADSAFE=0"]
}
```

When a project depends on a package with `c_sources`, the Cot compiler:
1. Compiles the C files for the target architecture (using the embedded Zig C compiler)
2. Links the resulting objects into the final binary
3. Cross-compilation just works — no system libraries needed

### Why This Works

- Zig's C compiler (which Cot's backend uses) can cross-compile C to any target
- SQLite, libpq, stb_*, miniz, etc. are all designed to be compiled from source
- The Cot compiler download stays minimal — no C code bundled
- Packages are self-contained — `cot add sqlite` brings everything needed

### The Boundary

| Ships with Cot | Lives on cot.land |
|----------------|-------------------|
| Compiler + tools | SQLite bindings |
| Standard library | Postgres bindings |
| Zig C compiler (already embedded) | Image libraries |
| Cross-compilation targets | Compression |
| LSP, formatter, linter | Any C library wrapper |

The compiler provides the **capability** to compile C. Packages provide the **C source**.

---

## Bootstrap Sequence

There's a chicken-and-egg problem: the registry needs a database, but the database package should live on the registry.

### Phase 1: Bootstrap (Current)

- `std/sqlite` exists in stdlib as a temporary measure
- cot.land runs on SQLite with `std/sqlite`
- Server builds and deploys — registry is live
- CLI tool (`cot add`, `cot publish`) works

### Phase 2: C Source Support

- Add `c_sources` field support to the compiler
- Publish `sqlite` package to cot.land (bundles `sqlite3.c`)
- Publish `postgres` package to cot.land (bundles libpq or pure wire protocol)

### Phase 3: Migration

- Migrate cot.land from SQLite to Postgres (full JSR parity)
- Remove `std/sqlite` from stdlib (it's now a registry package)
- cot.land depends on the `postgres` package from its own registry
- The registry hosts itself — bootstrap complete

### Phase 4: Full JSR Parity

- Cloud storage for package files (S3/GCS)
- CDN for package serving
- OAuth for user authentication
- Publishing validation (type-checking, documentation generation)
- Scoped packages, organizations, access control

---

## CLI Commands (Target)

```bash
cot init                    # Create project with cot.json
cot add sqlite              # Add dependency from cot.land
cot add sqlite@^1.2.0       # Add with version constraint
cot remove sqlite           # Remove dependency
cot install                 # Install all dependencies from cot.lock
cot publish                 # Publish package to cot.land
cot search <query>          # Search cot.land
cot info <package>          # Show package details
```

These are currently implemented as a separate `pkg-cli` binary. The target is integration into the `cot` compiler itself (Phase 8 in the pkg roadmap — requires compiler changes for import resolution from `~/.cache/cot/packages/`).

---

## Key Design Decisions

1. **Immutable versions** — Once published, a version cannot be modified or deleted (JSR model)
2. **Semver enforced** — All versions must be valid semver, ranges use `^` (caret) by default
3. **Flat namespace** — No scopes initially, keep it simple (can add later)
4. **Source distribution** — Packages publish source, not compiled artifacts
5. **No lock-in** — Packages are just Cot source files. No custom binary format.
6. **C sources are opt-in** — Pure Cot packages have zero build complexity. C sources only for FFI wrappers.

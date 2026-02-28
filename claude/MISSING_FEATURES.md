# Missing Cot Features for Package Registry

These features are needed to build the cot.land package registry. Each section describes what's missing, what the Zig equivalent is, and what needs to be implemented.

## 1. Directory Creation — `mkdir`

**Need:** Create directories for storing package files: `data/`, `data/packages/`, `data/packages/{name}/{version}/`

**Zig equivalent:** `std.fs.cwd().makeDir(path)` / `std.fs.makeDirAbsolute(path)`

**What to implement:**

### Runtime (both Wasm and Native)
Add to `sys.cot`:
```
extern fn mkdir(path_ptr: i64, path_len: i64, mode: i64) i64
```

### Native backend (`io_native.zig`)
Call libc `mkdir(path, mode)`. Returns 0 on success, -1 on error.

### Wasm backend (`wasi_runtime.zig`)
Call WASI `path_create_directory` or implement via libc.

### Stdlib (`fs.cot`)
```cot
fn mkdir(path: string) FsError!void {
    var result = mkdir(@ptrOf(path), @lenOf(path), 493)  // 0o755
    if (result < 0) { return error.IoError }
}

fn mkdirAll(path: string) FsError!void {
    // Create each path component, ignoring "already exists" errors
}
```

**Priority:** HIGH — blocks Phase 2 (package storage)

---

## 2. Directory Listing — `readdir`

**Need:** List packages stored on disk, list versions of a package.

**Zig equivalent:** `std.fs.cwd().openDir(path)` → `dir.iterate()`

**What to implement:**

### Runtime
Add to `sys.cot`:
```
extern fn dir_open(path_ptr: i64, path_len: i64) i64
extern fn dir_next(handle: i64, name_buf: i64, name_buf_len: i64) i64
extern fn dir_close(handle: i64) void
```

`dir_next` returns: name length (>0) on success, 0 when done, -1 on error.

### Native backend (`io_native.zig`)
Call libc `opendir()`, `readdir()`, `closedir()`.

### Stdlib (`fs.cot`)
```cot
fn listDir(path: string) FsError!List(string) {
    var handle = dir_open(@ptrOf(path), @lenOf(path))
    if (handle < 0) { return error.NotFound }
    var entries: List(string) = .{}
    var buf = alloc(0, 256)
    while (true) {
        var n = dir_next(handle, buf, 256)
        if (n == 0) { break }
        if (n < 0) { dir_close(handle); dealloc(buf); return error.IoError }
        var name = substring(@string(buf, n), 0, n)
        // Skip . and ..
        if (name != "." and name != "..") {
            entries.append(name)
        }
    }
    dir_close(handle)
    dealloc(buf)
    return entries
}
```

**Priority:** HIGH — blocks Phase 2 (package storage)

---

## 3. File/Directory Type Check — `stat`

**Need:** Distinguish files from directories when listing packages.

**Zig equivalent:** `std.fs.cwd().statFile(path)` → check `kind == .directory`

**What to implement:**

### Runtime
Add to `sys.cot`:
```
extern fn stat_type(path_ptr: i64, path_len: i64) i64
```

Returns: 1 = regular file, 2 = directory, 0 = not found, -1 = error.

### Native backend (`io_native.zig`)
Call libc `stat()`, check `st_mode & S_IFMT`.

### Stdlib (`fs.cot`)
```cot
fn isDir(path: string) bool {
    return stat_type(@ptrOf(path), @lenOf(path)) == 2
}

fn isFile(path: string) bool {
    return stat_type(@ptrOf(path), @lenOf(path)) == 1
}
```

**Priority:** MEDIUM — useful but can work around with `fileExists` + convention

---

## 4. File Deletion — `unlink`

**Need:** Delete package files if a publish is rolled back.

**Zig equivalent:** `std.fs.cwd().deleteFile(path)`

**What to implement:**

### Runtime
Add to `sys.cot`:
```
extern fn unlink(path_ptr: i64, path_len: i64) i64
```

### Native backend (`io_native.zig`)
Call libc `unlink()`.

### Stdlib (`fs.cot`)
```cot
fn deleteFile(path: string) FsError!void {
    var result = unlink(@ptrOf(path), @lenOf(path))
    if (result < 0) { return error.IoError }
}
```

**Priority:** LOW — nice to have, not blocking

---

## Summary

| Feature | sys.cot extern | io_native.zig | fs.cot wrapper | Priority |
|---------|---------------|---------------|----------------|----------|
| mkdir | `mkdir(ptr, len, mode)` | libc `mkdir` | `mkdir()`, `mkdirAll()` | HIGH |
| readdir | `dir_open/next/close` | libc `opendir/readdir/closedir` | `listDir()` | HIGH |
| stat | `stat_type(ptr, len)` | libc `stat` | `isDir()`, `isFile()` | MEDIUM |
| unlink | `unlink(ptr, len)` | libc `unlink` | `deleteFile()` | LOW |

**Note:** Phase 1 (HTTP server, router, request/response) does NOT need any of these features. They are only needed starting in Phase 2 (package storage).

---

## 5. COMPILER BUG — Native Codegen Register Allocator Crash

**Symptom:** `cot build src/main.cot -o pkg` crashes with:
```
[liveness] EntryLivein error: entry block has live-in vregs:
  entry block idx: 0, num_vregs: 883
  vreg v804, v805, v817, v819
thread panic: incorrect alignment
  in codegen.native.regalloc.liveness.computeLiveness
```

**Context:** `cot check` passes cleanly. `cot test` for individual modules works (42 tests pass). Only `cot build` of the full project crashes.

**Root cause:** Register allocator liveness analysis produces "entry block has live-in vregs" error on a function with 883 virtual registers. The function is likely `dispatch()` in main.cot (the big handler-dispatch switch with many route branches).

**Location:** `compiler/codegen/native/regalloc/liveness.zig` (`computeLiveness`)

**Workaround:** None — this is a compiler bug. Individual `cot test` still works for development.

**Priority:** HIGH — blocks running the server binary

**Similar known bug:** MEMORY.md notes "Codegen crash on app.cot — wasm_to_clif null panic on local.set (blocks cot run)" in cotty.

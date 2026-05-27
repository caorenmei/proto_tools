# Protoc CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimal `protoc`-style Lua CLI that compiles one or more proto3 files into a descriptor set using `lua-protobuf`.

**Architecture:** Keep the command-line entrypoint thin and move all reusable behavior into `src/protoc_cli/`. Parse argv into a normalized config, resolve user inputs against `--proto_path`, collect parsed `FileDescriptorProto` objects with `lua-protobuf`'s `protoc` parser, then encode and write a single `FileDescriptorSet` binary. Test both the reusable modules and the real CLI with fixture `.proto` files that cover proto3 features, including `service` and `option`.

**Tech Stack:** Lua 5.4, project-local LuaRocks tree, `argparse`, `lua-protobuf` (`protoc` + `pb`), `busted`

---

## File Structure

- `tools/protoc_cli.lua` — command entrypoint; prints stderr messages and exits with the right code.
- `src/protoc_cli/args.lua` — parses `--proto_path`, `--descriptor_set_out`, and positional input files into a normalized config.
- `src/protoc_cli/path_search.lua` — resolves user-supplied proto filenames and imports against the configured search roots.
- `src/protoc_cli/compiler.lua` — drives `protoc.new()`, deduplicates imported descriptors, and returns encoded `FileDescriptorSet` bytes.
- `src/protoc_cli/write_descriptor.lua` — writes binary descriptor bytes to the requested output path.
- `tests/support/env.lua` — ensures specs can `require("protoc_cli.*")` from `src/`.
- `tests/fixtures/protoc/imports/shared.proto` — shared imported proto types used by end-to-end tests.
- `tests/fixtures/protoc/full_feature.proto` — main proto3 fixture covering message, enum, nested types, map, oneof, proto3 optional, reserved, service, and options.
- `tests/fixtures/protoc/secondary.proto` — second input proto that imports the main fixture to validate multi-input compilation.
- `tests/fixtures/protoc/bad_syntax.proto` — intentionally broken fixture used to assert compiler error propagation.
- `tests/protoc_cli/args_spec.lua` — specs for argv parsing and validation.
- `tests/protoc_cli/path_search_spec.lua` — specs for proto path resolution and missing-file errors.
- `tests/protoc_cli/compiler_spec.lua` — specs for descriptor generation, import deduplication, descriptor inspection, and encode/decode validation.
- `tests/protoc_cli/write_descriptor_spec.lua` — specs for binary writes and write failures.
- `tests/protoc_cli/cli_spec.lua` — end-to-end specs that execute `tools/protoc_cli.lua`.

## Task 1: Establish the test harness and argument parser spec

**Files:**
- Create: `tests/support/env.lua`
- Create: `tests/protoc_cli/args_spec.lua`
- Test: `tests/protoc_cli/args_spec.lua`

- [ ] **Step 1: Write the support loader and failing argument parser spec**

```lua
-- tests/support/env.lua
package.path = table.concat({
  "src/?.lua",
  "src/?/init.lua",
  "./?.lua",
  package.path,
}, ";")

package.cpath = table.concat({
  "lua_modules/lib/lua/5.4/?.so",
  package.cpath,
}, ";")

return true
```

```lua
-- tests/protoc_cli/args_spec.lua
require("tests.support.env")

local args = require("protoc_cli.args")

describe("protoc_cli.args.parse", function()
  it("parses repeated proto_path options and positional inputs", function()
    local ok, config = args.parse({
      "--proto_path", "tests/fixtures/protoc",
      "--proto_path", "tests/fixtures/protoc/imports",
      "--descriptor_set_out", "tests/tmp/out.pb",
      "full_feature.proto",
      "secondary.proto",
    })

    assert.is_true(ok)
    assert.are.same({
      proto_paths = {
        "tests/fixtures/protoc",
        "tests/fixtures/protoc/imports",
      },
      descriptor_set_out = "tests/tmp/out.pb",
      inputs = {
        "full_feature.proto",
        "secondary.proto",
      },
    }, config)
  end)

  it("defaults proto_path to the current directory when none is provided", function()
    local ok, config = args.parse({
      "--descriptor_set_out", "tests/tmp/out.pb",
      "full_feature.proto",
    })

    assert.is_true(ok)
    assert.are.same({ "." }, config.proto_paths)
  end)

  it("returns a structured validation error when descriptor_set_out is missing", function()
    local ok, err = args.parse({ "full_feature.proto" })

    assert.is_false(ok)
    assert.are.equal(2, err.exit_code)
    assert.are.equal("missing required option '--descriptor_set_out'", err.message)
  end)
end)
```

- [ ] **Step 2: Run the spec and confirm it fails because the module does not exist yet**

Run:

```bash
cd /home/lenovo/source/repos/gen_model
./lua_modules/bin/busted tests/protoc_cli/args_spec.lua
```

Expected: FAIL with `module 'protoc_cli.args' not found`

- [ ] **Step 3: Implement the argument parser module**

```lua
-- src/protoc_cli/args.lua
local argparse = require("argparse")

local M = {}

local function new_parser()
  local parser = argparse("protoc_cli", "Generate a protobuf descriptor set")
  parser:option("--proto_path")
    :count("*")
    :argname("<path>")
  parser:option("--descriptor_set_out")
    :argname("<file>")
  parser:argument("inputs")
    :args("+")
    :argname("<proto>")
  return parser
end

function M.parse(argv)
  local ok, parsed_or_err = new_parser():pparse(argv)
  if not ok then
    return false, {
      exit_code = 2,
      message = parsed_or_err,
    }
  end

  if not parsed_or_err.descriptor_set_out then
    return false, {
      exit_code = 2,
      message = "missing required option '--descriptor_set_out'",
    }
  end

  local proto_paths = parsed_or_err.proto_path or {}
  if #proto_paths == 0 then
    proto_paths = { "." }
  end

  return true, {
    proto_paths = proto_paths,
    descriptor_set_out = parsed_or_err.descriptor_set_out,
    inputs = parsed_or_err.inputs,
  }
end

return M
```

- [ ] **Step 4: Re-run the spec and confirm it passes**

Run:

```bash
cd /home/lenovo/source/repos/gen_model
./lua_modules/bin/busted tests/protoc_cli/args_spec.lua
```

Expected: PASS with `3 successes`

- [ ] **Step 5: Commit the harness and args parser**

```bash
cd /home/lenovo/source/repos/gen_model
git add tests/support/env.lua tests/protoc_cli/args_spec.lua src/protoc_cli/args.lua
git commit -m "feat: add protoc cli argument parsing"
```

## Task 2: Add proto fixtures and path resolution

**Files:**
- Create: `tests/fixtures/protoc/imports/shared.proto`
- Create: `tests/fixtures/protoc/full_feature.proto`
- Create: `tests/fixtures/protoc/secondary.proto`
- Create: `tests/protoc_cli/path_search_spec.lua`
- Create: `src/protoc_cli/path_search.lua`
- Test: `tests/protoc_cli/path_search_spec.lua`

- [ ] **Step 1: Write the fixture protos and the failing path resolver spec**

```proto
// tests/fixtures/protoc/imports/shared.proto
syntax = "proto3";

package demo.shared;

message SharedNote {
  string id = 1;
  bool enabled = 2;
}

enum SharedKind {
  SHARED_KIND_UNSPECIFIED = 0;
  SHARED_KIND_PRIMARY = 1;
  SHARED_KIND_SECONDARY = 2;
}
```

```proto
// tests/fixtures/protoc/full_feature.proto
syntax = "proto3";

package demo.full;

import "imports/shared.proto";

option java_package = "com.example.demo.full";

message Envelope {
  message Nested {
    string source = 1;
  }

  enum Kind {
    KIND_UNSPECIFIED = 0;
    KIND_API = 1;
    KIND_BATCH = 2;
  }

  Kind kind = 1;
  Nested nested = 2;
}

message RichMessage {
  option deprecated = true;

  string plain_name = 1 [json_name = "plainName", deprecated = true];
  repeated string labels = 2;
  map<string, int32> counters = 3;

  oneof payload {
    string text = 4;
    bytes raw = 5;
  }

  optional string nickname = 6;
  demo.shared.SharedNote note = 7;
  demo.shared.SharedKind current_kind = 8;
  Envelope envelope = 9;

  reserved 10, 11 to 12;
  reserved "old_name";
}

service EchoService {
  option deprecated = true;

  rpc Send(RichMessage) returns (RichMessage) {
    option deprecated = true;
  }
}
```

```proto
// tests/fixtures/protoc/secondary.proto
syntax = "proto3";

package demo.secondary;

import "full_feature.proto";
import "imports/shared.proto";

message AuditEntry {
  string actor = 1;
  demo.full.RichMessage payload = 2;
  demo.shared.SharedNote note = 3;
}
```

```lua
-- tests/protoc_cli/path_search_spec.lua
require("tests.support.env")

local path_search = require("protoc_cli.path_search")

describe("protoc_cli.path_search", function()
  it("resolves positional inputs relative to proto_path", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local resolved = assert(resolver:resolve_input("full_feature.proto"))

    assert.are.equal("full_feature.proto", resolved.import_name)
    assert.is_true(resolved.absolute_path:match("tests/fixtures/protoc/full_feature%.proto$") ~= nil)
  end)

  it("resolves imports using the same search roots", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local resolved = assert(resolver:resolve_import("imports/shared.proto"))

    assert.are.equal("imports/shared.proto", resolved.import_name)
    assert.is_true(resolved.absolute_path:match("tests/fixtures/protoc/imports/shared%.proto$") ~= nil)
  end)

  it("returns a structured error for missing files", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local resolved, err = resolver:resolve_input("missing.proto")

    assert.is_nil(resolved)
    assert.are.equal(1, err.exit_code)
    assert.is_true(err.message:match("missing%.proto") ~= nil)
    assert.is_true(err.message:match("tests/fixtures/protoc") ~= nil)
  end)
end)
```

- [ ] **Step 2: Run the path resolver spec and confirm it fails because the module does not exist yet**

Run:

```bash
cd /home/lenovo/source/repos/gen_model
./lua_modules/bin/busted tests/protoc_cli/path_search_spec.lua
```

Expected: FAIL with `module 'protoc_cli.path_search' not found`

- [ ] **Step 3: Implement path resolution**

```lua
-- src/protoc_cli/path_search.lua
local lfs = require("lfs")

local Resolver = {}
Resolver.__index = Resolver

local function is_absolute(path)
  return path:sub(1, 1) == "/"
end

local function to_absolute(path)
  if is_absolute(path) then
    return path
  end
  return lfs.currentdir() .. "/" .. path
end

local function file_exists(path)
  local handle = io.open(path, "rb")
  if not handle then
    return false
  end
  handle:close()
  return true
end

local function join_path(root, name)
  if root == "." or root == "" then
    return name
  end
  return root .. "/" .. name
end

function Resolver:_resolve(name)
  for _, root in ipairs(self.proto_paths) do
    local candidate = join_path(root, name)
    if file_exists(candidate) then
      return {
        import_name = name,
        absolute_path = to_absolute(candidate),
      }
    end
  end

  return nil, {
    exit_code = 1,
    message = string.format(
      "unable to resolve '%s' from --proto_path (%s)",
      name,
      table.concat(self.proto_paths, ", ")
    ),
  }
end

function Resolver:resolve_input(name)
  return self:_resolve(name)
end

function Resolver:resolve_import(name)
  return self:_resolve(name)
end

local M = {}

function M.new(proto_paths)
  return setmetatable({
    proto_paths = proto_paths,
  }, Resolver)
end

return M
```

- [ ] **Step 4: Re-run the path resolver spec and confirm it passes**

Run:

```bash
cd /home/lenovo/source/repos/gen_model
./lua_modules/bin/busted tests/protoc_cli/path_search_spec.lua
```

Expected: PASS with `3 successes`

- [ ] **Step 5: Commit fixtures and path resolution**

```bash
cd /home/lenovo/source/repos/gen_model
git add \
  tests/fixtures/protoc/imports/shared.proto \
  tests/fixtures/protoc/full_feature.proto \
  tests/fixtures/protoc/secondary.proto \
  tests/protoc_cli/path_search_spec.lua \
  src/protoc_cli/path_search.lua
git commit -m "feat: add protoc file resolution"
```

## Task 3: Build the compiler around `lua-protobuf`

**Files:**
- Create: `tests/fixtures/protoc/bad_syntax.proto`
- Create: `tests/protoc_cli/compiler_spec.lua`
- Create: `src/protoc_cli/compiler.lua`
- Test: `tests/protoc_cli/compiler_spec.lua`

- [ ] **Step 1: Write the broken proto fixture and the failing compiler spec**

```proto
// tests/fixtures/protoc/bad_syntax.proto
syntax = "proto3";

package demo.bad

message Broken {
  string missing_semicolon = 1;
}
```

```lua
-- tests/protoc_cli/compiler_spec.lua
require("tests.support.env")

local pb = require("pb")
local protoc = require("protoc")
local compiler = require("protoc_cli.compiler")

local function decode_file_descriptor_set(bytes)
  return assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))
end

local function find_file(set, name)
  for _, file in ipairs(set.file) do
    if file.name == name then
      return file
    end
  end
end

describe("protoc_cli.compiler.compile", function()
  before_each(function()
    pb.clear()
    protoc.reload()
  end)

  it("builds one deduplicated descriptor set for multiple inputs", function()
    local bytes = assert(compiler.compile({
      proto_paths = { "tests/fixtures/protoc" },
      inputs = { "full_feature.proto", "secondary.proto" },
    }))

    local set = decode_file_descriptor_set(bytes)
    assert.are.equal(3, #set.file)

    local full = assert(find_file(set, "full_feature.proto"))
    assert.are.equal("com.example.demo.full", full.options.java_package)
    assert.are.equal("EchoService", full.service[1].name)
    assert.is_true(full.service[1].options.deprecated)
    assert.is_true(full.service[1].method[1].options.deprecated)

    assert(pb.load(bytes))

    local encoded = assert(pb.encode("demo.full.RichMessage", {
      plain_name = "Ada",
      labels = { "alpha" },
      counters = { views = 2 },
      text = "hello",
      nickname = "ace",
      note = {
        id = "note-1",
        enabled = true,
      },
      current_kind = "SHARED_KIND_PRIMARY",
      envelope = {
        kind = "KIND_API",
        nested = {
          source = "cli",
        },
      },
    }))

    local decoded = assert(pb.decode("demo.full.RichMessage", encoded))
    assert.are.equal("Ada", decoded.plain_name)
    assert.are.equal("hello", decoded.text)
    assert.are.equal("ace", decoded.nickname)
    assert.are.equal("note-1", decoded.note.id)
    assert.are.equal("cli", decoded.envelope.nested.source)
  end)

  it("returns compiler errors with the original file context", function()
    local bytes, err = compiler.compile({
      proto_paths = { "tests/fixtures/protoc" },
      inputs = { "bad_syntax.proto" },
    })

    assert.is_nil(bytes)
    assert.are.equal(1, err.exit_code)
    assert.is_true(err.message:match("bad_syntax%.proto") ~= nil)
  end)
end)
```

- [ ] **Step 2: Run the compiler spec and confirm it fails because the module does not exist yet**

Run:

```bash
cd /home/lenovo/source/repos/gen_model
./lua_modules/bin/busted tests/protoc_cli/compiler_spec.lua
```

Expected: FAIL with `module 'protoc_cli.compiler' not found`

- [ ] **Step 3: Implement the compiler**

```lua
-- src/protoc_cli/compiler.lua
local pb = require("pb")
local protoc = require("protoc")

local path_search = require("protoc_cli.path_search")

local M = {}

local function normalize_error(err)
  return {
    exit_code = 1,
    message = tostring(err),
  }
end

function M.compile(config)
  protoc.reload()

  local resolver = path_search.new(config.proto_paths)
  local parser = protoc.new()
  parser.proto3_optional = true

  for _, root in ipairs(config.proto_paths) do
    parser:addpath(root)
  end

  local files = {}
  local seen = {}

  local function collect(info)
    if not seen[info.name] then
      seen[info.name] = true
      files[#files + 1] = info
    end
  end

  parser.on_import = collect

  for _, input in ipairs(config.inputs) do
    local resolved, resolve_err = resolver:resolve_input(input)
    if not resolved then
      return nil, resolve_err
    end

    local ok, info_or_err = pcall(parser.parsefile, parser, resolved.import_name)
    if not ok then
      return nil, normalize_error(info_or_err)
    end

    collect(info_or_err)
  end

  local ok, encoded_or_err = pcall(pb.encode, ".google.protobuf.FileDescriptorSet", {
    file = files,
  })

  if not ok then
    return nil, normalize_error(encoded_or_err)
  end

  return encoded_or_err
end

return M
```

- [ ] **Step 4: Re-run the compiler spec and confirm it passes**

Run:

```bash
cd /home/lenovo/source/repos/gen_model
./lua_modules/bin/busted tests/protoc_cli/compiler_spec.lua
```

Expected: PASS with `2 successes`

- [ ] **Step 5: Commit the compiler**

```bash
cd /home/lenovo/source/repos/gen_model
git add \
  tests/fixtures/protoc/bad_syntax.proto \
  tests/protoc_cli/compiler_spec.lua \
  src/protoc_cli/compiler.lua
git commit -m "feat: compile descriptor sets from proto inputs"
```

## Task 4: Add descriptor writing and the real CLI entrypoint

**Files:**
- Create: `tests/protoc_cli/write_descriptor_spec.lua`
- Create: `tests/protoc_cli/cli_spec.lua`
- Create: `src/protoc_cli/write_descriptor.lua`
- Create: `tools/protoc_cli.lua`
- Test: `tests/protoc_cli/write_descriptor_spec.lua`
- Test: `tests/protoc_cli/cli_spec.lua`

- [ ] **Step 1: Write the failing writer and CLI specs**

```lua
-- tests/protoc_cli/write_descriptor_spec.lua
require("tests.support.env")

local write_descriptor = require("protoc_cli.write_descriptor")

describe("protoc_cli.write_descriptor.write", function()
  before_each(function()
    os.execute("rm -rf tests/tmp && mkdir -p tests/tmp")
  end)

  it("writes descriptor bytes to disk", function()
    assert(write_descriptor.write("tests/tmp/out.pb", "\1\2\3"))

    local handle = assert(io.open("tests/tmp/out.pb", "rb"))
    local bytes = handle:read("*a")
    handle:close()

    assert.are.equal("\1\2\3", bytes)
  end)

  it("returns a structured error when the output file cannot be opened", function()
    local ok, err = write_descriptor.write("tests/tmp/missing/out.pb", "abc")

    assert.is_nil(ok)
    assert.are.equal(1, err.exit_code)
    assert.is_true(err.message:match("tests/tmp/missing/out%.pb") ~= nil)
  end)
end)
```

```lua
-- tests/protoc_cli/cli_spec.lua
require("tests.support.env")

local pb = require("pb")
local protoc = require("protoc")

local LUA_PATH_VALUE =
  "src/?.lua;src/?/init.lua;lua_modules/share/lua/5.4/?.lua;lua_modules/share/lua/5.4/?/init.lua;;"
local LUA_CPATH_VALUE = "lua_modules/lib/lua/5.4/?.so;;"

local function run_cli(arguments, stderr_path)
  local command = table.concat({
    "LUA_PATH='" .. LUA_PATH_VALUE .. "'",
    "LUA_CPATH='" .. LUA_CPATH_VALUE .. "'",
    "lua5.4",
    "tools/protoc_cli.lua",
    arguments,
    "2>" .. stderr_path,
  }, " ")

  return os.execute(command)
end

describe("tools/protoc_cli.lua", function()
  before_each(function()
    os.execute("rm -rf tests/tmp && mkdir -p tests/tmp")
    pb.clear()
    protoc.reload()
  end)

  it("writes a descriptor set for multiple proto inputs", function()
    local ok, _, code = run_cli(
      "--proto_path tests/fixtures/protoc --descriptor_set_out tests/tmp/cli.pb full_feature.proto secondary.proto",
      "tests/tmp/cli-success.err"
    )

    assert.is_true(ok)
    assert.are.equal(0, code)

    local handle = assert(io.open("tests/tmp/cli.pb", "rb"))
    local bytes = handle:read("*a")
    handle:close()

    assert(pb.load(bytes))
    assert.is_not_nil(pb.type("demo.secondary.AuditEntry"))
  end)

  it("returns a non-zero exit code and stderr when an input file is missing", function()
    local ok, _, code = run_cli(
      "--proto_path tests/fixtures/protoc --descriptor_set_out tests/tmp/cli.pb missing.proto",
      "tests/tmp/cli-error.err"
    )

    assert.is_nil(ok)
    assert.are.equal(1, code)

    local handle = assert(io.open("tests/tmp/cli-error.err", "rb"))
    local stderr = handle:read("*a")
    handle:close()

    assert.is_true(stderr:match("missing%.proto") ~= nil)
  end)
end)
```

- [ ] **Step 2: Run the new specs and confirm they fail because the writer and CLI do not exist yet**

Run:

```bash
cd /home/lenovo/source/repos/gen_model
./lua_modules/bin/busted tests/protoc_cli/write_descriptor_spec.lua tests/protoc_cli/cli_spec.lua
```

Expected: FAIL with missing module errors for `protoc_cli.write_descriptor`

- [ ] **Step 3: Implement binary writing and the CLI entrypoint**

```lua
-- src/protoc_cli/write_descriptor.lua
local M = {}

function M.write(path, bytes)
  local handle, open_err = io.open(path, "wb")
  if not handle then
    return nil, {
      exit_code = 1,
      message = string.format("unable to open '%s' for writing: %s", path, open_err),
    }
  end

  local ok, write_err = handle:write(bytes)
  if not ok then
    handle:close()
    return nil, {
      exit_code = 1,
      message = string.format("unable to write '%s': %s", path, write_err),
    }
  end

  local closed, close_err = handle:close()
  if closed == nil then
    return nil, {
      exit_code = 1,
      message = string.format("unable to close '%s': %s", path, close_err),
    }
  end

  return true
end

return M
```

```lua
-- tools/protoc_cli.lua
local args = require("protoc_cli.args")
local compiler = require("protoc_cli.compiler")
local write_descriptor = require("protoc_cli.write_descriptor")

local function fail(err)
  io.stderr:write(err.message .. "\n")
  os.exit(err.exit_code or 1)
end

local ok, config_or_err = args.parse(arg)
if not ok then
  fail(config_or_err)
end

local bytes, compile_err = compiler.compile(config_or_err)
if not bytes then
  fail(compile_err)
end

local written, write_err = write_descriptor.write(config_or_err.descriptor_set_out, bytes)
if not written then
  fail(write_err)
end
```

- [ ] **Step 4: Re-run the writer and CLI specs and confirm they pass**

Run:

```bash
cd /home/lenovo/source/repos/gen_model
./lua_modules/bin/busted tests/protoc_cli/write_descriptor_spec.lua tests/protoc_cli/cli_spec.lua
```

Expected: PASS with `4 successes`

- [ ] **Step 5: Commit the writer and CLI**

```bash
cd /home/lenovo/source/repos/gen_model
git add \
  tests/protoc_cli/write_descriptor_spec.lua \
  tests/protoc_cli/cli_spec.lua \
  src/protoc_cli/write_descriptor.lua \
  tools/protoc_cli.lua
git commit -m "feat: add protoc cli entrypoint"
```

## Task 5: Run the full verification pass

**Files:**
- Modify: `src/protoc_cli/args.lua`
- Modify: `src/protoc_cli/path_search.lua`
- Modify: `src/protoc_cli/compiler.lua`
- Modify: `src/protoc_cli/write_descriptor.lua`
- Modify: `tools/protoc_cli.lua`
- Test: `tests/protoc_cli/args_spec.lua`
- Test: `tests/protoc_cli/path_search_spec.lua`
- Test: `tests/protoc_cli/compiler_spec.lua`
- Test: `tests/protoc_cli/write_descriptor_spec.lua`
- Test: `tests/protoc_cli/cli_spec.lua`

- [ ] **Step 1: Run the entire test suite**

Run:

```bash
cd /home/lenovo/source/repos/gen_model
./lua_modules/bin/busted tests/protoc_cli
```

Expected: PASS with all protoc CLI specs succeeding

- [ ] **Step 2: Run a manual CLI smoke test with two inputs**

Run:

```bash
cd /home/lenovo/source/repos/gen_model
rm -rf tests/tmp && mkdir -p tests/tmp
LUA_PATH="src/?.lua;src/?/init.lua;lua_modules/share/lua/5.4/?.lua;lua_modules/share/lua/5.4/?/init.lua;;" \
LUA_CPATH="lua_modules/lib/lua/5.4/?.so;;" \
lua5.4 tools/protoc_cli.lua \
  --proto_path tests/fixtures/protoc \
  --descriptor_set_out tests/tmp/manual.pb \
  full_feature.proto \
  secondary.proto
```

Expected: command exits `0` and creates `tests/tmp/manual.pb`

- [ ] **Step 3: Inspect the generated descriptor set with `pb`**

Run:

```bash
cd /home/lenovo/source/repos/gen_model
LUA_PATH="src/?.lua;src/?/init.lua;lua_modules/share/lua/5.4/?.lua;lua_modules/share/lua/5.4/?/init.lua;;" \
LUA_CPATH="lua_modules/lib/lua/5.4/?.so;;" \
lua5.4 -e 'local pb=require("pb"); local protoc=require("protoc"); protoc.reload(); local f=assert(io.open("tests/tmp/manual.pb","rb")); local bytes=f:read("*a"); f:close(); assert(pb.load(bytes)); assert(pb.type("demo.full.RichMessage")); assert(pb.type("demo.secondary.AuditEntry")); print("descriptor ok")'
```

Expected: prints `descriptor ok`

- [ ] **Step 4: Commit the verified feature**

```bash
cd /home/lenovo/source/repos/gen_model
git add \
  src/protoc_cli/args.lua \
  src/protoc_cli/path_search.lua \
  src/protoc_cli/compiler.lua \
  src/protoc_cli/write_descriptor.lua \
  tools/protoc_cli.lua \
  tests/support/env.lua \
  tests/fixtures/protoc/imports/shared.proto \
  tests/fixtures/protoc/full_feature.proto \
  tests/fixtures/protoc/secondary.proto \
  tests/fixtures/protoc/bad_syntax.proto \
  tests/protoc_cli/args_spec.lua \
  tests/protoc_cli/path_search_spec.lua \
  tests/protoc_cli/compiler_spec.lua \
  tests/protoc_cli/write_descriptor_spec.lua \
  tests/protoc_cli/cli_spec.lua
git commit -m "feat: add protobuf descriptor generation cli"
```

require("tests.support.env")

local lfs = require("lfs")
local path_search = require("protoc_cli.path_search")

local function write_file(path, content)
  local handle = assert(io.open(path, "wb"))
  handle:write(content)
  handle:close()
end

describe("protoc_cli.path_search", function()
  it("resolves positional inputs relative to proto_path", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local resolved = assert(resolver:resolve_input("full_feature.proto"))

    assert.are.equal("full_feature.proto", resolved.import_name)
    assert.is_true(resolved.absolute_path:match("tests/fixtures/protoc/full_feature%.proto$") ~= nil)
  end)

  it("normalizes ./ prefixed positional inputs to canonical import_name", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local resolved = assert(resolver:resolve_input("./full_feature.proto"))

    assert.are.equal("full_feature.proto", resolved.import_name)
    assert.is_true(resolved.absolute_path:match("tests/fixtures/protoc/full_feature%.proto$") ~= nil)
  end)

  it("resolves absolute positional inputs under proto_path", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local absolute_input = lfs.currentdir() .. "/tests/fixtures/protoc/full_feature.proto"
    local resolved = assert(resolver:resolve_input(absolute_input))

    assert.are.equal("full_feature.proto", resolved.import_name)
    assert.are.equal(absolute_input, resolved.absolute_path)
  end)

  it("canonicalizes absolute_path for non-canonical absolute positional inputs", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local absolute_input = lfs.currentdir() .. "/tests/fixtures/protoc/imports/../full_feature.proto"
    local resolved = assert(resolver:resolve_input(absolute_input))

    assert.are.equal("full_feature.proto", resolved.import_name)
    assert.are.equal(lfs.currentdir() .. "/tests/fixtures/protoc/full_feature.proto", resolved.absolute_path)
  end)

  it("resolves absolute positional inputs under the current directory root", function()
    local resolver = path_search.new({ "." })
    local absolute_input = lfs.currentdir() .. "/tests/fixtures/protoc/full_feature.proto"
    local resolved = assert(resolver:resolve_input(absolute_input))

    assert.are.equal("tests/fixtures/protoc/full_feature.proto", resolved.import_name)
    assert.are.equal(absolute_input, resolved.absolute_path)
  end)

  it("resolves absolute positional inputs under a trailing-slash proto_path", function()
    local resolver = path_search.new({ "tests/fixtures/protoc/" })
    local absolute_input = lfs.currentdir() .. "/tests/fixtures/protoc/full_feature.proto"
    local resolved = assert(resolver:resolve_input(absolute_input))

    assert.are.equal("full_feature.proto", resolved.import_name)
    assert.are.equal(absolute_input, resolved.absolute_path)
  end)

  it("resolves absolute positional inputs under a later valid proto_path when an earlier root is missing", function()
    local resolver = path_search.new({ "tests/tmp/missing-proto-root", "tests/fixtures/protoc" })
    local absolute_input = lfs.currentdir() .. "/tests/fixtures/protoc/full_feature.proto"
    local resolved = assert(resolver:resolve_input(absolute_input))

    assert.are.equal("full_feature.proto", resolved.import_name)
    assert.are.equal(absolute_input, resolved.absolute_path)
  end)

  it("resolves imports using the same search roots", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local resolved = assert(resolver:resolve_import("imports/shared.proto"))

    assert.are.equal("imports/shared.proto", resolved.import_name)
    assert.is_true(resolved.absolute_path:match("tests/fixtures/protoc/imports/shared%.proto$") ~= nil)
  end)

  it("normalizes imports with traversing segments to canonical import_name", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local resolved = assert(resolver:resolve_import("imports/../full_feature.proto"))

    assert.are.equal("full_feature.proto", resolved.import_name)
    assert.is_true(resolved.absolute_path:match("tests/fixtures/protoc/full_feature%.proto$") ~= nil)
  end)

  it("returns a structured error for relative names whose .. segments escape a nested proto root", function()
    local resolver = path_search.new({ "tests/fixtures/protoc/imports" })
    local resolved, err = resolver:resolve_input("../full_feature.proto")

    assert.is_nil(resolved)
    assert.are.equal(1, err.exit_code)
    assert.is_true(err.message:match("%.%.?/full_feature%.proto") ~= nil)
    assert.is_true(err.message:match("tests/fixtures/protoc/imports") ~= nil)
  end)

  it("returns a structured error for absolute import names", function()
    local resolver = path_search.new({ "." })
    local absolute_import = lfs.currentdir() .. "/tests/fixtures/protoc/imports/shared.proto"
    local resolved, err = resolver:resolve_import(absolute_import)

    assert.is_nil(resolved)
    assert.are.equal(1, err.exit_code)
    assert.is_true(err.message:match("imports/shared%.proto") ~= nil)
    assert.is_true(err.message:match("%.") ~= nil)
  end)

  it("returns a structured error for missing files", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local resolved, err = resolver:resolve_input("missing.proto")

    assert.is_nil(resolved)
    assert.are.equal(1, err.exit_code)
    assert.is_true(err.message:match("missing%.proto") ~= nil)
    assert.is_true(err.message:match("tests/fixtures/protoc") ~= nil)
  end)

  it("returns a structured error for directory positional inputs", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local resolved, err = resolver:resolve_input("imports")

    assert.is_nil(resolved)
    assert.are.equal(1, err.exit_code)
    assert.is_true(err.message:match("imports") ~= nil)
    assert.is_true(err.message:match("tests/fixtures/protoc") ~= nil)
  end)

  it("returns a structured error for directory imports", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local resolved, err = resolver:resolve_import("imports")

    assert.is_nil(resolved)
    assert.are.equal(1, err.exit_code)
    assert.is_true(err.message:match("imports") ~= nil)
    assert.is_true(err.message:match("tests/fixtures/protoc") ~= nil)
  end)

  it("returns a structured error for absolute inputs outside all proto roots", function()
    local resolver = path_search.new({ "." })
    local absolute_input = lfs.currentdir() .. "/../../gen_model-dev-1.rockspec"
    local resolved, err = resolver:resolve_input(absolute_input)

    assert.is_nil(resolved)
    assert.are.equal(1, err.exit_code)
    assert.is_true(err.message:match("gen_model%-dev%-1%.rockspec") ~= nil)
    assert.is_true(err.message:match("%.") ~= nil)
  end)

  it("returns a structured error for absolute inputs whose .. segments escape a proto root", function()
    local resolver = path_search.new({ "tests/fixtures/protoc/imports" })
    local absolute_input = lfs.currentdir()
      .. "/tests/fixtures/protoc/imports/../../../protoc_cli/path_search_spec.lua"
    local resolved, err = resolver:resolve_input(absolute_input)

    assert.is_nil(resolved)
    assert.are.equal(1, err.exit_code)
    assert.is_true(err.message:match("path_search_spec%.lua") ~= nil)
    assert.is_true(err.message:match("tests/fixtures/protoc/imports") ~= nil)
  end)

  it("resolves inputs from a symlinked configured proto root", function()
    local link_path = lfs.currentdir() .. "/tests/fixtures/protoc_symlink_root"
    os.remove(link_path)
    assert.are.equal(true, lfs.link("protoc", link_path, true))

    local ok, err_or_nil = xpcall(function()
      local resolver = path_search.new({ "tests/fixtures/protoc_symlink_root" })
      local resolved = assert(resolver:resolve_input("full_feature.proto"))

      assert.are.equal("full_feature.proto", resolved.import_name)
      assert.is_true(resolved.absolute_path:match("tests/fixtures/protoc/full_feature%.proto$") ~= nil)
    end, debug.traceback)

    os.remove(link_path)
    if not ok then
      error(err_or_nil, 0)
    end
  end)

  it("resolves absolute inputs under a symlinked proto root using the logical import name", function()
    local ok = os.execute("rm -rf tests/tmp/path-search-symlink-root && mkdir -p tests/tmp/path-search-symlink-root/actual/nested")
    assert.is_true(ok)

    write_file("tests/tmp/path-search-symlink-root/actual/nested/file.proto", [[
syntax = "proto3";

package demo.symlink;

message Linked {
  string value = 1;
}
]])

    local symlink_root = lfs.currentdir() .. "/tests/tmp/path-search-symlink-root/proto-link"
    os.remove(symlink_root)
    assert.are.equal(true, lfs.link("actual", symlink_root, true))

    local ok_run, err_or_nil = xpcall(function()
      local resolver = path_search.new({ "tests/tmp/path-search-symlink-root/proto-link" })
      local absolute_input = lfs.currentdir() .. "/tests/tmp/path-search-symlink-root/actual/nested/file.proto"
      local resolved = assert(resolver:resolve_input(absolute_input))

      assert.are.equal("nested/file.proto", resolved.import_name)
      assert.are.equal(absolute_input, resolved.absolute_path)
    end, debug.traceback)

    os.remove(symlink_root)
    os.remove("tests/tmp/path-search-symlink-root/actual/nested/file.proto")
    if not ok_run then
      error(err_or_nil, 0)
    end
  end)

  it("preserves alias import_name for absolute symlinked inputs under the logical proto root", function()
    local ok = os.execute("rm -rf tests/tmp/path-search-absolute-alias && mkdir -p tests/tmp/path-search-absolute-alias/root")
    assert.is_true(ok)

    write_file("tests/tmp/path-search-absolute-alias/root/actual.proto", [[
syntax = "proto3";

package demo.alias;

message Alias {
  string value = 1;
}
]])

    local alias_path = lfs.currentdir() .. "/tests/tmp/path-search-absolute-alias/root/alias.proto"
    os.remove(alias_path)
    assert.are.equal(true, lfs.link("actual.proto", alias_path, true))

    local ok_run, err_or_nil = xpcall(function()
      local resolver = path_search.new({ "tests/tmp/path-search-absolute-alias/root" })
      local resolved = assert(resolver:resolve_input(alias_path))

      assert.are.equal("alias.proto", resolved.import_name)
      assert.are.equal(lfs.currentdir() .. "/tests/tmp/path-search-absolute-alias/root/actual.proto", resolved.absolute_path)
    end, debug.traceback)

    os.remove(alias_path)
    os.remove("tests/tmp/path-search-absolute-alias/root/actual.proto")
    if not ok_run then
      error(err_or_nil, 0)
    end
  end)

  it("preserves logical import_name for symlinked positional inputs", function()
    local ok = os.execute("mkdir -p tests/tmp")
    assert.is_true(ok)

    write_file("tests/tmp/actual.proto", [[
syntax = "proto3";

package demo.alias;

message Alias {
  string value = 1;
}
]])
    os.remove("tests/tmp/alias.proto")
    assert.are.equal(true, lfs.link("actual.proto", "tests/tmp/alias.proto", true))

    local ok, err_or_nil = xpcall(function()
      local resolver = path_search.new({ "tests/tmp" })
      local resolved = assert(resolver:resolve_input("alias.proto"))

      assert.are.equal("alias.proto", resolved.import_name)
      assert.are.equal(lfs.currentdir() .. "/tests/tmp/actual.proto", resolved.absolute_path)
    end, debug.traceback)

    os.remove("tests/tmp/alias.proto")
    os.remove("tests/tmp/actual.proto")
    if not ok then
      error(err_or_nil, 0)
    end
  end)

  it("returns a structured error for symlink escape attempts under a proto root", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local link_path = lfs.currentdir() .. "/tests/fixtures/protoc/symlink_escape.proto"
    local target_path = lfs.currentdir() .. "/tests/protoc_cli/path_search_spec.lua"
    os.remove(link_path)
    assert.are.equal(true, lfs.link(target_path, link_path, true))

    local ok, err_or_nil = xpcall(function()
      local resolved, err = resolver:resolve_input("symlink_escape.proto")

      assert.is_nil(resolved)
      assert.are.equal(1, err.exit_code)
      assert.is_true(err.message:match("symlink_escape%.proto") ~= nil)
      assert.is_true(err.message:match("tests/fixtures/protoc") ~= nil)
    end, debug.traceback)

    os.remove(link_path)
    if not ok then
      error(err_or_nil, 0)
    end
  end)

  it("keeps rejecting symlink escape attempts under a symlinked configured proto root", function()
    local ok = os.execute("mkdir -p tests/tmp/real_root")
    assert.is_true(ok)

    local symlink_root = lfs.currentdir() .. "/tests/tmp/symlink_root"
    local link_path = lfs.currentdir() .. "/tests/tmp/real_root/symlink_escape.proto"
    local target_path = lfs.currentdir() .. "/tests/protoc_cli/path_search_spec.lua"
    os.remove(symlink_root)
    os.remove(link_path)
    assert.are.equal(true, lfs.link("real_root", symlink_root, true))
    assert.are.equal(true, lfs.link(target_path, link_path, true))

    local ok_run, err_or_nil = xpcall(function()
      local resolver = path_search.new({ "tests/tmp/symlink_root" })
      local resolved, err = resolver:resolve_input("symlink_escape.proto")

      assert.is_nil(resolved)
      assert.are.equal(1, err.exit_code)
      assert.is_true(err.message:match("symlink_escape%.proto") ~= nil)
      assert.is_true(err.message:match("tests/tmp/symlink_root") ~= nil)
    end, debug.traceback)

    os.remove(link_path)
    os.remove(symlink_root)
    if not ok_run then
      error(err_or_nil, 0)
    end
  end)

  it("returns an explicit error when realpath is unavailable", function()
    local original_popen = io.popen
    local original_loaded = package.loaded["protoc_cli.path_search"]

    io.popen = function(command, mode)
      if command:match("realpath") then
        return {
          read = function()
            return ""
          end,
          close = function()
            return nil, "exit", 127
          end,
        }
      end

      return original_popen(command, mode)
    end
    package.loaded["protoc_cli.path_search"] = nil

    local ok, err_or_nil = xpcall(function()
      local missing_realpath = require("protoc_cli.path_search")
      local resolver = missing_realpath.new({ "tests/fixtures/protoc" })
      local resolved, err = resolver:resolve_input("full_feature.proto")

      assert.is_nil(resolved)
      assert.are.equal(1, err.exit_code)
      assert.is_true(err.message:match("realpath") ~= nil)
      assert.is_true(err.message:match("PATH") ~= nil)
    end, debug.traceback)

    io.popen = original_popen
    package.loaded["protoc_cli.path_search"] = original_loaded
    if not ok then
      error(err_or_nil, 0)
    end
  end)
end)

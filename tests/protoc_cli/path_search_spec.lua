require("tests.support.env")

local lfs = require("lfs")
local path_search = require("protoc_cli.path_search")

describe("protoc_cli.path_search", function()
  it("resolves positional inputs relative to proto_path", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local resolved = assert(resolver:resolve_input("full_feature.proto"))

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

  it("resolves imports using the same search roots", function()
    local resolver = path_search.new({ "tests/fixtures/protoc" })
    local resolved = assert(resolver:resolve_import("imports/shared.proto"))

    assert.are.equal("imports/shared.proto", resolved.import_name)
    assert.is_true(resolved.absolute_path:match("tests/fixtures/protoc/imports/shared%.proto$") ~= nil)
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
end)

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

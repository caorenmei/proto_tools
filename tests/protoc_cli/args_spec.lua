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

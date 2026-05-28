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

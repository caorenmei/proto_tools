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

require("tests.support.env")

local pb = require("pb")
local protoc = require("protoc")

local LUA_PATH_VALUE =
  "src/?.lua;src/?/init.lua;lua_modules/share/lua/5.4/?.lua;lua_modules/share/lua/5.4/?/init.lua;;"
local LUA_CPATH_VALUE = "lua_modules/lib/lua/5.4/?.so;;"

local function write_file(path, content)
  local handle = assert(io.open(path, "wb"))
  handle:write(content)
  handle:close()
end

local function read_file(path)
  local handle = assert(io.open(path, "rb"))
  local content = handle:read("*a")
  handle:close()
  return content
end

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

  it("returns a non-zero exit code and stderr for malformed syntax missing a semicolon before a trailing comment", function()
    write_file("tests/tmp/bad_cli.proto", [[
syntax = "proto3";

package demo.bad // trailing comment

message Broken {
  string value = 1;
}
]])

    local ok, _, code = run_cli(
      "--proto_path tests/tmp --descriptor_set_out tests/tmp/cli.pb bad_cli.proto",
      "tests/tmp/cli-error.err"
    )

    assert.is_nil(ok)
    assert.are.equal(1, code)

    local stderr = read_file("tests/tmp/cli-error.err")
    assert.is_true(stderr:match("bad_cli%.proto") ~= nil)
    assert.is_true(stderr:match("';' expected") ~= nil)
  end)

  it("returns a non-zero exit code and stderr for a brace-valued option block missing a semicolon", function()
    local ok = os.execute("mkdir -p tests/tmp/google/protobuf")
    assert.is_true(ok)

    write_file("tests/tmp/google/protobuf/descriptor.proto", [[
syntax = "proto2";
package google.protobuf;
message FileOptions {
  extensions 1000 to max;
}
]])

    write_file("tests/tmp/bad_brace_cli.proto", [[
syntax = "proto2";

package demo.brace;

import "google/protobuf/descriptor.proto";

extend google.protobuf.FileOptions {
  optional Meta custom = 50001;
}

message Meta {
  optional string value = 1;
}

option (custom) = {
  value: "x"
} // trailing comment and missing semicolon

message Thing {
  optional string name = 1;
}
]])

    local ok, _, code = run_cli(
      "--proto_path tests/tmp --descriptor_set_out tests/tmp/cli.pb bad_brace_cli.proto",
      "tests/tmp/cli-error.err"
    )

    assert.is_nil(ok)
    assert.are.equal(1, code)

    local stderr = read_file("tests/tmp/cli-error.err")
    assert.is_true(stderr:match("bad_brace_cli%.proto") ~= nil)
    assert.is_true(stderr:match("';' expected") ~= nil)
  end)
end)

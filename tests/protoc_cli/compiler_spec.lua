require("tests.support.env")

local pb = require("pb")
local protoc = require("protoc")
local compiler = require("protoc_cli.compiler")

local function reset_state()
  pb.clear()
  protoc.reload()
end

local function write_file(path, content)
  local handle = assert(io.open(path, "wb"))
  handle:write(content)
  handle:close()
end

local function find_file(files, name)
  for _, file in ipairs(files) do
    if file.name == name then
      return file
    end
  end
end

describe("protoc_cli.compiler", function()
  before_each(function()
    os.execute("rm -rf tests/tmp && mkdir -p tests/tmp/proto_root")
    reset_state()
  end)

  it("compiles inputs into one deduplicated descriptor set", function()
    local bytes = assert(compiler.compile({
      proto_paths = { "tests/fixtures/protoc" },
      inputs = {
        "full_feature.proto",
        "secondary.proto",
      },
    }))

    local set = assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))
    assert.are.equal(3, #set.file)
    assert.is_not_nil(find_file(set.file, "imports/shared.proto"))
    assert.is_not_nil(find_file(set.file, "full_feature.proto"))
    assert.is_not_nil(find_file(set.file, "secondary.proto"))
  end)

  it("preserves file options and service metadata", function()
    local bytes = assert(compiler.compile({
      proto_paths = { "tests/fixtures/protoc" },
      inputs = { "full_feature.proto" },
    }))

    local set = assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))
    local file = assert(find_file(set.file, "full_feature.proto"))
    local service = assert(file.service[1])
    local method = assert(service.method[1])

    assert.are.equal("demo.full", file.package)
    assert.are.equal("com.example.demo.full", file.options.java_package)
    assert.are.equal("EchoService", service.name)
    assert.is_true(service.options.deprecated)
    assert.are.equal("Send", method.name)
    assert.are.equal(".demo.full.RichMessage", method.input_type)
    assert.are.equal(".demo.full.RichMessage", method.output_type)
    assert.is_true(method.options.deprecated)
  end)

  it("loads the descriptor set and round-trips RichMessage payloads", function()
    local bytes = assert(compiler.compile({
      proto_paths = { "tests/fixtures/protoc" },
      inputs = {
        "full_feature.proto",
        "secondary.proto",
      },
    }))

    assert(pb.load(bytes))

    local encoded = assert(pb.encode(".demo.full.RichMessage", {
      plain_name = "Alpha",
      labels = { "core", "cli" },
      counters = {
        sends = 2,
        retries = 1,
      },
      text = "hello world",
      nickname = "ally",
      note = {
        id = "note-1",
        enabled = true,
      },
      current_kind = "SHARED_KIND_PRIMARY",
      envelope = {
        kind = "KIND_API",
        nested = {
          source = "unit-test",
        },
      },
    }))

    local decoded = assert(pb.decode(".demo.full.RichMessage", encoded))
    assert.same({
      plain_name = "Alpha",
      labels = { "core", "cli" },
      counters = {
        sends = 2,
        retries = 1,
      },
      payload = "text",
      text = "hello world",
      _nickname = "nickname",
      nickname = "ally",
      note = {
        id = "note-1",
        enabled = true,
      },
      current_kind = "SHARED_KIND_PRIMARY",
      envelope = {
        kind = "KIND_API",
        nested = {
          source = "unit-test",
        },
      },
    }, decoded)
  end)

  it("returns a structured error for invalid syntax", function()
    local bytes, err = compiler.compile({
      proto_paths = { "tests/fixtures/protoc" },
      inputs = { "bad_syntax.proto" },
    })

    assert.is_nil(bytes)
    assert.are.same({
      exit_code = 1,
      message = err.message,
    }, err)
    assert.is_true(err.message:match("bad_syntax%.proto") ~= nil)
  end)

  it("prefers the proto_path file over a same-named cwd file", function()
    write_file("full_feature.proto", [[
syntax = "proto3";

package shadow.cwd;

message WrongFile {
  string value = 1;
}
]])

    local ok, result = xpcall(function()
      local bytes = assert(compiler.compile({
        proto_paths = { "tests/fixtures/protoc" },
        inputs = { "full_feature.proto" },
      }))
      local set = assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))
      local file = assert(find_file(set.file, "full_feature.proto"))

      assert.are.equal("demo.full", file.package)
      assert.is_not_nil(find_file(set.file, "imports/shared.proto"))
    end, debug.traceback)

    os.remove("full_feature.proto")
    if not ok then
      error(result, 0)
    end
  end)

  it("rejects import paths that escape the proto root during compilation", function()
    write_file("tests/tmp/proto_root/main.proto", [[
syntax = "proto3";

package escape.main;

import "../escape.proto";

message Main {
  escape.outside.Outside value = 1;
}
]])

    write_file("tests/tmp/escape.proto", [[
syntax = "proto3";

package escape.outside;

message Outside {
  string value = 1;
}
]])

    local bytes, err = compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "main.proto" },
    })

    assert.is_nil(bytes)
    assert.are.same({
      exit_code = 1,
      message = err.message,
    }, err)
    assert.is_true(err.message:match("%.%./escape%.proto") ~= nil)
  end)

  it("returns a structured error when an imported file has invalid syntax", function()
    write_file("tests/tmp/proto_root/main.proto", [[
syntax = "proto3";

package import.bad;

import "broken.proto";

message Main {
  Broken value = 1;
}
]])

    write_file("tests/tmp/proto_root/broken.proto", [[
syntax = "proto3";

package import.bad

message Broken {
  string value = 1;
}
]])

    local bytes, err = compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "main.proto" },
    })

    assert.is_nil(bytes)
    assert.are.same({
      exit_code = 1,
      message = err.message,
    }, err)
    assert.is_true(err.message:match("broken%.proto") ~= nil)
  end)
end)

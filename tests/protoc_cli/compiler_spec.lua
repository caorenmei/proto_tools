require("tests.support.env")

local lfs = require("lfs")
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

  it("rejects a package declaration missing a semicolon before a trailing comment", function()
    write_file("tests/tmp/proto_root/bad_package.proto", [[
syntax = "proto3";

package demo.bad // trailing comment

message Broken {
  string value = 1;
}
]])

    local bytes, err = compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "bad_package.proto" },
    })

    assert.is_nil(bytes)
    assert.are.same({
      exit_code = 1,
      message = err.message,
    }, err)
    assert.is_true(err.message:match("bad_package%.proto") ~= nil)
    assert.is_true(err.message:match("';' expected") ~= nil)
  end)

  it("rejects a field declaration missing a semicolon before a trailing comment", function()
    write_file("tests/tmp/proto_root/bad_field.proto", [[
syntax = "proto3";

package demo.bad;

message Broken {
  string name = 1 // trailing comment
}
]])

    local bytes, err = compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "bad_field.proto" },
    })

    assert.is_nil(bytes)
    assert.are.same({
      exit_code = 1,
      message = err.message,
    }, err)
    assert.is_true(err.message:match("bad_field%.proto") ~= nil)
    assert.is_true(err.message:match("';' expected") ~= nil)
  end)

  it("rejects a package declaration missing a semicolon before a trailing block comment", function()
    write_file("tests/tmp/proto_root/bad_package_block.proto", [[
syntax = "proto3";

package demo.bad /* trailing block comment */

message Broken {
  string value = 1;
}
]])

    local bytes, err = compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "bad_package_block.proto" },
    })

    assert.is_nil(bytes)
    assert.are.same({
      exit_code = 1,
      message = err.message,
    }, err)
    assert.is_true(err.message:match("bad_package_block%.proto") ~= nil)
    assert.is_true(err.message:match("';' expected") ~= nil)
  end)

  it("rejects a field declaration missing a semicolon before a trailing block comment", function()
    write_file("tests/tmp/proto_root/bad_field_block.proto", [[
syntax = "proto3";

package demo.bad;

message Broken {
  string name = 1 /* trailing block comment */
}
]])

    local bytes, err = compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "bad_field_block.proto" },
    })

    assert.is_nil(bytes)
    assert.are.same({
      exit_code = 1,
      message = err.message,
    }, err)
    assert.is_true(err.message:match("bad_field_block%.proto") ~= nil)
    assert.is_true(err.message:match("';' expected") ~= nil)
  end)

  it("accepts valid single-quoted option strings containing double slashes", function()
    write_file("tests/tmp/proto_root/single_quote_option.proto", [[
syntax = "proto3";

package demo.good;
option java_package = 'com.example//demo';

message Valid {
  string value = 1;
}
]])

    local bytes = assert(compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "single_quote_option.proto" },
    }))

    local set = assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))
    local file = assert(find_file(set.file, "single_quote_option.proto"))

    assert.are.equal("com.example//demo", file.options.java_package)
  end)

  it("accepts valid statements with trailing block comments after semicolons", function()
    write_file("tests/tmp/proto_root/block_comment.proto", [[
syntax = "proto3";

package demo.good; /* trailing block comment */

message Valid {
  string value = 1; /* field block comment */
}
]])

    local bytes = assert(compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "block_comment.proto" },
    }))

    local set = assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))
    local file = assert(find_file(set.file, "block_comment.proto"))

    assert.are.equal("demo.good", file.package)
    assert.are.equal("value", file.message_type[1].field[1].name)
  end)

  it("accepts multiline field options with trailing comments", function()
    write_file("tests/tmp/proto_root/field_options.proto", [[
syntax = "proto3";

package demo.good;

message Valid {
  string value = 1 [
    json_name = "value" // trailing comment
  ];
}
]])

    local bytes = assert(compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "field_options.proto" },
    }))

    local set = assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))
    local file = assert(find_file(set.file, "field_options.proto"))
    local field = assert(file.message_type[1].field[1])

    assert.are.equal("value", field.json_name)
  end)

  it("accepts field and option assignments continued on the next line", function()
    write_file("tests/tmp/proto_root/multiline_assignments.proto", [[
syntax = "proto3";

package demo.good;
option java_package =
  "com.example.demo";

message Valid {
  string value =
    1;
}
]])

    local bytes = assert(compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "multiline_assignments.proto" },
    }))

    local set = assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))
    local file = assert(find_file(set.file, "multiline_assignments.proto"))
    local field = assert(file.message_type[1].field[1])

    assert.are.equal("com.example.demo", file.options.java_package)
    assert.are.equal(1, field.number)
  end)

  it("accepts rpc method bodies whose opening brace starts on the next line", function()
    write_file("tests/tmp/proto_root/rpc_next_line_brace.proto", [[
syntax = "proto3";

package demo.rpc;

service EchoService {
  rpc Send (Request) returns (Reply)
  {
    option deprecated = true;
  }
}

message Request {
  string value = 1;
}

message Reply {
  string value = 1;
}
]])

    local bytes = assert(compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "rpc_next_line_brace.proto" },
    }))

    local set = assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))
    local file = assert(find_file(set.file, "rpc_next_line_brace.proto"))
    local service = assert(file.service[1])
    local method = assert(service.method[1])

    assert.are.equal("EchoService", service.name)
    assert.are.equal("Send", method.name)
    assert.is_true(method.options.deprecated)
  end)

  it("rejects closing multiline field options that end with a trailing comment but no semicolon", function()
    write_file("tests/tmp/proto_root/field_options_missing_semicolon.proto", [[
syntax = "proto3";

package demo.bad;

message Broken {
  string value = 1 [
    json_name = "value"
  ] // trailing comment
}
]])

    local bytes, err = compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "field_options_missing_semicolon.proto" },
    })

    assert.is_nil(bytes)
    assert.are.same({
      exit_code = 1,
      message = err.message,
    }, err)
    assert.is_true(err.message:match("field_options_missing_semicolon%.proto") ~= nil)
    assert.is_true(err.message:match("';' expected") ~= nil)
  end)

  it("accepts semicolons that appear after multiline block comments", function()
    write_file("tests/tmp/proto_root/multiline_block_semicolon.proto", [[
syntax = "proto3";

package demo.good /* comment
continued */
;

message Valid {
  string value = 1 /* field comment
  continued */
  ;
}
]])

    local bytes = assert(compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "multiline_block_semicolon.proto" },
    }))

    local set = assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))
    local file = assert(find_file(set.file, "multiline_block_semicolon.proto"))

    assert.are.equal("demo.good", file.package)
    assert.are.equal("value", file.message_type[1].field[1].name)
  end)

  it("rejects extensions declarations missing semicolons before trailing comments", function()
    write_file("tests/tmp/proto_root/extensions_comment.proto", [[
syntax = "proto2";

message Broken {
  extensions 100 to max // trailing comment
}
]])

    local bytes, err = compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "extensions_comment.proto" },
    })

    assert.is_nil(bytes)
    assert.are.same({
      exit_code = 1,
      message = err.message,
    }, err)
    assert.is_true(err.message:match("extensions_comment%.proto") ~= nil)
    assert.is_true(err.message:match("';' expected") ~= nil)
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

  it("rewrites dependency entries to canonical import names", function()
    write_file("tests/tmp/proto_root/alias.proto", [[
syntax = "proto3";

package demo.alias;

import "imports/../full_feature.proto";

message AliasRequest {
  demo.full.RichMessage value = 1;
}
]])

    local bytes = assert(compiler.compile({
      proto_paths = {
        "tests/tmp/proto_root",
        "tests/fixtures/protoc",
      },
      inputs = { "alias.proto" },
    }))

    local set = assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))
    local file = assert(find_file(set.file, "alias.proto"))

    assert.same({ "full_feature.proto" }, file.dependency)
    assert.is_not_nil(find_file(set.file, "full_feature.proto"))
  end)

  it("preserves logical descriptor names for symlinked positional inputs", function()
    write_file("tests/tmp/proto_root/actual.proto", [[
syntax = "proto3";

package demo.alias;

message Alias {
  string value = 1;
}
]])
    os.remove("tests/tmp/proto_root/alias.proto")
    assert.are.equal(true, lfs.link("actual.proto", "tests/tmp/proto_root/alias.proto", true))

    local ok, result = xpcall(function()
      local bytes = assert(compiler.compile({
        proto_paths = { "tests/tmp/proto_root" },
        inputs = { "alias.proto" },
      }))

      local set = assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))

      assert.is_not_nil(find_file(set.file, "alias.proto"))
      assert.is_nil(find_file(set.file, "actual.proto"))
    end, debug.traceback)

    os.remove("tests/tmp/proto_root/alias.proto")
    if not ok then
      error(result, 0)
    end
  end)

  it("preserves already canonical dependency entries", function()
    write_file("tests/tmp/proto_root/alias_canonical.proto", [[
syntax = "proto3";

package demo.alias;

import "full_feature.proto";

message AliasRequest {
  demo.full.RichMessage value = 1;
}
]])

    local bytes = assert(compiler.compile({
      proto_paths = {
        "tests/tmp/proto_root",
        "tests/fixtures/protoc",
      },
      inputs = { "alias_canonical.proto" },
    }))

    local set = assert(pb.decode(".google.protobuf.FileDescriptorSet", bytes))
    local file = assert(find_file(set.file, "alias_canonical.proto"))

    assert.same({ "full_feature.proto" }, file.dependency)
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

  it("returns a structured error when an imported file is missing a field semicolon before a trailing comment", function()
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

package import.bad;

message Broken {
  string value = 1 // trailing comment
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
    assert.is_true(err.message:match("';' expected") ~= nil)
  end)

  it("rejects different absolute inputs that resolve to the same logical proto name", function()
    local ok = os.execute("mkdir -p tests/tmp/root_a tests/tmp/root_b")
    assert.is_true(ok)

    write_file("tests/tmp/root_a/common.proto", [[
syntax = "proto3";

package demo.alpha;

message Alpha {
  string value = 1;
}
]])

    write_file("tests/tmp/root_b/common.proto", [[
syntax = "proto3";

package demo.beta;

message Beta {
  string value = 1;
}
]])

    local bytes, err = compiler.compile({
      proto_paths = {
        "tests/tmp/root_a",
        "tests/tmp/root_b",
      },
      inputs = {
        lfs.currentdir() .. "/tests/tmp/root_a/common.proto",
        lfs.currentdir() .. "/tests/tmp/root_b/common.proto",
      },
    })

    assert.is_nil(bytes)
    assert.are.same({
      exit_code = 1,
      message = err.message,
    }, err)
    assert.is_true(err.message:match("common%.proto") ~= nil)
    assert.is_true(err.message:match("root_a/common%.proto") ~= nil)
    assert.is_true(err.message:match("root_b/common%.proto") ~= nil)
  end)

  it("rejects brace-valued option blocks missing a trailing semicolon", function()
    local ok = os.execute("mkdir -p tests/tmp/proto_root/google/protobuf")
    assert.is_true(ok)

    write_file("tests/tmp/proto_root/google/protobuf/descriptor.proto", [[
syntax = "proto2";
package google.protobuf;
message FileOptions {
  extensions 1000 to max;
}
]])

    write_file("tests/tmp/proto_root/bad_brace_option.proto", [[
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

    local bytes, err = compiler.compile({
      proto_paths = { "tests/tmp/proto_root" },
      inputs = { "bad_brace_option.proto" },
    })

    assert.is_nil(bytes)
    assert.are.same({
      exit_code = 1,
      message = err.message,
    }, err)
    assert.is_true(err.message:match("bad_brace_option%.proto") ~= nil)
    assert.is_true(err.message:match("';' expected") ~= nil)
  end)
end)

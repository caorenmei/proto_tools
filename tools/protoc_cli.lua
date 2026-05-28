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

local argparse = require("argparse")

local M = {}

local function new_parser()
  local parser = argparse("protoc_cli", "Generate a protobuf descriptor set")

  parser:option("--proto_path")
    :target("proto_paths")
    :count("*")
    :argname("<path>")

  parser:option("--descriptor_set_out")
    :target("descriptor_set_out")
    :argname("<file>")

  parser:argument("inputs")
    :target("inputs")
    :args("*")
    :argname("<proto>")

  return parser
end

function M.parse(argv)
  local ok, parsed_or_err = new_parser():pparse(argv)
  if not ok then
    return false, {
      exit_code = 2,
      message = parsed_or_err,
    }
  end

  local config = parsed_or_err

  if not config.proto_paths or next(config.proto_paths) == nil then
    config.proto_paths = { "." }
  end

  if not config.inputs then
    config.inputs = {}
  end

  if not config.descriptor_set_out then
    return false, {
      exit_code = 2,
      message = "missing required option '--descriptor_set_out'",
    }
  end

  return true, config
end

return M

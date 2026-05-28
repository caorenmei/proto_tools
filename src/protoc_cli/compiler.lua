local pb = require("pb")
local protoc = require("protoc")
local path_search = require("protoc_cli.path_search")

local M = {}

local function structured_error(err)
  if type(err) == "table" then
    return {
      exit_code = 1,
      message = tostring(err.message or err),
    }
  end

  return {
    exit_code = 1,
    message = tostring(err),
  }
end

local function append_files(files, seen, set)
  for _, file in ipairs(set.file or {}) do
    if not seen[file.name] then
      seen[file.name] = true
      table.insert(files, file)
    end
  end
end

local function validate_source(resolved)
  for line in io.lines(resolved.absolute_path) do
    if line:match("^%s*package%s+[%w%.]+%s*$") then
      error(string.format("%s: ';' expected after package declaration", resolved.import_name), 0)
    end
  end
end

local function read_source(resolved)
  local handle, err = io.open(resolved.absolute_path, "rb")
  if not handle then
    error(err, 0)
  end

  local source = handle:read("*a")
  handle:close()
  return source
end

local function compile_resolved(parser, resolved)
  validate_source(resolved)
  return assert(parser:compile(read_source(resolved), resolved.import_name))
end

function M.compile(config)
  local resolver = path_search.new(config.proto_paths or { "." })
  local parser = protoc.new()
  local files = {}
  local seen = {}

  parser.proto3_optional = true
  parser.include_imports = true
  parser.paths = {}
  parser.unknown_import = function(import_parser, name)
    local resolved, err = resolver:resolve_import(name)
    if not resolved then
      error(err, 0)
    end

    validate_source(resolved)
    return import_parser:parse(read_source(resolved), resolved.import_name)
  end

  local ok, result = xpcall(function()
    for _, input in ipairs(config.inputs or {}) do
      local resolved, err = resolver:resolve_input(input)
      if not resolved then
        error(err, 0)
      end

      local set = assert(
        pb.decode(
          ".google.protobuf.FileDescriptorSet",
          compile_resolved(parser, resolved)
        )
      )

      append_files(files, seen, set)
    end

    return pb.encode(".google.protobuf.FileDescriptorSet", { file = files })
  end, function(err)
    return err
  end)

  if not ok then
    return nil, structured_error(result)
  end

  return result
end

return M

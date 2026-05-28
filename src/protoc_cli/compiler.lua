local pb = require("pb")
local protoc = require("protoc_cli.patched_protoc")
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

local function register_resolved_file(seen, resolved)
  local existing = seen[resolved.import_name]
  if existing and existing ~= resolved.absolute_path then
    error(
      string.format(
        "duplicate logical proto name '%s' resolves to multiple files: %s and %s",
        resolved.import_name,
        existing,
        resolved.absolute_path
      ),
      0
    )
  end

  seen[resolved.import_name] = resolved.absolute_path
end

local function qualify(scope, name)
  if scope == nil or scope == "" then
    return name
  end

  return scope .. "." .. name
end

local function register_symbol(symbols, symbol, file_name)
  local existing = symbols[symbol]
  if existing and existing ~= file_name then
    error(
      string.format(
        "duplicate fully-qualified symbol '%s' found in files '%s' and '%s'",
        symbol,
        existing,
        file_name
      ),
      0
    )
  end

  symbols[symbol] = file_name
end

local function register_message_symbols(symbols, scope, message, file_name)
  local message_name = qualify(scope, message.name)
  register_symbol(symbols, message_name, file_name)

  for _, nested in ipairs(message.nested_type or {}) do
    register_message_symbols(symbols, message_name, nested, file_name)
  end

  for _, enum in ipairs(message.enum_type or {}) do
    register_symbol(symbols, qualify(message_name, enum.name), file_name)
  end

  for _, extension in ipairs(message.extension or {}) do
    register_symbol(symbols, qualify(message_name, extension.name), file_name)
  end
end

local function register_file_symbols(symbols, seen_files, file)
  if seen_files[file.name] then
    return
  end

  local scope = file.package or ""

  for _, message in ipairs(file.message_type or {}) do
    register_message_symbols(symbols, scope, message, file.name)
  end

  for _, enum in ipairs(file.enum_type or {}) do
    register_symbol(symbols, qualify(scope, enum.name), file.name)
  end

  for _, service in ipairs(file.service or {}) do
    register_symbol(symbols, qualify(scope, service.name), file.name)
  end

  for _, extension in ipairs(file.extension or {}) do
    register_symbol(symbols, qualify(scope, extension.name), file.name)
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

local function canonicalize_dependencies(resolver, file)
  for i, dependency in ipairs(file.dependency or {}) do
    local resolved = assert(resolver:resolve_import(dependency))
    file.dependency[i] = resolved.import_name
  end
end

local function compile_resolved(parser, resolved)
  return assert(parser:compile(read_source(resolved), resolved.import_name))
end

local function new_parser(resolver, resolved_files)
  local parser = protoc.new()

  parser.proto3_optional = true
  parser.include_imports = true
  parser.paths = {}
  parser.unknown_import = function(import_parser, name)
    local resolved, err = resolver:resolve_import(name)
    if not resolved then
      error(err, 0)
    end
    register_resolved_file(resolved_files, resolved)
    return import_parser:parse(read_source(resolved), resolved.import_name)
  end

  return parser
end

function M.compile(config)
  local resolver = path_search.new(config.proto_paths or { "." })
  local files = {}
  local seen = {}
  local resolved_files = {}
  local symbols = {}

  local ok, result = xpcall(function()
    for _, input in ipairs(config.inputs or {}) do
      local resolved, err = resolver:resolve_input(input)
      if not resolved then
        error(err, 0)
      end

      register_resolved_file(resolved_files, resolved)
      local parser = new_parser(resolver, resolved_files)
      local set = assert(
        pb.decode(
          ".google.protobuf.FileDescriptorSet",
          compile_resolved(parser, resolved)
        )
      )

      for _, file in ipairs(set.file or {}) do
        canonicalize_dependencies(resolver, file)
        register_file_symbols(symbols, seen, file)
      end

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

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

local function strip_comments(line, in_block_comment)
  local quote_char = nil
  local escaped = false
  local parts = {}
  local had_line_comment = false
  local had_block_comment = false
  local index = 1

  while index <= #line do
    local ch = line:sub(index, index)
    local next_two = line:sub(index, index + 1)

    if in_block_comment then
      had_block_comment = true
      if next_two == "*/" then
        in_block_comment = false
        index = index + 2
      else
        index = index + 1
      end
    elseif escaped then
      table.insert(parts, ch)
      escaped = false
      index = index + 1
    elseif quote_char and ch == "\\" then
      table.insert(parts, ch)
      escaped = true
      index = index + 1
    elseif quote_char and ch == quote_char then
      table.insert(parts, ch)
      quote_char = nil
      index = index + 1
    elseif not quote_char and (ch == '"' or ch == "'") then
      table.insert(parts, ch)
      quote_char = ch
      index = index + 1
    elseif not quote_char and next_two == "//" then
      had_line_comment = true
      break
    elseif not quote_char and next_two == "/*" then
      had_block_comment = true
      in_block_comment = true
      index = index + 2
    else
      table.insert(parts, ch)
      index = index + 1
    end
  end

  return table.concat(parts), had_line_comment, had_block_comment, in_block_comment
end

local function missing_semicolon_kind(line)
  local trimmed = line:match("^%s*(.-)%s*$")
  if trimmed == "" then
    return nil
  end

  if trimmed:match("[;{}%[]%s*$") or trimmed:match(",%s*$") then
    return nil
  end

  if trimmed:match("^package%s+") then
    return "package"
  end

  if trimmed:match("^syntax%s*=")
    or trimmed:match("^import%s+")
    or trimmed:match("^option%s+")
    or trimmed:match("^reserved%s+")
    or trimmed:match("^extensions%s+")
    or trimmed:match("^rpc%s+.-%)%s+returns%s*%b()")
    or trimmed:match("=")
  then
    return "statement"
  end
end

local function update_square_bracket_depth(line, depth)
  local quote_char = nil
  local escaped = false

  for index = 1, #line do
    local ch = line:sub(index, index)

    if escaped then
      escaped = false
    elseif quote_char and ch == "\\" then
      escaped = true
    elseif quote_char and ch == quote_char then
      quote_char = nil
    elseif not quote_char and (ch == '"' or ch == "'") then
      quote_char = ch
    elseif not quote_char and ch == "[" then
      depth = depth + 1
    elseif not quote_char and ch == "]" and depth > 0 then
      depth = depth - 1
    end
  end

  return depth
end

local function update_curly_brace_depth(line, depth)
  local quote_char = nil
  local escaped = false

  for index = 1, #line do
    local ch = line:sub(index, index)

    if escaped then
      escaped = false
    elseif quote_char and ch == "\\" then
      escaped = true
    elseif quote_char and ch == quote_char then
      quote_char = nil
    elseif not quote_char and (ch == '"' or ch == "'") then
      quote_char = ch
    elseif not quote_char and ch == "{" then
      depth = depth + 1
    elseif not quote_char and ch == "}" and depth > 0 then
      depth = depth - 1
    end
  end

  return depth
end

local function raise_missing_semicolon(resolved, kind, line_number)
  if kind == "package" then
    error(string.format("%s:%d: ';' expected after package declaration", resolved.import_name, line_number), 0)
  end

  error(string.format("%s:%d: ';' expected before end of statement", resolved.import_name, line_number), 0)
end

local function opens_option_block(line)
  local trimmed = line:match("^%s*(.-)%s*$")
  return trimmed:match("=%s*.-%[%s*$") ~= nil
end

local function opens_brace_valued_option_block(line)
  local trimmed = line:match("^%s*(.-)%s*$")
  return trimmed:match("^option%s+.-=%s*{%s*$") ~= nil
end

local function validate_source(resolved)
  local in_block_comment = false
  local square_bracket_depth = 0
  local curly_brace_depth = 0
  local pending_statement = nil
  local line_number = 0
  for line in io.lines(resolved.absolute_path) do
    line_number = line_number + 1

    local uncommented, _, _, next_in_block_comment = strip_comments(line, in_block_comment)
    local depth_before_line = square_bracket_depth
    local brace_depth_before_line = curly_brace_depth
    square_bracket_depth = update_square_bracket_depth(uncommented, square_bracket_depth)
    curly_brace_depth = update_curly_brace_depth(uncommented, curly_brace_depth)
    local trimmed = uncommented:match("^%s*(.-)%s*$")

    if pending_statement then
      if trimmed == "" then
        -- Comments and whitespace can separate a statement from its semicolon.
      elseif trimmed:match("^;") then
        pending_statement = nil
      elseif pending_statement.awaiting_value then
        if trimmed:match(";%s*$") then
          pending_statement = nil
        else
          pending_statement.awaiting_value = trimmed:match("=%s*$") ~= nil
        end
      elseif trimmed:match("^%[") then
        pending_statement.in_option_block = true
      elseif depth_before_line > 0 or pending_statement.in_option_block then
        if square_bracket_depth > 0 then
          pending_statement.in_option_block = true
        elseif trimmed:match("^%]%s*;") then
          pending_statement = nil
        elseif trimmed:match("^%]") then
          pending_statement.in_option_block = false
        else
          raise_missing_semicolon(resolved, pending_statement.kind, pending_statement.line_number)
        end
      elseif brace_depth_before_line > 0 or pending_statement.in_brace_option_block then
        if curly_brace_depth > 0 then
          pending_statement.in_brace_option_block = true
        elseif trimmed:match("^}%s*;") then
          pending_statement = nil
        elseif trimmed:match("^}") then
          pending_statement.in_brace_option_block = false
        else
          raise_missing_semicolon(resolved, pending_statement.kind, pending_statement.line_number)
        end
      else
        raise_missing_semicolon(resolved, pending_statement.kind, pending_statement.line_number)
      end
    end

    if not pending_statement then
      local kind = missing_semicolon_kind(uncommented)

      if kind and depth_before_line == 0 and square_bracket_depth == 0 then
        pending_statement = {
          kind = kind,
          line_number = line_number,
          in_option_block = false,
          awaiting_value = trimmed:match("=%s*$") ~= nil,
        }
      elseif depth_before_line == 0 and square_bracket_depth > 0 and opens_option_block(uncommented) then
        pending_statement = {
          kind = "statement",
          line_number = line_number,
          in_option_block = true,
          awaiting_value = false,
        }
      elseif brace_depth_before_line == 0 and curly_brace_depth > 0 and opens_brace_valued_option_block(uncommented) then
        pending_statement = {
          kind = "statement",
          line_number = line_number,
          in_option_block = false,
          in_brace_option_block = true,
          awaiting_value = false,
        }
      elseif depth_before_line > 0 and square_bracket_depth == 0 and trimmed:match("^%]") then
        pending_statement = {
          kind = "statement",
          line_number = line_number,
          in_option_block = false,
          in_brace_option_block = false,
          awaiting_value = false,
        }

        if trimmed:match("^%]%s*;") then
          pending_statement = nil
        end
      end
    elseif depth_before_line > 0 and square_bracket_depth == 0 and trimmed:match("^%]") then
      if trimmed:match("^%]%s*;") then
        pending_statement = nil
      else
        pending_statement.in_option_block = false
      end
    elseif brace_depth_before_line > 0 and curly_brace_depth == 0 and trimmed:match("^}") then
      if trimmed:match("^}%s*;") then
        pending_statement = nil
      else
        pending_statement.in_brace_option_block = false
      end
    end

    in_block_comment = next_in_block_comment
  end

  if pending_statement then
    raise_missing_semicolon(resolved, pending_statement.kind, pending_statement.line_number)
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
  local resolved_files = {}

  parser.proto3_optional = true
  parser.include_imports = true
  parser.paths = {}
  parser.unknown_import = function(import_parser, name)
    local resolved, err = resolver:resolve_import(name)
    if not resolved then
      error(err, 0)
    end

    register_resolved_file(resolved_files, resolved)
    validate_source(resolved)
    return import_parser:parse(read_source(resolved), resolved.import_name)
  end

  local ok, result = xpcall(function()
    for _, input in ipairs(config.inputs or {}) do
      local resolved, err = resolver:resolve_input(input)
      if not resolved then
        error(err, 0)
      end

      register_resolved_file(resolved_files, resolved)
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

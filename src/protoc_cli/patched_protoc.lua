local SUPPORTED_LUA_PROTOBUF_VERSION = "0.5.3-1"

local function read_file(path)
  local handle, err = io.open(path, "rb")
  if not handle then
    error(err, 0)
  end

  local source = handle:read("*a")
  handle:close()
  return source
end

local function replace_once(source, before, after, label)
  local start_index, end_index = source:find(before, 1, true)
  if not start_index then
    error(
      string.format(
        "failed to patch upstream protoc source (%s); expected lua-protobuf %s",
        label,
        SUPPORTED_LUA_PROTOBUF_VERSION
      ),
      0
    )
  end

  return table.concat({
    source:sub(1, start_index - 1),
    after,
    source:sub(end_index + 1),
  })
end

local protoc_path = assert(package.searchpath("protoc", package.path))
local source = read_file(protoc_path)

source = replace_once(source, [[
function Lexer:line_end(opt)
   self:whitespace()
   local pos = self '^[%s;]*%s*()'
   if not pos then
      return self:opterror(opt, "';' expected")
   end
   self.pos = pos
   return pos
end
]], [[
function Lexer:line_end(opt)
   self:whitespace()
   local pos
   if opt then
      pos = self '^[%s;]*%s*()'
   else
      pos = self '^;[%s;]*%s*()'
   end
   if not pos then
      return self:opterror(opt, "';' expected")
   end
   self.pos = pos
   return pos
end

function Lexer:block_end()
   self:whitespace()
   local pos = self '^[%s;]*%s*()'
   self.pos = pos
   return pos
end
]], "Lexer:line_end")

source = replace_once(source, [[
      if ident == "option" then
         toplevel.option(self, lex, oneof)
      else
         local f, t = field(self, lex, ident)
         self.locmap[f] = lex.pos
         if t then insert_tab(ts, t) end
         f.oneof_index = index - 1
         insert_tab(fs, f)
      end
      lex:line_end 'opt'
]], [[
      if ident == "option" then
         toplevel.option(self, lex, oneof)
         lex:block_end()
      else
         local f, t = field(self, lex, ident)
         self.locmap[f] = lex.pos
         if t then insert_tab(ts, t) end
         f.oneof_index = index - 1
         insert_tab(fs, f)
         lex:line_end()
      end
]], "oneof field terminator")

source = replace_once(source, [[
      if body_parser then
         body_parser(self, lex, typ)
      else
         local fs = default(typ, 'field')
         local f, t = label_field(self, lex, ident, typ)
         self.locmap[f] = pos
         insert_tab(fs, f)
         if t then
            local ts = default(typ, 'nested_type')
            insert_tab(ts, t)
         end
      end
      lex:line_end 'opt'
]], [[
      if body_parser then
         body_parser(self, lex, typ)
         lex:block_end()
      else
         local fs = default(typ, 'field')
         local f, t = label_field(self, lex, ident, typ)
         self.locmap[f] = pos
         insert_tab(fs, f)
         if t then
            local ts = default(typ, 'nested_type')
            insert_tab(ts, t)
         end
         lex:line_end()
      end
]], "message field terminator")

source = replace_once(source, [[
      if ident == 'option' then
         toplevel.option(self, lex, enum)
      elseif ident == 'reserved' then
         msgbody.reserved(self, lex, enum)
      else
         local values  = default(enum, 'value')
         local number  = lex:expected '=' :integer()
         local value = {
            name    = ident,
            number  = number,
            options = inline_option(lex)
         }
         self.locmap[value] = pos
         insert_tab(values, value)
      end
      lex:line_end 'opt'
]], [[
      if ident == 'option' then
         toplevel.option(self, lex, enum)
         lex:block_end()
      elseif ident == 'reserved' then
         msgbody.reserved(self, lex, enum)
         lex:block_end()
      else
         local values  = default(enum, 'value')
         local number  = lex:expected '=' :integer()
         local value = {
            name    = ident,
            number  = number,
            options = inline_option(lex)
         }
         self.locmap[value] = pos
         insert_tab(values, value)
         lex:line_end()
      end
]], "enum value terminator")

source = replace_once(source, [[
      insert_tab(ft, f)
      insert_tab(mt, t)
      lex:line_end 'opt'
]], [[
      insert_tab(ft, f)
      insert_tab(mt, t)
      lex:line_end()
]], "extend field terminator")

source = replace_once(source, [[
   lex:expected "%)"
   if lex:test "{" then
      while not lex:test "}" do
         lex:line_end "opt"
         lex:keyword "option"
         toplevel.option(self, lex, rpc)
      end
   end
   lex:line_end "opt"
]], [[
   lex:expected "%)"
   local has_body = lex:test "{"
   if has_body then
      while not lex:test "}" do
         lex:line_end "opt"
         lex:keyword "option"
         toplevel.option(self, lex, rpc)
      end
      lex:block_end()
   else
      lex:line_end()
   end
]], "rpc terminator")

local env = setmetatable({}, { __index = _ENV })
local chunk = assert(load(source, "@" .. protoc_path .. " (patched)", "t", env))

return assert(chunk())

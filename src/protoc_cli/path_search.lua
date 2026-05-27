local lfs = require("lfs")

local Resolver = {}
Resolver.__index = Resolver

local function is_absolute(path)
  return path:sub(1, 1) == "/"
end

local function to_absolute(path)
  if is_absolute(path) then
    return path
  end
  return lfs.currentdir() .. "/" .. path
end

local function file_exists(path)
  local handle = io.open(path, "rb")
  if not handle then
    return false
  end
  handle:close()
  return true
end

local function join_path(root, name)
  if root == "." or root == "" then
    return name
  end
  return root .. "/" .. name
end

function Resolver:_resolve(name)
  for _, root in ipairs(self.proto_paths) do
    local candidate = join_path(root, name)
    if file_exists(candidate) then
      return {
        import_name = name,
        absolute_path = to_absolute(candidate),
      }
    end
  end

  return nil, {
    exit_code = 1,
    message = string.format(
      "unable to resolve '%s' from --proto_path (%s)",
      name,
      table.concat(self.proto_paths, ", ")
    ),
  }
end

function Resolver:resolve_input(name)
  return self:_resolve(name)
end

function Resolver:resolve_import(name)
  return self:_resolve(name)
end

local M = {}

function M.new(proto_paths)
  return setmetatable({
    proto_paths = proto_paths,
  }, Resolver)
end

return M

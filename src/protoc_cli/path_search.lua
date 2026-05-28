local lfs = require("lfs")

local Resolver = {}
Resolver.__index = Resolver

local function is_absolute(path)
  return path:sub(1, 1) == "/"
end

local function normalize_root(root)
  if root == "" or root == "." or root == "/" then
    return root
  end

  while root:sub(-1) == "/" do
    root = root:sub(1, -2)
    if root == "/" then
      return root
    end
  end

  return root
end

local function to_absolute(path)
  if path == "." or path == "" then
    return lfs.currentdir()
  end

  if is_absolute(path) then
    return path
  end
  return lfs.currentdir() .. "/" .. path
end

local function canonicalize_absolute(path)
  local segments = {}

  for segment in to_absolute(path):gmatch("[^/]+") do
    if segment == ".." then
      if #segments > 0 then
        table.remove(segments)
      end
    elseif segment ~= "." and segment ~= "" then
      table.insert(segments, segment)
    end
  end

  if #segments == 0 then
    return "/"
  end

  return "/" .. table.concat(segments, "/")
end

local function shell_quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function realpath_existing(path)
  -- Relies on Linux/GNU realpath -e to canonicalize only existing paths.
  local handle = io.popen(
    "realpath -e -- " .. shell_quote(to_absolute(path)) .. " 2>/dev/null",
    "r"
  )
  if not handle then
    return nil
  end

  local resolved = handle:read("*a")
  handle:close()

  resolved = resolved:gsub("%s+$", "")
  if resolved == "" then
    return nil
  end

  return resolved
end

local function realpath_available()
  local handle = io.popen("command -v realpath 2>/dev/null", "r")
  if not handle then
    return false
  end

  local resolved = handle:read("*a")
  handle:close()

  resolved = resolved:gsub("%s+$", "")
  return resolved ~= ""
end

local function is_regular_file(path)
  return lfs.attributes(path, "mode") == "file"
end

local function join_path(root, name)
  root = normalize_root(root)

  if root == "." or root == "" then
    return name
  end

  if root == "/" then
    return "/" .. name
  end

  return root .. "/" .. name
end

local function relative_to_root(root, path)
  local absolute_root = root

  if absolute_root ~= "/" then
    absolute_root = absolute_root:gsub("/+$", "")
  end

  if absolute_root == "/" then
    if path:sub(1, 1) == "/" then
      return path:sub(2)
    end
    return nil
  end

  if path == absolute_root then
    return ""
  end

  if path:sub(1, #absolute_root) == absolute_root and path:sub(#absolute_root + 1, #absolute_root + 1) == "/" then
    return path:sub(#absolute_root + 2)
  end

  return nil
end

function Resolver:_resolve_error(name)
  return nil, {
    exit_code = 1,
    message = string.format(
      "unable to resolve '%s' from --proto_path (%s)",
      name,
      table.concat(self.proto_paths, ", ")
    ),
  }
end

function Resolver:_dependency_error()
  return nil, {
    exit_code = 1,
    message = "path resolution requires external 'realpath' in PATH",
  }
end

function Resolver:_resolve(name)
  if not self.realpath_available then
    return self:_dependency_error()
  end

  for i, root in ipairs(self.proto_paths) do
    local candidate = join_path(root, name)
    local logical_candidate = canonicalize_absolute(candidate)
    local real_candidate = realpath_existing(candidate)
    local real_root = self.real_proto_paths[i]
    local canonical_root = self.canonical_proto_paths[i]

    if real_candidate ~= nil and real_root ~= nil and is_regular_file(real_candidate) then
      local real_import_name = relative_to_root(real_root, real_candidate)
      local import_name = relative_to_root(canonical_root, logical_candidate)
      if real_import_name ~= nil and import_name ~= nil then
        return {
          import_name = import_name,
          absolute_path = real_candidate,
        }
      end
    end
  end

  return self:_resolve_error(name)
end

function Resolver:resolve_input(name)
  if not self.realpath_available then
    return self:_dependency_error()
  end

  if is_absolute(name) then
    local logical_name = canonicalize_absolute(name)
    local real_name = realpath_existing(name)
    if real_name ~= nil and is_regular_file(real_name) then
      for i, root in ipairs(self.real_proto_paths) do
        local real_import_name = root ~= nil and relative_to_root(root, real_name) or nil
        if real_import_name ~= nil then
          return {
            import_name = real_import_name,
            absolute_path = real_name,
          }
        end
      end
    end

    return self:_resolve_error(name)
  end

  return self:_resolve(name)
end

function Resolver:resolve_import(name)
  if is_absolute(name) then
    return self:_resolve_error(name)
  end

  return self:_resolve(name)
end

local M = {}

function M.new(proto_paths)
  local normalized_proto_paths = {}
  local canonical_proto_paths = {}
  local real_proto_paths = {}
  local realpath_is_available = realpath_available()
  for i, proto_path in ipairs(proto_paths) do
    normalized_proto_paths[i] = normalize_root(proto_path)
    canonical_proto_paths[i] = canonicalize_absolute(normalized_proto_paths[i])
    if realpath_is_available then
      real_proto_paths[i] = realpath_existing(normalized_proto_paths[i])
    end
  end

  return setmetatable({
    proto_paths = normalized_proto_paths,
    canonical_proto_paths = canonical_proto_paths,
    real_proto_paths = real_proto_paths,
    realpath_available = realpath_is_available,
  }, Resolver)
end

return M

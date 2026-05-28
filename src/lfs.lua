local M = {}

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

function M.currentdir()
  local handle = assert(io.popen("pwd -P", "r"))
  local cwd = handle:read("*l")
  handle:close()
  return cwd
end

function M.attributes(path, attr)
  if attr ~= nil and attr ~= "mode" then
    return nil
  end

  local handle = io.popen(
    "stat -c %F -- " .. shell_quote(path) .. " 2>/dev/null",
    "r"
  )
  if not handle then
    return nil
  end

  local kind = handle:read("*l")
  handle:close()
  if kind == nil then
    return nil
  end

  if kind == "regular file" then
    return "file"
  end

  if kind == "directory" then
    return "directory"
  end

  return kind
end

function M.link(target, link_name, symlink)
  local command = (symlink and "ln -s -- " or "ln -- ") .. shell_quote(target) .. " " .. shell_quote(link_name)
  local ok = os.execute(command)
  return ok == true or ok == 0
end

return M

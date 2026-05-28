local M = {}

function M.write(path, bytes)
  local handle, open_err = io.open(path, "wb")
  if not handle then
    return nil, {
      exit_code = 1,
      message = string.format("unable to open '%s' for writing: %s", path, open_err),
    }
  end

  local ok, write_err = handle:write(bytes)
  if not ok then
    handle:close()
    return nil, {
      exit_code = 1,
      message = string.format("unable to write '%s': %s", path, write_err),
    }
  end

  local closed, close_err = handle:close()
  if closed == nil then
    return nil, {
      exit_code = 1,
      message = string.format("unable to close '%s': %s", path, close_err),
    }
  end

  return true
end

return M

local package_path_prefix = table.concat({
  "src/?.lua",
  "src/?/init.lua",
  "./?.lua",
}, ";")

local package_cpath_prefix = "lua_modules/lib/lua/5.4/?.so"

package.path = package_path_prefix .. ";" .. package.path
package.cpath = package_cpath_prefix .. ";" .. package.cpath


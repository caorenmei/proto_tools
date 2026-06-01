local package_path_prefix = table.concat({
  "lua_lib/?.lua",
  "lua_lib/?/init.lua",
  "lua_tests/?.lua",
  "lua_tests/?/init.lua",
  -- busted 运行时 cwd 可能是 lua_tests/，添加相对路径
  "../lua_lib/?.lua",
  "../lua_lib/?/init.lua",
  "?.lua",
  "?/init.lua",
  "src/?.lua",
  "src/?/init.lua",
  "./?.lua",
}, ";")

local package_cpath_prefix = "lua_modules/lib/lua/5.4/?.so"

package.path = package_path_prefix .. ";" .. package.path
package.cpath = package_cpath_prefix .. ";" .. package.cpath

-- 预加载 protobuf 描述符类型定义，供 pb.decode 使用
local protoc = require("protoc")
local p = protoc.new()
p:addpath("lua_tests/fixtures/protoc")
p:addpath("fixtures/protoc")
p:loadfile("imports/shared.proto")


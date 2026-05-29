local pb = require("pb")

local M = {}

--- 解析二进制描述符集文件
---@param file string 二进制描述符集文件路径
---@return google.protobuf.FileDescriptorSet
function M.parse(file)
    local f = assert(io.open(file, "rb"))
    local data = f:read("*a")
    f:close()
    local descriptor_set = assert(pb.decode("google.protobuf.FileDescriptorSet", data))
    return descriptor_set
end

return M
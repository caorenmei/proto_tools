local pb = require("pb")

local M = {}

function M.parse(file)
    local f = assert(io.open(file, "rb"))
    local data = f:read("*a")
    f:close()
    local descriptor_set = assert(pb.decode("google.protobuf.DescriptorSet", data))
    return descriptor_set
end

return M
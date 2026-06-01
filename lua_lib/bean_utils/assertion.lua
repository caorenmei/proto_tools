local math = require("math")

local M = {}

--- 空断言函数，不做任何校验
function M.assert_none()

end

---@param value integer
function M.assert_int32(value)
    assert(math.type(value) == "integer" and value >= -0x80000000 and value <= 0x7FFFFFFF, "value must be an integer in range [-0x80000000, 0x7FFFFFFF]")
end

---@param value integer
function M.assert_uint32(value)
    assert(math.type(value) == "integer" and value >= 0 and value <= 0xFFFFFFFF, "value must be an integer in range [0, 0xFFFFFFFF]")
end

---@param value string
function M.assert_string(value)
    assert(type(value) == "string", "value must be a string")
end

---@param value boolean
function M.assert_boolean(value)
    assert(type(value) == "boolean", "value must be a boolean")
end

---@param value number
function M.assert_float(value)
    assert(type(value) == "number", "value must be a number")
end

return M

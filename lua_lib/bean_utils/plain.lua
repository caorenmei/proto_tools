local math = require("math")

local M = {}

--- 空断言函数，不做任何校验
local function assert_none()

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

---@generic ValueType
---@param self any[]
---@param data_index integer
---@param value ValueType
---@param assertion fun(value: ValueType)
function M.set_field(self, data_index, value, assertion)
    local old_value = self[data_index]
    if old_value == value then
        return false
    end
    assertion(value)
    self[data_index] = value
    return true
end

---@generic MessageType
---@param self any[]
---@param data_index integer
---@param constructor fun(): MessageType
---@return MessageType
function M.get_message(self, data_index, constructor)
    local value = self[data_index]
    if value then
        return value
    end
    local new_value = constructor()
    self[data_index] = new_value
    return new_value
end

---@generic ValueType
---@param self any[]
---@param data_index integer
---@param oneof_index integer
---@param value ValueType
---@param assertion fun(value: ValueType)
function M.set_oneof_field(self, data_index, oneof_index, value, assertion)
    local old_index = self[data_index] --[[@as integer]]
    local old_value = self[data_index + 1]
    if old_index == oneof_index and old_value == value then
        return false
    end
    assertion(value)
    self[data_index] = oneof_index
    self[data_index + 1] = value
    return true
end

---@generic MessageType
---@param self any[]
---@param data_index integer
---@param oneof_index integer
---@param constructor fun(): MessageType
---@return MessageType
function M.add_oneof_message(self, data_index, oneof_index, constructor)
    local index = self[data_index] --[[@as integer]]
    local value = self[data_index + 1]
    if index == oneof_index and value then
        return value
    end
    local new_value = constructor()
    M.set_oneof_field(self, data_index, oneof_index, new_value, assert_none)
    return new_value
end

---@param self any[]
---@param data_index integer
function M.clear_oneof_field(self, data_index)
    local old_index = self[data_index] --[[@as integer]]
    if old_index == 0 then
        return
    end
    self[data_index] = 0
    self[data_index + 1] = false
end

---@generic ValueType
---@param self any[]
---@param data_index integer
---@param value ValueType
---@param assertion fun(value: ValueType)
function M.add_repeated_value(self, data_index, value, assertion)
    assertion(value)
    local list = self[data_index] --[=[@as any[]?]=]
    if not list then
        list = {}
        self[data_index] = list
    end
    list[#list + 1] = value
end

---@generic ValueType
---@param self any[]
---@param data_index integer
---@param value_index integer
---@param value ValueType
---@param assertion fun(value: ValueType)
function M.set_repeated_value(self, data_index, value_index, value, assertion)
    assertion(value)
    local list = self[data_index] --[=[@as any[]]=]
    assert(list and value_index >= 1 and value_index <= #list, "index out of range")
    list[value_index] = value
end

---@param self any[]
---@param data_index integer
---@return any?
function M.pop_repeated_value(self, data_index)
    local list = self[data_index] --[=[@as any[]?]=]
    if not list then
        return nil
    end
    local length = #list
    if length == 0 then
        return nil
    end
    local value = list[length]
    list[length] = nil
    return value
end

---@param self any[]
---@param data_index integer
function M.clear_repeated_value(self, data_index)
    local list = self[data_index] --[=[@as any[]?]=]
    if not list then
        return
    end
    local length = #list
    if length == 0 then
        return
    end
    for i = length, 1, -1 do
        list[i] = nil
    end
end

---@generic MessageType
---@param self any[]
---@param data_index integer
---@param constructor fun(): MessageType
---@return MessageType
function M.add_repeated_message(self, data_index, constructor)
    local new_value = constructor()
    M.add_repeated_value(self, data_index, new_value, assert_none)
    return new_value
end

---@generic MessageType
---@param self any[]
---@param data_index integer
---@return MessageType?
function M.pop_repeated_message(self, data_index)
    return M.pop_repeated_value(self, data_index)
end

---@param self any[]
---@param data_index integer
function M.clear_repeated_message(self, data_index)
    M.clear_repeated_value(self, data_index)
end

---@generic KeyType
---@generic ValueType
---@param self any[]
---@param data_index integer
---@param key KeyType
---@param value ValueType
---@param assertion fun(key: KeyType, value: ValueType)
function M.set_map_value(self, data_index, key, value, assertion)
    assertion(key, value)
    local length = self[data_index] --[[@as integer]]
    local map = self[data_index + 1]
    if not map then
        map = {}
        self[data_index + 1] = map
    end
    if map[key] == nil then
        length = length + 1
        self[data_index] = length
    end
    map[key] = value
end

---@generic KeyType
---@generic ValueType
---@param self any[]
---@param data_index integer
---@param key KeyType
---@return ValueType?
function M.remove_map_key(self, data_index, key)
    local length = self[data_index] --[[@as integer]]
    local map = self[data_index + 1]
    if not map then
        return
    end
    local value = map[key]
    if value == nil then
        return
    end
    map[key] = nil
    length = length - 1
    self[data_index] = length
    return value
end

---@param self any[]
---@param data_index integer
function M.clear_map(self, data_index)
    local length = self[data_index] --[[@as integer]]
    local map = self[data_index + 1] --[[@as table | false]]
    if not map or length == 0 then
        return
    end
    self[data_index] = 0
    for key in pairs(map) do
        map[key] = nil
    end
end

---@generic KeyType
---@generic MessageType
---@param self any[]
---@param data_index integer
---@param key KeyType
---@param constructor fun(): MessageType
---@return MessageType
function M.add_map_message(self, data_index, key, constructor)
    local length = self[data_index] --[[@as integer]]
    local map = self[data_index + 1]
    if not map then
        map = {}
        self[data_index + 1] = map
    end
    local value = map[key]
    if value then
        return value
    end
    local new_value = constructor()
    map[key] = new_value
    length = length + 1
    self[data_index] = length
    return new_value
end

---@generic KeyType
---@generic MessageType
---@param self any[]
---@param data_index integer
---@param key KeyType
---@return MessageType?
function M.remove_map_message(self, data_index, key)
    return M.remove_map_key(self, data_index, key)
end

---@param self any[]
---@param data_index integer
function M.clear_map_message(self, data_index)
    M.clear_map(self, data_index)
end

return M

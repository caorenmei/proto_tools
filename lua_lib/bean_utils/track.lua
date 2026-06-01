local math = require("math")

local M = {}

---@param self any[]
---@param track_words integer
---@return boolean
local function is_tracked_bean(self, track_words)
    for i = 1, track_words do
        if self[1 + i] ~= 0 then
            return true
        end
    end
    return false
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param has_bit boolean
---@return boolean
local function set_track_bit(self, track_words, track_index, has_bit)
    local words_index = ((track_index + 63) // 64) + 1
    local bit_index = (track_index - 1) % 64
    local word = self[words_index] --[[@as integer ]]
    local bit = (1 << bit_index)
    local old_bit = word & bit
    if (old_bit ~= 0) == has_bit then
        return false
    end
    local modified = is_tracked_bean(self, track_words)
    if has_bit then
        self[words_index] = word | bit
    else
        self[words_index] = word & ~bit
    end
    if not modified and has_bit and self[1] then
        self[1](true)
    elseif modified and not has_bit and self[1] and not is_tracked_bean(self, track_words) then
        self[1](false)
    end
    return true
end

---@enum bean_utils.TrackState
local TrackState = {
    Added = 1,
    Updated = 2,
    Removed = 3,
    RemovedAdded = 4,
}

---@param track_maps table
---@param map table
---@return table
---@return boolean
local function get_track_map(track_maps, map)
    local track_map = track_maps[map]
    local new_track = false
    if track_map == nil then
        track_map = {}
        track_maps[map] = track_map
        new_track = true
    end
    return track_map, new_track
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param track_maps table
---@param map table
---@param key any
local function track_map_add(self, track_words, track_index, track_maps, map, key)
    local track_map, new_track = get_track_map(track_maps, map)
    local state = track_map[key]
    if state == nil then
        track_map[key] = TrackState.Added
    elseif state == TrackState.Removed then
        track_map[key] = TrackState.RemovedAdded
    end
    if new_track then
        set_track_bit(self, track_words, track_index, true)
    end
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param track_maps table
---@param map table
---@param key any
---@param has_bit boolean
local function track_map_update(self, track_words, track_index, track_maps, map, key, has_bit)
    local track_map, new_track = get_track_map(track_maps, map)
    local state = track_map[key]
    if state == nil and has_bit then
        track_map[key] = TrackState.Updated
        if new_track then
            set_track_bit(self, track_words, track_index, true)
        end
    elseif state == TrackState.Updated and not has_bit then
        track_map[key] = nil
        if next(track_map) == nil then
            track_maps[map] = nil
            set_track_bit(self, track_words, track_index, false)
        end
    end
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param track_maps table
---@param map table
---@param key any
local function track_map_remove(self, track_words, track_index, track_maps, map, key)
    local track_map, new_track = get_track_map(track_maps, map)
    local state = track_map[key]
    if state == TrackState.Added then
        track_map[key] = nil
        if next(track_map) == nil then
            track_maps[map] = nil
            set_track_bit(self, track_words, track_index, false)
        end
    else
        track_map[key] = TrackState.Removed
        if new_track then
            set_track_bit(self, track_words, track_index, true)
        end
    end
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param track_maps table
---@param map table
---@param key any
local function track_map_remove_add(self, track_words, track_index, track_maps, map, key)
    local track_map, new_track = get_track_map(track_maps, map)
    local state = track_map[key]
    if state == nil then
        track_map[key] = TrackState.Added
        if new_track then
            set_track_bit(self, track_words, track_index, true)
        end
    elseif state == TrackState.Updated then
        track_map[key] = TrackState.RemovedAdded
        if new_track then
            set_track_bit(self, track_words, track_index, true)
        end
    end
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param track_maps table
---@param list any[]
---@param length integer
local function track_map_clear_repeated(self, track_words, track_index, track_maps, list, length)
    local track_map, new_track = get_track_map(track_maps, list)
    for i = length, 1, -1 do
        local state = track_map[i]
        if state == TrackState.Added then
            track_map[i] = nil
        else
            track_map[i] = TrackState.Removed
        end
        list[i] = nil
    end
    if next(track_map) == nil then
        track_maps[list] = nil
        set_track_bit(self, track_words, track_index, false)
    elseif new_track then
        set_track_bit(self, track_words, track_index, true)
    end
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param track_maps table
---@param map table
local function track_map_clear_map(self, track_words, track_index, track_maps, map)
    local track_map, new_track = get_track_map(track_maps, map)
    for key in pairs(map) do
        local state = track_map[key]
        if state == TrackState.Added then
            track_map[key] = nil
        else
            track_map[key] = TrackState.Removed
        end
        map[key] = nil
    end
    if next(track_map) == nil then
        track_maps[map] = nil
        set_track_bit(self, track_words, track_index, false)
    elseif new_track then
        set_track_bit(self, track_words, track_index, true)
    end
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@return fun(has_bit: boolean)
local function create_track_message(self, track_words, track_index)
    return function(has_bit)
        set_track_bit(self, track_words, track_index, has_bit)
    end
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param track_maps table
---@param map table
---@param key any
---@return fun(has_bit: boolean)
local function create_track_map_message(self, track_words, track_index, track_maps, map, key)
    return function(has_bit)
        track_map_update(self, track_words, track_index, track_maps, map, key, has_bit)
    end
end

local assertion = require("bean_utils.assertion")

local assert_none = assertion.assert_none

M.assert_none = assertion.assert_none
M.assert_int32 = assertion.assert_int32
M.assert_uint32 = assertion.assert_uint32
M.assert_string = assertion.assert_string
M.assert_boolean = assertion.assert_boolean
M.assert_float = assertion.assert_float

---@generic ValueType
---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param value ValueType
---@param assertion fun(value: ValueType)
function M.set_field(self, track_words, track_index, data_index, value, assertion)
    local old_value = self[data_index]
    if old_value == value then
        return false
    end
    assertion(value)
    self[data_index] = value
    set_track_bit(self, track_words, track_index, true)
    return true
end

---@generic MessageType
---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param constructor fun(): MessageType
---@return MessageType
function M.get_message(self, track_words, track_index, data_index, constructor)
    local value = self[data_index]
    if value then
        return value
    end
    local new_value = constructor()
    new_value[1] = create_track_message(self, track_words, track_index)
    self[data_index] = new_value
    set_track_bit(self, track_words, track_index, true)
    return new_value
end

---@generic ValueType
---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
---@param oneof_index integer
---@param value ValueType
---@param assertion fun(value: ValueType)
function M.set_oneof_field(self, track_words, track_index, data_index, track_maps, oneof_index, value, assertion)
    local old_index = self[data_index] --[[@as integer]]
    local old_value = self[data_index + 1]
    if old_index == oneof_index and old_value == value then
        return false
    end
    assertion(value)
    if (old_index & 1) == 1 then
        old_value[1] = false
    end
    self[data_index] = oneof_index
    self[data_index + 1] = value
    if old_index == 0 then
        track_map_add(self, track_words, track_index, track_maps, self, track_index)
    elseif old_index ~= oneof_index then
        track_map_remove_add(self, track_words, track_index, track_maps, self, track_index)
    else
        track_map_update(self, track_words, track_index, track_maps, self, track_index, true)
    end
end

---@generic MessageType
---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
---@param oneof_index integer
---@param constructor fun(): MessageType
---@return MessageType
function M.add_oneof_message(self, track_words, track_index, data_index, track_maps, oneof_index, constructor)
    local index = self[data_index] --[[@as integer]]
    local value = self[data_index + 1]
    if index == oneof_index and value then
        return value
    end
    local new_value = constructor()
    new_value[1] = create_track_map_message(self, track_words, track_index, track_maps, self, track_index)
    M.set_oneof_field(self, track_words, track_index, data_index, track_maps, oneof_index, new_value, assert_none)
    return new_value
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
function M.clear_oneof_field(self, track_words, track_index, data_index, track_maps)
    local old_index = self[data_index] --[[@as integer]]
    if old_index == 0 then
        return
    end
    local old_value = self[data_index + 1] --[[@as any | false]]
    if (old_index & 1) == 1 then
        old_value[1] = false
    end
    self[data_index] = 0
    self[data_index + 1] = false
    track_map_remove(self, track_words, track_index, track_maps, self, track_index)
end

---@generic ValueType
---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
---@param value ValueType
---@param assertion fun(value: ValueType)
function M.add_repeated_value(self, track_words, track_index, data_index, track_maps, value, assertion)
    assertion(value)
    local list = self[data_index] --[=[@as any[]?]=]
    if not list then
        list = {}
        self[data_index] = list
    end
    list[#list + 1] = value
    track_map_add(self, track_words, track_index, track_maps, list, #list)
end

---@generic ValueType
---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
---@param value_index integer
---@param value ValueType
---@param assertion fun(value: ValueType)
function M.set_repeated_value(self, track_words, track_index, data_index, track_maps, value_index, value, assertion)
    assertion(value)
    local list = self[data_index] --[=[@as any[]]=]
    assert(list and value_index >= 1 and value_index <= #list, "index out of range")
    if list[value_index] == value then
        return
    end
    list[value_index] = value
    track_map_update(self, track_words, track_index, track_maps, list, value_index, true)
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
---@return any?
function M.pop_repeated_value(self, track_words, track_index, data_index, track_maps)
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
    track_map_remove(self, track_words, track_index, track_maps, list, length)
    return value
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
function M.clear_repeated_value(self, track_words, track_index, data_index, track_maps)
    local list = self[data_index] --[=[@as any[]?]=]
    if not list then
        return
    end
    local length = #list
    if length == 0 then
        return
    end
    track_map_clear_repeated(self, track_words, track_index, track_maps, list, length)
end

---@generic MessageType
---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
---@param constructor fun(): MessageType
---@return MessageType
function M.add_repeated_message(self, track_words, track_index, data_index, track_maps, constructor)
    local new_value = constructor()
    M.add_repeated_value(self, track_words, track_index, data_index, track_maps, new_value, assert_none)
    new_value[1] = create_track_map_message(self, track_words, track_index, track_maps, self, track_index)
    return new_value
end

---@generic MessageType
---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
---@return MessageType?
function M.pop_repeated_message(self, track_words, track_index, data_index, track_maps)
    local value = M.pop_repeated_value(self, track_words, track_index, data_index, track_maps)
    if value then
        value[1] = false
    end
    return value
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
function M.clear_repeated_message(self, track_words, track_index, data_index, track_maps)
    local list = self[data_index] --[=[@as any[]?]=]
    if list then
        for _, value in ipairs(list) do
            value[1] = false
        end
    end
    M.clear_repeated_value(self, track_words, track_index, data_index, track_maps)
end

---@generic KeyType
---@generic ValueType
---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
---@param key KeyType
---@param value ValueType
---@param assertion fun(key: KeyType, value: ValueType)
function M.set_map_value(self, track_words, track_index, data_index, track_maps, key, value, assertion)
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
        map[key] = value
        track_map_add(self, track_words, track_index, track_maps, map, key)
    elseif map[key] ~= value then
        map[key] = value
        track_map_update(self, track_words, track_index, track_maps, map, key, true)
    end
end

---@generic KeyType
---@generic ValueType
---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
---@param key KeyType
---@return ValueType?
function M.remove_map_key(self, track_words, track_index, data_index, track_maps, key)
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
    track_map_remove(self, track_words, track_index, track_maps, map, key)
    return value
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
function M.clear_map(self, track_words, track_index, data_index, track_maps)
    local length = self[data_index] --[[@as integer]]
    local map = self[data_index + 1] --[[@as table | false]]
    if not map or length == 0 then
        return
    end
    self[data_index] = 0
    track_map_clear_map(self, track_words, track_index, track_maps, map)
end

---@generic KeyType
---@generic MessageType
---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
---@param key KeyType
---@param constructor fun(): MessageType
---@return MessageType
function M.add_map_message(self, track_words, track_index, data_index, track_maps, key, constructor)
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
    new_value[1] = create_track_map_message(self, track_words, track_index, track_maps, map, key)
    map[key] = new_value
    length = length + 1
    self[data_index] = length
    track_map_add(self, track_words, track_index, track_maps, map, key)
    return new_value
end

---@generic KeyType
---@generic MessageType
---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
---@param key KeyType
---@return MessageType?
function M.remove_map_message(self, track_words, track_index, data_index, track_maps, key)
    local value = M.remove_map_key(self, track_words, track_index, data_index, track_maps, key)
    if value then
        value[1] = false
    end
    return value
end

---@param self any[]
---@param track_words integer
---@param track_index integer
---@param data_index integer
---@param track_maps table
function M.clear_map_message(self, track_words, track_index, data_index, track_maps)
    local map = self[data_index + 1] --[[@as table | false]]
    if map then
        for _, value in pairs(map) do
            value[1] = false
        end
    end
    M.clear_map(self, track_words, track_index, data_index, track_maps)
end

return M

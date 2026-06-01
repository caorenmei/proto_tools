local M = {}
local b = require("fixtures.bean_info.descriptor_builder")

--- 创建空 track 消息（level=1, 无字段）
---@param name string
---@param package string
---@return table
function M.empty_track_message(name, package)
    return b.message(name, {}, {}, {}, {}, { level = 1 })
end

--- 创建包含标量字段的 track 消息（level=1）
---@param name string
---@param package string
---@return table
function M.scalar_track_message(name, package)
    local fields = {
        b.field("id", 5, 1, 1, {}), -- TYPE_INT32 = 5, LABEL_OPTIONAL = 1
    }
    return b.message(name, fields, {}, {}, {}, { level = 1 })
end

--- 创建引用另一个消息的 track 消息（level=1）
---@param name string
---@param package string
---@param ref_type string 被引用消息的全名（带点前缀，如 ".demo.Inner"）
---@return table
function M.ref_track_message(name, package, ref_type)
    local fields = {
        b.field("ref", 11, 1, 1, { type_name = ref_type }), -- TYPE_MESSAGE = 11
    }
    return b.message(name, fields, {}, {}, {}, { level = 1 })
end

--- 创建 map entry 消息
---@param name string
---@param key_type integer
---@param value_type integer
---@param value_type_name string|nil map value 为消息类型时的类型名
---@return table
function M.map_entry_message(name, key_type, value_type, value_type_name)
    local fields = {
        b.field("key", key_type, 1, 1, {}),
        b.field("value", value_type, 2, 1, { type_name = value_type_name }),
    }
    return b.message(name, fields, {}, {}, {}, { map_entry = true })
end

--- 循环引用场景：A→B→A，无标量字段
---@return table descriptor_set
function M.cycle_reference_scenario()
    return b.descriptor_set(
        b.file("test.proto", "demo", {
            b.message("A", {
                b.field("b", 11, 1, 1, { type_name = ".demo.B" }),
            }, {}, {}, {}, { level = 1 }),
            b.message("B", {
                b.field("a", 11, 1, 1, { type_name = ".demo.A" }),
            }, {}, {}, {}, { level = 1 }),
        }, {})
    )
end

--- 空内层消息场景：EmptyInner 为空消息，Root 引用它
---@return table descriptor_set
function M.empty_inner_scenario()
    return b.descriptor_set(
        b.file("test.proto", "demo", {
            b.message("EmptyInner", {}, {}, {}, {}, { level = 1 }),
            b.message("Root", {
                b.field("empty_field", 11, 1, 1, { type_name = ".demo.EmptyInner" }),
                b.field("id", 5, 2, 1, {}),
            }, {}, {}, {}, { level = 1 }),
        }, {})
    )
end

--- 自引用场景
---@return table descriptor_set
function M.self_reference_scenario()
    return b.descriptor_set(
        b.file("test.proto", "demo", {
            b.message("SelfRef", {
                b.field("self", 11, 1, 1, { type_name = ".demo.SelfRef" }),
            }, {}, {}, {}, { level = 1 }),
        }, {})
    )
end

--- 多级嵌套 non-trackable 场景：L1→L2→L3，全部为空消息
---@return table descriptor_set
function M.nested_nontrackable_scenario()
    return b.descriptor_set(
        b.file("test.proto", "demo", {
            b.message("L1", {}, {}, {}, {}, { level = 1 }),
            b.message("L2", {
                b.field("l1", 11, 1, 1, { type_name = ".demo.L1" }),
            }, {}, {}, {}, { level = 1 }),
            b.message("L3", {
                b.field("l2", 11, 1, 1, { type_name = ".demo.L2" }),
            }, {}, {}, {}, { level = 1 }),
            b.message("Root", {
                b.field("l3", 11, 1, 1, { type_name = ".demo.L3" }),
                b.field("id", 5, 2, 1, {}),
            }, {}, {}, {}, { level = 1 }),
        }, {})
    )
end

--- oneof 引用 non-trackable 消息场景
---@return table descriptor_set
function M.oneof_nontrackable_scenario()
    return b.descriptor_set(
        b.file("test.proto", "demo", {
            b.message("Inner", {}, {}, {}, {}, { level = 1 }),
            b.message("Outer", {
                b.field("inner1", 11, 1, 1, { type_name = ".demo.Inner", oneof_index = 0 }),
                b.field("inner2", 11, 2, 1, { type_name = ".demo.Inner", oneof_index = 0 }),
            }, {
                b.oneof("choice"),
            }, {}, {}, { level = 1 }),
        }, {})
    )
end

--- map value 为 non-trackable 消息场景
---@return table descriptor_set
function M.map_value_nontrackable_scenario()
    return b.descriptor_set(
        b.file("test.proto", "demo", {
            b.message("ValueMsg", {}, {}, {}, {}, { level = 1 }),
            M.map_entry_message("MsgMapEntry", 9, 11, ".demo.ValueMsg"), -- TYPE_STRING=9, TYPE_MESSAGE=11
            b.message("Root", {
                b.field("msg_map", 11, 1, 3, { type_name = ".demo.MsgMapEntry" }), -- LABEL_REPEATED=3
                b.field("id", 5, 2, 1, {}),
            }, {}, {}, {}, { level = 1 }),
        }, {})
    )
end

--- repeated 消息字段引用 non-trackable 场景
---@return table descriptor_set
function M.repeated_nontrackable_scenario()
    return b.descriptor_set(
        b.file("test.proto", "demo", {
            b.message("Inner", {}, {}, {}, {}, { level = 1 }),
            b.message("Outer", {
                b.field("inners", 11, 1, 3, { type_name = ".demo.Inner" }), -- LABEL_REPEATED=3
                b.field("id", 5, 2, 1, {}),
            }, {}, {}, {}, { level = 1 }),
        }, {})
    )
end

--- 有效配置：track 消息引用 trackable 消息
---@return table descriptor_set
function M.valid_reference_scenario()
    return b.descriptor_set(
        b.file("test.proto", "demo", {
            b.message("Child", {
                b.field("value", 5, 1, 1, {}),
            }, {}, {}, {}, { level = 1 }),
            b.message("Root", {
                b.field("child", 11, 1, 1, { type_name = ".demo.Child" }),
                b.field("id", 5, 2, 1, {}),
            }, {}, {}, {}, { level = 1 }),
        }, {})
    )
end

--- 有效配置：混合标量字段和 trackable 消息字段
---@return table descriptor_set
function M.valid_mixed_scenario()
    return b.descriptor_set(
        b.file("test.proto", "demo", {
            b.message("Inner", {
                b.field("value", 5, 1, 1, {}),
            }, {}, {}, {}, { level = 1 }),
            b.message("Root", {
                b.field("name", 9, 1, 1, {}),   -- TYPE_STRING=9
                b.field("count", 5, 2, 1, {}),  -- TYPE_INT32=5
                b.field("inner", 11, 3, 1, { type_name = ".demo.Inner" }),
            }, {}, {}, {}, { level = 1 }),
        }, {})
    )
end

--- 有效配置：oneof 包含 trackable 分支
---@return table descriptor_set
function M.valid_oneof_scenario()
    return b.descriptor_set(
        b.file("test.proto", "demo", {
            b.message("Inner", {
                b.field("value", 5, 1, 1, {}),
            }, {}, {}, {}, { level = 1 }),
            b.message("Root", {
                b.field("text", 9, 1, 1, { oneof_index = 0 }),
                b.field("num", 5, 2, 1, { oneof_index = 0 }),
                b.field("inner", 11, 3, 1, { type_name = ".demo.Inner", oneof_index = 0 }),
            }, {
                b.oneof("choice"),
            }, {}, {}, { level = 1 }),
        }, {})
    )
end

return M

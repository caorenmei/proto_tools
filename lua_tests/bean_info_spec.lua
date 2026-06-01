describe("bean_info", function()
    local bean_info
    local db
    local pf

    setup(function()
        dofile("lua_tests/support/env.lua")
        bean_info = require("gen_bean.bean_info")
        db = require("fixtures.bean_info.descriptor_builder")
        pf = require("fixtures.bean_info.preset_fixtures")
    end)

    describe("模块可加载性", function()
        it("require 成功", function()
            assert.is_not_nil(bean_info)
        end)
    end)

    describe("常量导出", function()
        it("FieldType 包含所有 protobuf 字段类型", function()
            assert.are.equal(1, bean_info.FieldType.TYPE_DOUBLE)
            assert.are.equal(2, bean_info.FieldType.TYPE_FLOAT)
            assert.are.equal(3, bean_info.FieldType.TYPE_INT64)
            assert.are.equal(4, bean_info.FieldType.TYPE_UINT64)
            assert.are.equal(5, bean_info.FieldType.TYPE_INT32)
            assert.are.equal(6, bean_info.FieldType.TYPE_FIXED64)
            assert.are.equal(7, bean_info.FieldType.TYPE_FIXED32)
            assert.are.equal(8, bean_info.FieldType.TYPE_BOOL)
            assert.are.equal(9, bean_info.FieldType.TYPE_STRING)
            assert.are.equal(10, bean_info.FieldType.TYPE_GROUP)
            assert.are.equal(11, bean_info.FieldType.TYPE_MESSAGE)
            assert.are.equal(12, bean_info.FieldType.TYPE_BYTES)
            assert.are.equal(13, bean_info.FieldType.TYPE_UINT32)
            assert.are.equal(14, bean_info.FieldType.TYPE_ENUM)
            assert.are.equal(15, bean_info.FieldType.TYPE_SFIXED32)
            assert.are.equal(16, bean_info.FieldType.TYPE_SFIXED64)
            assert.are.equal(17, bean_info.FieldType.TYPE_SINT32)
            assert.are.equal(18, bean_info.FieldType.TYPE_SINT64)
        end)

        it("FieldLabel 包含所有标签类型", function()
            assert.are.equal(1, bean_info.FieldLabel.LABEL_OPTIONAL)
            assert.are.equal(2, bean_info.FieldLabel.LABEL_REQUIRED)
            assert.are.equal(3, bean_info.FieldLabel.LABEL_REPEATED)
        end)

        it("IntegerTypes 包含所有整数类型", function()
            assert.is_true(bean_info.IntegerTypes[bean_info.FieldType.TYPE_INT32])
            assert.is_true(bean_info.IntegerTypes[bean_info.FieldType.TYPE_INT64])
            assert.is_true(bean_info.IntegerTypes[bean_info.FieldType.TYPE_UINT32])
            assert.is_true(bean_info.IntegerTypes[bean_info.FieldType.TYPE_UINT64])
            assert.is_true(bean_info.IntegerTypes[bean_info.FieldType.TYPE_SINT32])
            assert.is_true(bean_info.IntegerTypes[bean_info.FieldType.TYPE_SINT64])
            assert.is_true(bean_info.IntegerTypes[bean_info.FieldType.TYPE_FIXED32])
            assert.is_true(bean_info.IntegerTypes[bean_info.FieldType.TYPE_FIXED64])
            assert.is_true(bean_info.IntegerTypes[bean_info.FieldType.TYPE_SFIXED32])
            assert.is_true(bean_info.IntegerTypes[bean_info.FieldType.TYPE_SFIXED64])
            assert.is_nil(bean_info.IntegerTypes[bean_info.FieldType.TYPE_DOUBLE])
            assert.is_nil(bean_info.IntegerTypes[bean_info.FieldType.TYPE_STRING])
        end)

        it("NumberTypes 包含浮点类型", function()
            assert.is_true(bean_info.NumberTypes[bean_info.FieldType.TYPE_DOUBLE])
            assert.is_true(bean_info.NumberTypes[bean_info.FieldType.TYPE_FLOAT])
            assert.is_nil(bean_info.NumberTypes[bean_info.FieldType.TYPE_INT32])
        end)

        it("StringTypes 包含字符串和字节类型", function()
            assert.is_true(bean_info.StringTypes[bean_info.FieldType.TYPE_STRING])
            assert.is_true(bean_info.StringTypes[bean_info.FieldType.TYPE_BYTES])
            assert.is_nil(bean_info.StringTypes[bean_info.FieldType.TYPE_INT32])
        end)

        it("EnumTypes 只包含 TYPE_ENUM", function()
            assert.is_true(bean_info.EnumTypes[bean_info.FieldType.TYPE_ENUM])
            assert.is_nil(bean_info.EnumTypes[bean_info.FieldType.TYPE_INT32])
        end)
    end)

    describe("build_field_info", function()
        it("普通字段正确设置 name、type、index", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = { full_name = "test.Msg", fields = {}, oneofs = {} }
            local field = {
                name = "id",
                type = bean_info.FieldType.TYPE_INT32,
                number = 1,
                label = bean_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = nil,
            }

            bean_info.build_field_info(info, file_info, message_info, field, 1)

            local fi = message_info.fields[1]
            assert.is_not_nil(fi)
            assert.are.equal(field, fi.descriptor)
            assert.are.equal("test.Msg", fi.message)
            assert.are.equal("id", fi.name)
            assert.are.equal(1, fi.index)
            assert.are.equal(bean_info.FieldType.TYPE_INT32, fi.type)
            assert.is_false(fi.is_repeated)
            assert.is_false(fi.is_map)
            assert.is_false(fi.is_oneof)
            assert.are.equal("", fi.oneof_name)
            assert.are.equal(0, fi.oneof_index)
            assert.are.equal(0, fi.map_key_type)
            assert.are.equal(0, fi.map_value_type)
            assert.are.equal(0, fi.track_index)
            assert.are.equal(0, fi.data_index)
        end)

        it("repeated 字段 is_repeated = true", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = { full_name = "test.Msg", fields = {}, oneofs = {} }
            local field = {
                name = "tags",
                type = bean_info.FieldType.TYPE_STRING,
                number = 1,
                label = bean_info.FieldLabel.LABEL_REPEATED,
                oneof_index = nil,
            }

            bean_info.build_field_info(info, file_info, message_info, field, 1)

            local fi = message_info.fields[1]
            assert.is_true(fi.is_repeated)
            assert.is_false(fi.is_map)
        end)

        it("消息类型字段 type 为消息全名（去掉前缀 '.'）", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = { full_name = "test.Msg", fields = {}, oneofs = {} }
            local field = {
                name = "child",
                type = bean_info.FieldType.TYPE_MESSAGE,
                number = 1,
                label = bean_info.FieldLabel.LABEL_OPTIONAL,
                type_name = ".test.Child",
                oneof_index = nil,
            }

            bean_info.build_field_info(info, file_info, message_info, field, 1)

            local fi = message_info.fields[1]
            assert.are.equal("test.Child", fi.type)
        end)

        it("oneof 字段 is_oneof = true，oneof_index 正确", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = { full_name = "test.Msg", fields = {}, oneofs = {} }
            local field = {
                name = "text",
                type = bean_info.FieldType.TYPE_STRING,
                number = 1,
                label = bean_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = 0,
            }

            bean_info.build_field_info(info, file_info, message_info, field, 1)

            local fi = message_info.fields[1]
            assert.is_true(fi.is_oneof)
            assert.are.equal(1, fi.oneof_index)
        end)
    end)

    describe("build_oneof_info", function()
        it("正确构建 oneof 信息", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = { full_name = "test.Msg", oneofs = {} }
            local oneof = { name = "payload" }

            bean_info.build_oneof_info(info, file_info, message_info, oneof, 1)

            local oi = message_info.oneofs[1]
            assert.is_not_nil(oi)
            assert.are.equal(oneof, oi.descriptor)
            assert.are.equal("test.Msg", oi.message)
            assert.are.equal("payload", oi.name)
            assert.are.equal(1, oi.index)
            assert.are.equal(0, oi.track_index)
            assert.are.equal(0, oi.data_index)
        end)
    end)

    describe("process_fields", function()
        it("map 字段正确识别（is_map = true，map_key_type/map_value_type 正确）", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            -- 先注册 map entry 消息
            info.messages["test.Msg.MapEntry"] = {
                full_name = "test.Msg.MapEntry",
                descriptor = {
                    options = { map_entry = true },
                    field = {
                        { name = "key", type = bean_info.FieldType.TYPE_STRING },
                        { name = "value", type = bean_info.FieldType.TYPE_INT32 },
                    },
                },
            }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 0 } },
            }
            local field = {
                name = "items",
                type = bean_info.FieldType.TYPE_MESSAGE,
                number = 1,
                label = bean_info.FieldLabel.LABEL_REPEATED,
                type_name = ".test.Msg.MapEntry",
                oneof_index = nil,
            }

            bean_info.build_field_info(info, file_info, message_info, field, 1)
            bean_info.process_fields(info, file_info, message_info)

            local fi = message_info.fields[1]
            assert.is_true(fi.is_map)
            assert.are.equal(bean_info.FieldType.TYPE_STRING, fi.map_key_type)
            assert.are.equal(bean_info.FieldType.TYPE_INT32, fi.map_value_type)
        end)

        it("map 字段 value 为消息类型时 map_value_type 正确", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            info.messages["test.Msg.MapEntry"] = {
                full_name = "test.Msg.MapEntry",
                descriptor = {
                    options = { map_entry = true },
                    field = {
                        { name = "key", type = bean_info.FieldType.TYPE_STRING },
                        { name = "value", type = bean_info.FieldType.TYPE_MESSAGE, type_name = ".test.Other" },
                    },
                },
            }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 0 } },
            }
            local field = {
                name = "items",
                type = bean_info.FieldType.TYPE_MESSAGE,
                number = 1,
                label = bean_info.FieldLabel.LABEL_REPEATED,
                type_name = ".test.Msg.MapEntry",
                oneof_index = nil,
            }

            bean_info.build_field_info(info, file_info, message_info, field, 1)
            bean_info.process_fields(info, file_info, message_info)

            local fi = message_info.fields[1]
            assert.is_true(fi.is_map)
            assert.are.equal("test.Other", fi.map_value_type)
        end)

        it("非 level=0 消息分配 track_index", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 1 } },
            }
            local field = {
                name = "name",
                type = bean_info.FieldType.TYPE_STRING,
                number = 1,
                label = bean_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = nil,
                options = nil,
            }

            bean_info.build_field_info(info, file_info, message_info, field, 1)
            bean_info.process_fields(info, file_info, message_info)

            local fi = message_info.fields[1]
            assert.are.equal(1, fi.track_index)
            assert.are.equal(1, message_info.track_field_count)
            assert.are.equal(1, message_info.track_words)
        end)

        it("level=0 消息不分配 track_index", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 0 } },
            }
            local field = {
                name = "name",
                type = bean_info.FieldType.TYPE_STRING,
                number = 1,
                label = bean_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = nil,
            }

            bean_info.build_field_info(info, file_info, message_info, field, 1)
            bean_info.process_fields(info, file_info, message_info)

            local fi = message_info.fields[1]
            assert.are.equal(0, fi.track_index)
            assert.are.equal(0, message_info.track_field_count)
            assert.are.equal(0, message_info.track_words)
        end)

        it("带 transient 选项的字段不分配 track_index", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 1 } },
            }
            local f1 = {
                name = "normal",
                type = bean_info.FieldType.TYPE_STRING,
                number = 1,
                label = bean_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = nil,
                options = nil,
            }
            local f2 = {
                name = "transient",
                type = bean_info.FieldType.TYPE_INT32,
                number = 2,
                label = bean_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = nil,
                options = { transient = true },
            }

            bean_info.build_field_info(info, file_info, message_info, f1, 1)
            bean_info.build_field_info(info, file_info, message_info, f2, 2)
            bean_info.process_fields(info, file_info, message_info)

            assert.are.equal(1, message_info.fields[1].track_index)
            assert.are.equal(0, message_info.fields[2].track_index)
            assert.are.equal(1, message_info.track_field_count)
        end)

        it("无 options 的消息默认分配 track_index", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = {}, -- 无 options
            }
            local field = {
                name = "name",
                type = bean_info.FieldType.TYPE_STRING,
                number = 1,
                label = bean_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = nil,
            }

            bean_info.build_field_info(info, file_info, message_info, field, 1)
            bean_info.process_fields(info, file_info, message_info)

            local fi = message_info.fields[1]
            assert.are.equal(1, fi.track_index)
        end)

        it("data_index 正确分配——普通字段占 1 个", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 0 } },
            }

            local f1 = { name = "a", type = bean_info.FieldType.TYPE_INT32, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = nil }
            local f2 = { name = "b", type = bean_info.FieldType.TYPE_STRING, number = 2, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = nil }

            bean_info.build_field_info(info, file_info, message_info, f1, 1)
            bean_info.build_field_info(info, file_info, message_info, f2, 2)
            bean_info.process_fields(info, file_info, message_info)

            assert.are.equal(1, message_info.fields[1].data_index)
            assert.are.equal(2, message_info.fields[2].data_index)
        end)

        it("map 字段占 2 个 data_index", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            info.messages["test.Msg.MapEntry"] = {
                full_name = "test.Msg.MapEntry",
                descriptor = {
                    options = { map_entry = true },
                    field = {
                        { name = "key", type = bean_info.FieldType.TYPE_STRING },
                        { name = "value", type = bean_info.FieldType.TYPE_INT32 },
                    },
                },
            }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 0 } },
            }

            local f1 = { name = "a", type = bean_info.FieldType.TYPE_INT32, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = nil }
            local f2 = { name = "m", type = bean_info.FieldType.TYPE_MESSAGE, number = 2, label = bean_info.FieldLabel.LABEL_REPEATED, type_name = ".test.Msg.MapEntry", oneof_index = nil }

            bean_info.build_field_info(info, file_info, message_info, f1, 1)
            bean_info.build_field_info(info, file_info, message_info, f2, 2)
            bean_info.process_fields(info, file_info, message_info)

            assert.are.equal(1, message_info.fields[1].data_index)
            assert.are.equal(2, message_info.fields[2].data_index)
        end)

        it("oneof 字段占 2 个 data_index，同 oneof 内字段共享 data_index", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 0 } },
            }

            local f1 = { name = "text", type = bean_info.FieldType.TYPE_STRING, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 0 }
            local f2 = { name = "num", type = bean_info.FieldType.TYPE_INT32, number = 2, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 0 }

            bean_info.build_field_info(info, file_info, message_info, f1, 1)
            bean_info.build_field_info(info, file_info, message_info, f2, 2)
            bean_info.build_oneof_info(info, file_info, message_info, { name = "payload" }, 1)
            bean_info.process_fields(info, file_info, message_info)

            assert.are.equal(1, message_info.fields[1].data_index)
            assert.are.equal(1, message_info.fields[2].data_index)
            assert.are.equal(1, message_info.oneofs[1].data_index)
            -- oneof_data_index: (1 << 1) + 0 = 2 for string type, (2 << 1) + 0 = 4 for int32 type
            assert.are.equal(2, message_info.fields[1].oneof_data_index)
            assert.are.equal(4, message_info.fields[2].oneof_data_index)
        end)

        it("oneof 字段为消息类型时 oneof_data_index 最低位为 1", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 0 } },
            }

            local f1 = { name = "text", type = bean_info.FieldType.TYPE_STRING, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 0 }
            local f2 = { name = "child", type = bean_info.FieldType.TYPE_MESSAGE, number = 2, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 0, type_name = ".test.Child" }

            bean_info.build_field_info(info, file_info, message_info, f1, 1)
            bean_info.build_field_info(info, file_info, message_info, f2, 2)
            bean_info.build_oneof_info(info, file_info, message_info, { name = "payload" }, 1)
            bean_info.process_fields(info, file_info, message_info)

            -- oneof_data_index: (1 << 1) + 0 = 2 for string type, (2 << 1) + 1 = 5 for message type
            assert.are.equal(2, message_info.fields[1].oneof_data_index)
            assert.are.equal(5, message_info.fields[2].oneof_data_index)
        end)

        it("oneof 字段在 track 消息中分配 track_index（通过 oneof_info）", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 1 } },
            }

            local f1 = { name = "text", type = bean_info.FieldType.TYPE_STRING, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 0, options = nil }
            local f2 = { name = "num", type = bean_info.FieldType.TYPE_INT32, number = 2, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 0, options = nil }

            bean_info.build_field_info(info, file_info, message_info, f1, 1)
            bean_info.build_field_info(info, file_info, message_info, f2, 2)
            bean_info.build_oneof_info(info, file_info, message_info, { name = "payload" }, 1)
            bean_info.process_fields(info, file_info, message_info)

            -- oneof 的 track_index 通过 oneof_info 分配，字段共享同一个 track_index
            assert.are.equal(1, message_info.fields[1].track_index)
            assert.are.equal(1, message_info.fields[2].track_index)
            assert.are.equal(1, message_info.oneofs[1].track_index)
            assert.are.equal(1, message_info.track_field_count)
        end)

        it("多个 oneof 各自独立分配 track_index", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 1 } },
            }

            local f1 = { name = "a", type = bean_info.FieldType.TYPE_STRING, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 0, options = nil }
            local f2 = { name = "b", type = bean_info.FieldType.TYPE_INT32, number = 2, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 0, options = nil }
            local f3 = { name = "c", type = bean_info.FieldType.TYPE_STRING, number = 3, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 1, options = nil }
            local f4 = { name = "d", type = bean_info.FieldType.TYPE_INT32, number = 4, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 1, options = nil }

            bean_info.build_field_info(info, file_info, message_info, f1, 1)
            bean_info.build_field_info(info, file_info, message_info, f2, 2)
            bean_info.build_field_info(info, file_info, message_info, f3, 3)
            bean_info.build_field_info(info, file_info, message_info, f4, 4)
            bean_info.build_oneof_info(info, file_info, message_info, { name = "first" }, 1)
            bean_info.build_oneof_info(info, file_info, message_info, { name = "second" }, 2)
            bean_info.process_fields(info, file_info, message_info)

            assert.are.equal(1, message_info.fields[1].track_index)
            assert.are.equal(1, message_info.fields[2].track_index)
            assert.are.equal(2, message_info.fields[3].track_index)
            assert.are.equal(2, message_info.fields[4].track_index)
            assert.are.equal(1, message_info.oneofs[1].track_index)
            assert.are.equal(2, message_info.oneofs[2].track_index)
            assert.are.equal(2, message_info.track_field_count)
        end)

        it("track_words 计算正确（超过 64 个字段）", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 1 } },
            }

            -- 创建 65 个普通字段
            for i = 1, 65 do
                local field = {
                    name = "f" .. i,
                    type = bean_info.FieldType.TYPE_INT32,
                    number = i,
                    label = bean_info.FieldLabel.LABEL_OPTIONAL,
                    oneof_index = nil,
                    options = nil,
                }
                bean_info.build_field_info(info, file_info, message_info, field, i)
            end

            bean_info.process_fields(info, file_info, message_info)

            assert.are.equal(65, message_info.track_field_count)
            assert.are.equal(2, message_info.track_words)
        end)
    end)

    describe("build_enum_info", function()
        it("正确构建枚举信息", function()
            local info = { enums = {} }
            local file_info = { name = "test.proto", enums = {} }
            local enum = {
                name = "Status",
                value = {
                    { name = "UNKNOWN", number = 0 },
                    { name = "ACTIVE", number = 1 },
                    { name = "DELETED", number = 2 },
                },
            }

            bean_info.build_enum_info(info, file_info, enum, "demo.", "demo.")

            local ei = info.enums["demo.Status"]
            assert.is_not_nil(ei)
            assert.are.equal(enum, ei.descriptor)
            assert.are.equal("test.proto", ei.file)
            assert.are.equal("Status", ei.name)
            assert.are.equal("demo.Status", ei.full_name)
            assert.are.equal("demo.Status", ei.full_name_dot)
            assert.are.equal(3, #ei.values)
            assert.are.equal("UNKNOWN", ei.values[1].key)
            assert.are.equal(0, ei.values[1].value)
            assert.are.equal("ACTIVE", ei.values[2].key)
            assert.are.equal(1, ei.values[2].value)
            assert.are.equal("DELETED", ei.values[3].key)
            assert.are.equal(2, ei.values[3].value)

            -- 也通过 dot 名称访问
            assert.are.equal(ei, info.enums["demo.Status"])
        end)
    end)

    describe("build_message_info", function()
        it("正确构建消息信息", function()
            local info = { messages = {}, enums = {} }
            local file_info = { name = "test.proto", messages = {}, enums = {} }
            local message = {
                name = "Person",
                field = {
                    { name = "id", type = bean_info.FieldType.TYPE_INT32, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL },
                },
                oneof_decl = {},
                nested_type = {},
                enum_type = {},
                options = { level = 0 },
            }

            bean_info.build_message_info(info, file_info, message, "demo.", "demo.")

            local mi = info.messages["demo.Person"]
            assert.is_not_nil(mi)
            assert.are.equal(message, mi.descriptor)
            assert.are.equal("test.proto", mi.file)
            assert.are.equal("Person", mi.name)
            assert.are.equal("demo.Person", mi.full_name)
            assert.are.equal("demo.Person", mi.full_name_dot)
            assert.are.equal(1, #mi.fields)
            assert.are.equal(0, #mi.oneofs)
            assert.are.equal(0, mi.track_field_count)
            assert.are.equal(0, mi.track_words)
        end)
    end)

    describe("build_info", function()
        it("空描述符集返回空结构", function()
            local descriptor_set = { file = {} }

            local info = bean_info.build_info(descriptor_set)

            assert.is_not_nil(info)
            assert.are.equal(descriptor_set, info.descriptor_set)
            assert.are.equal(0, #info.files)
            assert.are.equal(0, #info.messages)
            assert.are.equal(0, #info.enums)
        end)

        it("包含简单消息的描述符集正确解析", function()
            local descriptor_set = {
                file = {
                    {
                        name = "test.proto",
                        package = "demo",
                        message_type = {
                            {
                                name = "Person",
                                field = {
                                    {
                                        name = "id",
                                        number = 1,
                                        label = bean_info.FieldLabel.LABEL_OPTIONAL,
                                        type = bean_info.FieldType.TYPE_INT32,
                                    },
                                    {
                                        name = "name",
                                        number = 2,
                                        label = bean_info.FieldLabel.LABEL_OPTIONAL,
                                        type = bean_info.FieldType.TYPE_STRING,
                                    },
                                },
                                oneof_decl = {},
                                enum_type = {},
                                nested_type = {},
                                options = { level = 1 },
                            },
                        },
                        enum_type = {},
                    },
                },
            }

            local info = bean_info.build_info(descriptor_set)

            -- file info
            local file_info = info.files["test.proto"]
            assert.is_not_nil(file_info)
            assert.are.equal("test.proto", file_info.name)
            assert.are.equal("demo", file_info.package_name)
            assert.are.equal(1, #file_info.messages)
            assert.are.equal(0, #file_info.enums)

            -- message info
            local msg = info.messages["demo.Person"]
            assert.is_not_nil(msg)
            assert.are.equal("Person", msg.name)
            assert.are.equal("demo.Person", msg.full_name)
            assert.are.equal("demo.Person", msg.full_name_dot)
            assert.are.equal("test.proto", msg.file)
            assert.are.equal(2, #msg.fields)
            assert.are.equal("id", msg.fields[1].name)
            assert.are.equal(bean_info.FieldType.TYPE_INT32, msg.fields[1].type)
            assert.are.equal("name", msg.fields[2].name)
            assert.are.equal(bean_info.FieldType.TYPE_STRING, msg.fields[2].type)
            -- track 消息
            assert.are.equal(2, msg.track_field_count)
            assert.are.equal(1, msg.track_words)

            -- 也可以通过 dot 名称访问
            assert.are.equal(msg, info.messages["demo.Person"])
        end)

        it("包含枚举的描述符集正确解析", function()
            local descriptor_set = {
                file = {
                    {
                        name = "test.proto",
                        package = "demo",
                        message_type = {},
                        enum_type = {
                            {
                                name = "Status",
                                value = {
                                    { name = "UNKNOWN", number = 0 },
                                    { name = "ACTIVE", number = 1 },
                                },
                            },
                        },
                    },
                },
            }

            local info = bean_info.build_info(descriptor_set)

            local enum = info.enums["demo.Status"]
            assert.is_not_nil(enum)
            assert.are.equal("Status", enum.name)
            assert.are.equal("demo.Status", enum.full_name)
            assert.are.equal(2, #enum.values)
            assert.are.equal("UNKNOWN", enum.values[1].key)
            assert.are.equal(0, enum.values[1].value)
            assert.are.equal("ACTIVE", enum.values[2].key)
            assert.are.equal(1, enum.values[2].value)

            local file_info = info.files["test.proto"]
            assert.are.equal(1, #file_info.enums)
        end)

        it("空包名正确处理", function()
            local descriptor_set = {
                file = {
                    {
                        name = "test.proto",
                        package = "",
                        message_type = {
                            {
                                name = "Msg",
                                field = {},
                                oneof_decl = {},
                                enum_type = {},
                                nested_type = {},
                            },
                        },
                        enum_type = {},
                    },
                },
            }

            local info = bean_info.build_info(descriptor_set)

            assert.is_not_nil(info.messages["Msg"])
            assert.are.equal("Msg", info.messages["Msg"].full_name)
            assert.are.equal("Msg", info.messages["Msg"].full_name_dot)
        end)
    end)

    describe("嵌套消息和枚举", function()
        it("嵌套消息正确解析", function()
            local descriptor_set = {
                file = {
                    {
                        name = "test.proto",
                        package = "demo",
                        message_type = {
                            {
                                name = "Outer",
                                field = {},
                                oneof_decl = {},
                                enum_type = {},
                                nested_type = {
                                    {
                                        name = "Inner",
                                        field = {
                                            { name = "value", type = bean_info.FieldType.TYPE_INT32, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL },
                                        },
                                        oneof_decl = {},
                                        enum_type = {},
                                        nested_type = {},
                                        options = { level = 0 },
                                    },
                                },
                                options = { level = 0 },
                            },
                        },
                        enum_type = {},
                    },
                },
            }

            local info = bean_info.build_info(descriptor_set)

            assert.is_not_nil(info.messages["demo.Outer"])
            assert.is_not_nil(info.messages["demo.Outer_Inner"])
            assert.are.equal("Inner", info.messages["demo.Outer_Inner"].name)
            assert.are.equal("demo.Outer_Inner", info.messages["demo.Outer_Inner"].full_name)
            assert.are.equal("demo.Outer.Inner", info.messages["demo.Outer_Inner"].full_name_dot)
            assert.are.equal(1, #info.messages["demo.Outer_Inner"].fields)
        end)

        it("嵌套枚举正确解析", function()
            local descriptor_set = {
                file = {
                    {
                        name = "test.proto",
                        package = "demo",
                        message_type = {
                            {
                                name = "Outer",
                                field = {},
                                oneof_decl = {},
                                enum_type = {
                                    {
                                        name = "InnerEnum",
                                        value = {
                                            { name = "A", number = 0 },
                                            { name = "B", number = 1 },
                                        },
                                    },
                                },
                                nested_type = {},
                                options = { level = 0 },
                            },
                        },
                        enum_type = {},
                    },
                },
            }

            local info = bean_info.build_info(descriptor_set)

            assert.is_not_nil(info.enums["demo.Outer_InnerEnum"])
            assert.are.equal("InnerEnum", info.enums["demo.Outer_InnerEnum"].name)
            assert.are.equal("demo.Outer_InnerEnum", info.enums["demo.Outer_InnerEnum"].full_name)
            assert.are.equal("demo.Outer.InnerEnum", info.enums["demo.Outer_InnerEnum"].full_name_dot)
            assert.are.equal(2, #info.enums["demo.Outer_InnerEnum"].values)
        end)

        it("多层嵌套正确解析", function()
            local descriptor_set = {
                file = {
                    {
                        name = "test.proto",
                        package = "demo",
                        message_type = {
                            {
                                name = "L1",
                                field = {},
                                oneof_decl = {},
                                enum_type = {},
                                nested_type = {
                                    {
                                        name = "L2",
                                        field = {},
                                        oneof_decl = {},
                                        enum_type = {},
                                        nested_type = {
                                            {
                                                name = "L3",
                                                field = {},
                                                oneof_decl = {},
                                                enum_type = {},
                                                nested_type = {},
                                                options = { level = 0 },
                                            },
                                        },
                                        options = { level = 0 },
                                    },
                                },
                                options = { level = 0 },
                            },
                        },
                        enum_type = {},
                    },
                },
            }

            local info = bean_info.build_info(descriptor_set)

            assert.is_not_nil(info.messages["demo.L1"])
            assert.is_not_nil(info.messages["demo.L1_L2"])
            assert.is_not_nil(info.messages["demo.L1_L2_L3"])
            assert.are.equal("demo.L1.L2.L3", info.messages["demo.L1_L2_L3"].full_name_dot)
        end)
    end)

    describe("validate_track_references 错误检测", function()
        it("普通字段引用 non-trackable 消息时报错", function()
            local ds = pf.empty_inner_scenario()
            assert.has_error(function()
                bean_info.build_info(ds)
            end, "track field 'empty_field' in message 'demo.Root' references non-trackable message 'demo.EmptyInner'")
        end)

        it("map value 引用 non-trackable 消息时报错", function()
            local ds = pf.map_value_nontrackable_scenario()
            assert.has_error(function()
                bean_info.build_info(ds)
            end)
        end)

        it("循环引用时报错", function()
            local ds = pf.cycle_reference_scenario()
            assert.has_error(function()
                bean_info.build_info(ds)
            end)
        end)

        it("oneof 字段引用 non-trackable 消息时报错", function()
            local ds = pf.oneof_nontrackable_scenario()
            assert.has_error(function()
                bean_info.build_info(ds)
            end)
        end)

        it("自引用消息时报错", function()
            local ds = pf.self_reference_scenario()
            assert.has_error(function()
                bean_info.build_info(ds)
            end)
        end)

        it("多级嵌套 non-trackable 时报错", function()
            local ds = pf.nested_nontrackable_scenario()
            assert.has_error(function()
                bean_info.build_info(ds)
            end)
        end)

        it("repeated 消息字段引用 non-trackable 时报错", function()
            local ds = pf.repeated_nontrackable_scenario()
            assert.has_error(function()
                bean_info.build_info(ds)
            end)
        end)
    end)

    describe("compute_trackable_states 正确性", function()
        it("正确标记消息可追踪性", function()
            -- 手动构建 info 并调用 compute_trackable_states，避免触发 validate_track_references
            local info = { files = {}, messages = {} }
            local file_info = { name = "test.proto", messages = {}, enums = {} }
            info.files["test.proto"] = file_info

            -- EmptyInner: 空消息，level=1
            bean_info.build_message_info(info, file_info, {
                name = "EmptyInner", field = {}, oneof_decl = {}, enum_type = {}, nested_type = {}, options = { level = 1 }
            }, "demo.", "demo.")
            -- ScalarOnly: 有标量字段，level=1
            bean_info.build_message_info(info, file_info, {
                name = "ScalarOnly", field = {
                    { name = "id", type = bean_info.FieldType.TYPE_INT32, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL }
                }, oneof_decl = {}, enum_type = {}, nested_type = {}, options = { level = 1 }
            }, "demo.", "demo.")
            -- NestedA: 引用 EmptyInner，level=1
            bean_info.build_message_info(info, file_info, {
                name = "NestedA", field = {
                    { name = "empty", type = bean_info.FieldType.TYPE_MESSAGE, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL, type_name = ".demo.EmptyInner" }
                }, oneof_decl = {}, enum_type = {}, nested_type = {}, options = { level = 1 }
            }, "demo.", "demo.")
            -- NestedB: 引用 ScalarOnly，level=1
            bean_info.build_message_info(info, file_info, {
                name = "NestedB", field = {
                    { name = "scalar", type = bean_info.FieldType.TYPE_MESSAGE, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL, type_name = ".demo.ScalarOnly" }
                }, oneof_decl = {}, enum_type = {}, nested_type = {}, options = { level = 1 }
            }, "demo.", "demo.")

            bean_info.compute_trackable_states(info)

            assert.are.equal("non-trackable", info.messages["demo.EmptyInner"].trackable_state)
            assert.are.equal("trackable", info.messages["demo.ScalarOnly"].trackable_state)
            assert.are.equal("non-trackable", info.messages["demo.NestedA"].trackable_state)
            assert.are.equal("trackable", info.messages["demo.NestedB"].trackable_state)
        end)
    end)

    describe("有效配置的 track_index 分配", function()
        it("track 消息引用 trackable 消息", function()
            local ds = pf.valid_reference_scenario()
            local info = bean_info.build_info(ds)
            local root = info.messages["demo.Root"]
            assert.is_not_nil(root)
            assert.are.equal(1, root.fields[1].track_index)  -- child
            assert.are.equal(2, root.fields[2].track_index)  -- id
            assert.are.equal(2, root.track_field_count)
            assert.are.equal(1, root.track_words)
        end)

        it("混合标量字段和 trackable 消息字段", function()
            local ds = pf.valid_mixed_scenario()
            local info = bean_info.build_info(ds)
            local root = info.messages["demo.Root"]
            assert.is_not_nil(root)
            assert.are.equal(1, root.fields[1].track_index)  -- name
            assert.are.equal(2, root.fields[2].track_index)  -- count
            assert.are.equal(3, root.fields[3].track_index)  -- inner
            assert.are.equal(3, root.track_field_count)
        end)

        it("oneof 在有效配置中正确分配 track_index", function()
            local ds = pf.valid_oneof_scenario()
            local info = bean_info.build_info(ds)
            local root = info.messages["demo.Root"]
            assert.is_not_nil(root)
            -- oneof 的所有字段共享同一个 track_index
            assert.are.equal(1, root.fields[1].track_index)  -- text
            assert.are.equal(1, root.fields[2].track_index)  -- num
            assert.are.equal(1, root.fields[3].track_index)  -- inner
            assert.are.equal(1, root.oneofs[1].track_index)  -- choice
            -- Root 只有 oneof 的三个字段，共享 1 个 track_index
            assert.are.equal(1, root.track_field_count)
        end)

        it("track_words 计算正确（超过 64 个字段）", function()
            local fields = {}
            for i = 1, 65 do
                fields[i] = db.field("f" .. i, bean_info.FieldType.TYPE_INT32, i, bean_info.FieldLabel.LABEL_OPTIONAL, {})
            end
            local ds = db.descriptor_set(
                db.file("test.proto", "demo", {
                    db.message("Big", fields, {}, {}, {}, { level = 1 })
                }, {})
            )
            local info = bean_info.build_info(ds)
            local msg = info.messages["demo.Big"]
            assert.are.equal(65, msg.track_field_count)
            assert.are.equal(2, msg.track_words)
        end)

        it("data_index 分配正确", function()
            local ds = db.descriptor_set(
                db.file("test.proto", "demo", {
                    db.message("DataTest", {
                        db.field("a", bean_info.FieldType.TYPE_INT32, 1, bean_info.FieldLabel.LABEL_OPTIONAL, {}),
                        db.field("b", bean_info.FieldType.TYPE_STRING, 2, bean_info.FieldLabel.LABEL_OPTIONAL, {}),
                    }, {}, {}, {}, { level = 0 })
                }, {})
            )
            local info = bean_info.build_info(ds)
            local msg = info.messages["demo.DataTest"]
            assert.are.equal(1, msg.fields[1].data_index)
            assert.are.equal(2, msg.fields[2].data_index)
        end)
    end)

    describe("完整流程测试", function()
        it("包含所有字段类型的复杂消息", function()
            local descriptor_set = {
                file = {
                    {
                        name = "test.proto",
                        package = "demo",
                        message_type = {
                            {
                                name = "Complex",
                                field = {
                                    { name = "id", type = bean_info.FieldType.TYPE_INT32, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL },
                                    { name = "name", type = bean_info.FieldType.TYPE_STRING, number = 2, label = bean_info.FieldLabel.LABEL_OPTIONAL },
                                    { name = "tags", type = bean_info.FieldType.TYPE_STRING, number = 3, label = bean_info.FieldLabel.LABEL_REPEATED },
                                    { name = "child", type = bean_info.FieldType.TYPE_MESSAGE, number = 4, label = bean_info.FieldLabel.LABEL_OPTIONAL, type_name = ".demo.Child" },
                                    { name = "status", type = bean_info.FieldType.TYPE_ENUM, number = 5, label = bean_info.FieldLabel.LABEL_OPTIONAL, type_name = ".demo.Status" },
                                    { name = "payload_text", type = bean_info.FieldType.TYPE_STRING, number = 6, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 0 },
                                    { name = "payload_num", type = bean_info.FieldType.TYPE_INT32, number = 7, label = bean_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 0 },
                                },
                                oneof_decl = {
                                    { name = "payload" },
                                },
                                enum_type = {},
                                nested_type = {},
                                options = { level = 1 },
                            },
                            {
                                name = "Child",
                                field = {
                                    { name = "value", type = bean_info.FieldType.TYPE_INT32, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL },
                                },
                                oneof_decl = {},
                                enum_type = {},
                                nested_type = {},
                                options = { level = 0 },
                            },
                        },
                        enum_type = {
                            {
                                name = "Status",
                                value = {
                                    { name = "UNKNOWN", number = 0 },
                                    { name = "ACTIVE", number = 1 },
                                },
                            },
                        },
                    },
                },
            }

            local info = bean_info.build_info(descriptor_set)

            local msg = info.messages["demo.Complex"]
            assert.is_not_nil(msg)
            assert.are.equal(7, #msg.fields)

            -- 普通字段
            assert.are.equal("id", msg.fields[1].name)
            assert.are.equal(bean_info.FieldType.TYPE_INT32, msg.fields[1].type)
            assert.is_false(msg.fields[1].is_repeated)

            -- repeated 字段
            assert.are.equal("tags", msg.fields[3].name)
            assert.is_true(msg.fields[3].is_repeated)

            -- 消息类型字段
            assert.are.equal("child", msg.fields[4].name)
            assert.are.equal("demo.Child", msg.fields[4].type)

            -- 枚举类型字段
            assert.are.equal("status", msg.fields[5].name)
            assert.are.equal(bean_info.FieldType.TYPE_ENUM, msg.fields[5].type)

            -- oneof 字段
            assert.is_true(msg.fields[6].is_oneof)
            assert.are.equal(1, msg.fields[6].oneof_index)
            assert.is_true(msg.fields[7].is_oneof)
            assert.are.equal(1, msg.fields[7].oneof_index)

            -- track 分配
            -- level=0 的 Child 被标记为 trackable，所以 child 字段也有 track_index
            -- 7 个字段 - 1 个 oneof 共享 = 6 track slots
            assert.are.equal(6, msg.track_field_count)
            assert.are.equal(1, msg.track_words)
        end)

        it("包含 map 字段的完整流程", function()
            -- map entry 消息需要在引用它的消息之前被处理
            -- 这里将 map entry 作为顶层消息（先于 WithMap 定义）
            local descriptor_set = {
                file = {
                    {
                        name = "test.proto",
                        package = "demo",
                        message_type = {
                            {
                                name = "ItemsEntry",
                                field = {
                                    { name = "key", type = bean_info.FieldType.TYPE_STRING, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL },
                                    { name = "value", type = bean_info.FieldType.TYPE_INT32, number = 2, label = bean_info.FieldLabel.LABEL_OPTIONAL },
                                },
                                oneof_decl = {},
                                enum_type = {},
                                nested_type = {},
                                options = { map_entry = true },
                            },
                            {
                                name = "WithMap",
                                field = {
                                    { name = "id", type = bean_info.FieldType.TYPE_INT32, number = 1, label = bean_info.FieldLabel.LABEL_OPTIONAL },
                                    { name = "items", type = bean_info.FieldType.TYPE_MESSAGE, number = 2, label = bean_info.FieldLabel.LABEL_REPEATED, type_name = ".demo.ItemsEntry" },
                                },
                                oneof_decl = {},
                                enum_type = {},
                                nested_type = {},
                                options = { level = 1 },
                            },
                        },
                        enum_type = {},
                    },
                },
            }

            local info = bean_info.build_info(descriptor_set)

            local msg = info.messages["demo.WithMap"]
            assert.is_not_nil(msg)
            assert.are.equal(2, #msg.fields)

            -- map 字段
            local map_field = msg.fields[2]
            assert.are.equal("items", map_field.name)
            assert.is_true(map_field.is_map)
            assert.are.equal(bean_info.FieldType.TYPE_STRING, map_field.map_key_type)
            assert.are.equal(bean_info.FieldType.TYPE_INT32, map_field.map_value_type)

            -- data_index: id=1, items=2 (map 占 2 个)
            assert.are.equal(1, msg.fields[1].data_index)
            assert.are.equal(2, msg.fields[2].data_index)

            -- track_index
            assert.are.equal(1, msg.fields[1].track_index)
            assert.are.equal(2, msg.fields[2].track_index)
        end)
    end)
end)

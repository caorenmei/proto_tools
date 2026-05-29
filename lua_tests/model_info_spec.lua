local model_info = require("lua_lib.gen_model.model_info")

describe("model_info", function()
    describe("FieldType enum", function()
        it("has correct values", function()
            assert.are.equal(1, model_info.FieldType.TYPE_DOUBLE)
            assert.are.equal(2, model_info.FieldType.TYPE_FLOAT)
            assert.are.equal(3, model_info.FieldType.TYPE_INT64)
            assert.are.equal(4, model_info.FieldType.TYPE_UINT64)
            assert.are.equal(5, model_info.FieldType.TYPE_INT32)
            assert.are.equal(6, model_info.FieldType.TYPE_FIXED64)
            assert.are.equal(7, model_info.FieldType.TYPE_FIXED32)
            assert.are.equal(8, model_info.FieldType.TYPE_BOOL)
            assert.are.equal(9, model_info.FieldType.TYPE_STRING)
            assert.are.equal(10, model_info.FieldType.TYPE_GROUP)
            assert.are.equal(11, model_info.FieldType.TYPE_MESSAGE)
            assert.are.equal(12, model_info.FieldType.TYPE_BYTES)
            assert.are.equal(13, model_info.FieldType.TYPE_UINT32)
            assert.are.equal(14, model_info.FieldType.TYPE_ENUM)
            assert.are.equal(15, model_info.FieldType.TYPE_SFIXED32)
            assert.are.equal(16, model_info.FieldType.TYPE_SFIXED64)
            assert.are.equal(17, model_info.FieldType.TYPE_SINT32)
            assert.are.equal(18, model_info.FieldType.TYPE_SINT64)
        end)
    end)

    describe("FieldLabel enum", function()
        it("has correct values", function()
            assert.are.equal(1, model_info.FieldLabel.LABEL_OPTIONAL)
            assert.are.equal(2, model_info.FieldLabel.LABEL_REQUIRED)
            assert.are.equal(3, model_info.FieldLabel.LABEL_REPEATED)
        end)
    end)

    describe("type category tables", function()
        it("IntegerTypes contains all integer types", function()
            assert.is_true(model_info.IntegerTypes[model_info.FieldType.TYPE_INT32])
            assert.is_true(model_info.IntegerTypes[model_info.FieldType.TYPE_INT64])
            assert.is_true(model_info.IntegerTypes[model_info.FieldType.TYPE_UINT32])
            assert.is_true(model_info.IntegerTypes[model_info.FieldType.TYPE_UINT64])
            assert.is_true(model_info.IntegerTypes[model_info.FieldType.TYPE_SINT32])
            assert.is_true(model_info.IntegerTypes[model_info.FieldType.TYPE_SINT64])
            assert.is_true(model_info.IntegerTypes[model_info.FieldType.TYPE_FIXED32])
            assert.is_true(model_info.IntegerTypes[model_info.FieldType.TYPE_FIXED64])
            assert.is_true(model_info.IntegerTypes[model_info.FieldType.TYPE_SFIXED32])
            assert.is_true(model_info.IntegerTypes[model_info.FieldType.TYPE_SFIXED64])
            assert.is_nil(model_info.IntegerTypes[model_info.FieldType.TYPE_DOUBLE])
            assert.is_nil(model_info.IntegerTypes[model_info.FieldType.TYPE_STRING])
        end)

        it("NumberTypes contains float/double", function()
            assert.is_true(model_info.NumberTypes[model_info.FieldType.TYPE_DOUBLE])
            assert.is_true(model_info.NumberTypes[model_info.FieldType.TYPE_FLOAT])
            assert.is_nil(model_info.NumberTypes[model_info.FieldType.TYPE_INT32])
        end)

        it("StringTypes contains string/bytes", function()
            assert.is_true(model_info.StringTypes[model_info.FieldType.TYPE_STRING])
            assert.is_true(model_info.StringTypes[model_info.FieldType.TYPE_BYTES])
            assert.is_nil(model_info.StringTypes[model_info.FieldType.TYPE_INT32])
        end)

        it("EnumTypes contains only TYPE_ENUM", function()
            assert.is_true(model_info.EnumTypes[model_info.FieldType.TYPE_ENUM])
            assert.is_nil(model_info.EnumTypes[model_info.FieldType.TYPE_INT32])
        end)
    end)

    describe("build_field_info", function()
        it("builds basic field info correctly", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = { full_name = "test.Msg", fields = {}, oneofs = {} }
            local field = {
                name = "id",
                type = model_info.FieldType.TYPE_INT32,
                label = model_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = nil,
            }

            model_info.build_field_info(info, file_info, message_info, field, 1)

            local fi = message_info.fields[1]
            assert.is_not_nil(fi)
            assert.are.equal(field, fi.descriptor)
            assert.are.equal("test.Msg", fi.message)
            assert.are.equal("id", fi.name)
            assert.are.equal(1, fi.index)
            assert.are.equal(model_info.FieldType.TYPE_INT32, fi.type)
            assert.is_false(fi.is_repeated)
            assert.is_false(fi.is_map)
            assert.is_false(fi.is_oneof)
            assert.are.equal("", fi.oneof_name)
            assert.are.equal(0, fi.oneof_index)
            assert.are.equal(0, fi.map_key_type)
            assert.are.equal(0, fi.map_value_type)
            assert.are.equal(0, fi.data_index)
            assert.are.equal(0, fi.dirty_index)
        end)

        it("builds repeated field info correctly", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = { full_name = "test.Msg", fields = {}, oneofs = {} }
            local field = {
                name = "tags",
                type = model_info.FieldType.TYPE_STRING,
                label = model_info.FieldLabel.LABEL_REPEATED,
                oneof_index = nil,
            }

            model_info.build_field_info(info, file_info, message_info, field, 2)

            local fi = message_info.fields[1]
            assert.is_true(fi.is_repeated)
            assert.is_false(fi.is_map)
        end)

        it("builds oneof field info correctly", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = { full_name = "test.Msg", fields = {}, oneofs = {} }
            local field = {
                name = "text",
                type = model_info.FieldType.TYPE_STRING,
                label = model_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = 0,
            }

            model_info.build_field_info(info, file_info, message_info, field, 1)

            local fi = message_info.fields[1]
            assert.is_true(fi.is_oneof)
            assert.are.equal(1, fi.oneof_index)
        end)

        it("resolves message type to full name", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = { full_name = "test.Msg", fields = {}, oneofs = {} }
            local field = {
                name = "child",
                type = model_info.FieldType.TYPE_MESSAGE,
                label = model_info.FieldLabel.LABEL_OPTIONAL,
                type_name = ".test.Child",
                oneof_index = nil,
            }

            model_info.build_field_info(info, file_info, message_info, field, 1)

            local fi = message_info.fields[1]
            assert.are.equal("test.Child", fi.type)
        end)
    end)

    describe("process_fields", function()
        it("assigns dirty_index for non-transient fields in dirty messages", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = {
                    options = { level = 1 },
                },
            }
            local field = {
                name = "name",
                type = model_info.FieldType.TYPE_STRING,
                label = model_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = nil,
                options = nil,
            }

            model_info.build_field_info(info, file_info, message_info, field, 1)
            model_info.process_fields(info, file_info, message_info)

            local fi = message_info.fields[1]
            assert.are.equal(1, fi.dirty_index)
            assert.is_true(message_info.has_dirty_fields)
        end)

        it("skips dirty_index for transient fields", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = {
                    options = { level = 1 },
                },
            }
            local field = {
                name = "temp",
                type = model_info.FieldType.TYPE_STRING,
                label = model_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = nil,
                options = { transient = true },
            }

            model_info.build_field_info(info, file_info, message_info, field, 1)
            model_info.process_fields(info, file_info, message_info)

            local fi = message_info.fields[1]
            assert.are.equal(0, fi.dirty_index)
            assert.is_false(message_info.has_dirty_fields)
        end)

        it("skips dirty_index for level=0 messages", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = {
                    options = { level = 0 },
                },
            }
            local field = {
                name = "name",
                type = model_info.FieldType.TYPE_STRING,
                label = model_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = nil,
            }

            model_info.build_field_info(info, file_info, message_info, field, 1)
            model_info.process_fields(info, file_info, message_info)

            local fi = message_info.fields[1]
            assert.are.equal(0, fi.dirty_index)
            assert.is_false(message_info.has_dirty_fields)
        end)

        it("recognizes map fields and sets map types", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            -- 先注册 map entry 消息（build_field_info 会去掉 type_name 前面的 '.'）
            info.messages["test.Msg.MapEntry"] = {
                full_name = "test.Msg.MapEntry",
                descriptor = {
                    options = { map_entry = true },
                    field = {
                        { name = "key", type = model_info.FieldType.TYPE_STRING },
                        { name = "value", type = model_info.FieldType.TYPE_INT32 },
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
                type = model_info.FieldType.TYPE_MESSAGE,
                label = model_info.FieldLabel.LABEL_REPEATED,
                type_name = ".test.Msg.MapEntry",
                oneof_index = nil,
            }

            model_info.build_field_info(info, file_info, message_info, field, 1)
            model_info.process_fields(info, file_info, message_info)

            local fi = message_info.fields[1]
            assert.is_true(fi.is_map)
            assert.are.equal(model_info.FieldType.TYPE_STRING, fi.map_key_type)
            assert.are.equal(model_info.FieldType.TYPE_INT32, fi.map_value_type)
        end)

        it("handles map with message value type", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            info.messages["test.Msg.MapEntry"] = {
                full_name = "test.Msg.MapEntry",
                descriptor = {
                    options = { map_entry = true },
                    field = {
                        { name = "key", type = model_info.FieldType.TYPE_STRING },
                        { name = "value", type = model_info.FieldType.TYPE_MESSAGE, type_name = ".test.Other" },
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
                type = model_info.FieldType.TYPE_MESSAGE,
                label = model_info.FieldLabel.LABEL_REPEATED,
                type_name = ".test.Msg.MapEntry",
                oneof_index = nil,
            }

            model_info.build_field_info(info, file_info, message_info, field, 1)
            model_info.process_fields(info, file_info, message_info)

            local fi = message_info.fields[1]
            assert.is_true(fi.is_map)
            assert.are.equal("test.Other", fi.map_value_type)
        end)

        it("assigns data_index correctly for simple fields", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 0 } },
            }

            local f1 = { name = "a", type = model_info.FieldType.TYPE_INT32, label = model_info.FieldLabel.LABEL_OPTIONAL, oneof_index = nil }
            local f2 = { name = "b", type = model_info.FieldType.TYPE_STRING, label = model_info.FieldLabel.LABEL_OPTIONAL, oneof_index = nil }

            model_info.build_field_info(info, file_info, message_info, f1, 1)
            model_info.build_field_info(info, file_info, message_info, f2, 2)
            model_info.process_fields(info, file_info, message_info)

            assert.are.equal(1, message_info.fields[1].data_index)
            assert.are.equal(2, message_info.fields[2].data_index)
        end)

        it("map fields occupy 2 data indices", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            info.messages["test.Msg.MapEntry"] = {
                full_name = "test.Msg.MapEntry",
                descriptor = {
                    options = { map_entry = true },
                    field = {
                        { name = "key", type = model_info.FieldType.TYPE_STRING },
                        { name = "value", type = model_info.FieldType.TYPE_INT32 },
                    },
                },
            }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 0 } },
            }

            local f1 = { name = "a", type = model_info.FieldType.TYPE_INT32, label = model_info.FieldLabel.LABEL_OPTIONAL, oneof_index = nil }
            local f2 = { name = "m", type = model_info.FieldType.TYPE_MESSAGE, label = model_info.FieldLabel.LABEL_REPEATED, type_name = ".test.Msg.MapEntry", oneof_index = nil }

            model_info.build_field_info(info, file_info, message_info, f1, 1)
            model_info.build_field_info(info, file_info, message_info, f2, 2)
            model_info.process_fields(info, file_info, message_info)

            assert.are.equal(1, message_info.fields[1].data_index)
            assert.are.equal(2, message_info.fields[2].data_index)
        end)

        it("oneof fields share data_index within same oneof", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = { options = { level = 0 } },
            }

            local f1 = { name = "text", type = model_info.FieldType.TYPE_STRING, label = model_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 0 }
            local f2 = { name = "num", type = model_info.FieldType.TYPE_INT32, label = model_info.FieldLabel.LABEL_OPTIONAL, oneof_index = 0 }

            model_info.build_field_info(info, file_info, message_info, f1, 1)
            model_info.build_field_info(info, file_info, message_info, f2, 2)
            model_info.build_oneof_info(info, file_info, message_info, { name = "payload" }, 1)
            model_info.process_fields(info, file_info, message_info)

            assert.are.equal(1, message_info.fields[1].data_index)
            assert.are.equal(1, message_info.fields[2].data_index)
            assert.are.equal(1, message_info.oneofs[1].data_index)
        end)

        it("data_index starts after dirty header when has dirty fields", function()
            local info = { messages = {} }
            local file_info = { name = "test.proto" }
            local message_info = {
                full_name = "test.Msg",
                fields = {},
                oneofs = {},
                descriptor = {
                    options = { level = 1 },
                },
            }
            local field = {
                name = "name",
                type = model_info.FieldType.TYPE_STRING,
                label = model_info.FieldLabel.LABEL_OPTIONAL,
                oneof_index = nil,
            }

            model_info.build_field_info(info, file_info, message_info, field, 1)
            model_info.process_fields(info, file_info, message_info)

            -- dirty_index=1, data_index starts at 4 (3 + 0 extra dirty words)
            assert.are.equal(1, message_info.fields[1].dirty_index)
            assert.are.equal(4, message_info.fields[1].data_index)
        end)
    end)

    describe("build_info", function()
        it("parses a simple descriptor set correctly", function()
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
                                        label = model_info.FieldLabel.LABEL_OPTIONAL,
                                        type = model_info.FieldType.TYPE_INT32,
                                    },
                                    {
                                        name = "name",
                                        number = 2,
                                        label = model_info.FieldLabel.LABEL_OPTIONAL,
                                        type = model_info.FieldType.TYPE_STRING,
                                    },
                                },
                                oneof_decl = {},
                                enum_type = {},
                                nested_type = {},
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

            local info = model_info.build_info(descriptor_set)

            assert.is_not_nil(info)
            assert.are.equal(descriptor_set, info.descriptor_set)

            -- file info
            local file_info = info.files["test.proto"]
            assert.is_not_nil(file_info)
            assert.are.equal("test.proto", file_info.name)
            assert.are.equal("demo", file_info.package_name)

            -- message info
            local msg = info.messages["demo.Person"]
            assert.is_not_nil(msg)
            assert.are.equal("Person", msg.name)
            assert.are.equal("demo.Person", msg.full_name)
            assert.are.equal("demo.Person", msg.full_name_dot)
            assert.are.equal("test.proto", msg.file)
            assert.are.equal(2, #msg.fields)
            assert.are.equal("id", msg.fields[1].name)
            assert.are.equal("name", msg.fields[2].name)

            -- enum info
            local enum = info.enums["demo.Status"]
            assert.is_not_nil(enum)
            assert.are.equal("Status", enum.name)
            assert.are.equal("demo.Status", enum.full_name)
            assert.are.equal(2, #enum.values)
            assert.are.equal("UNKNOWN", enum.values[1].key)
            assert.are.equal(0, enum.values[1].value)
            assert.are.equal("ACTIVE", enum.values[2].key)
            assert.are.equal(1, enum.values[2].value)
        end)

        it("handles nested messages and enums", function()
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
                                        },
                                    },
                                },
                                nested_type = {
                                    {
                                        name = "Inner",
                                        field = {},
                                        oneof_decl = {},
                                        enum_type = {},
                                        nested_type = {},
                                    },
                                },
                            },
                        },
                        enum_type = {},
                    },
                },
            }

            local info = model_info.build_info(descriptor_set)

            assert.is_not_nil(info.messages["demo.Outer"])
            assert.is_not_nil(info.messages["demo.Outer_Inner"])
            assert.is_not_nil(info.enums["demo.Outer_InnerEnum"])
            assert.are.equal("demo.Outer.InnerEnum", info.enums["demo.Outer_InnerEnum"].full_name_dot)
        end)

        it("handles empty package", function()
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

            local info = model_info.build_info(descriptor_set)

            assert.is_not_nil(info.messages["Msg"])
            assert.are.equal("Msg", info.messages["Msg"].full_name)
        end)
    end)
end)

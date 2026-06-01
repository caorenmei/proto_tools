describe("bean_utils.plain", function()
    dofile("lua_tests/support/env.lua")

    local plain = require("bean_utils.plain")

    -- 辅助函数：创建模拟的 self 表
    -- 索引1为 false（无 track 回调），data_index 从 2 开始
    local function make_self()
        return { false }
    end


    describe("set_field", function()
        it("设置新值成功，返回 true", function()
            local self = make_self()
            local result = plain.set_field(self, 2, "hello", plain.assert_string)
            assert.is_true(result)
            assert.equals("hello", self[2])
        end)

        it("设置相同值返回 false", function()
            local self = make_self()
            plain.set_field(self, 2, "hello", plain.assert_string)
            local result = plain.set_field(self, 2, "hello", plain.assert_string)
            assert.is_false(result)
        end)

        it("断言失败时抛出错误", function()
            local self = make_self()
            assert.has_error(function()
                plain.set_field(self, 2, 123, plain.assert_string)
            end, "value must be a string")
        end)
    end)

    describe("get_message", function()
        it("获取已存在的消息", function()
            local self = make_self()
            local existing = { name = "test" }
            self[2] = existing
            local result = plain.get_message(self, 2, function()
                return { name = "new" }
            end)
            assert.equals(existing, result)
            assert.equals("test", result.name)
        end)

        it("创建新消息（调用 constructor）", function()
            local self = make_self()
            local call_count = 0
            local result = plain.get_message(self, 2, function()
                call_count = call_count + 1
                return { name = "new" }
            end)
            assert.equals(1, call_count)
            assert.equals("new", result.name)
            assert.equals(result, self[2])
        end)
    end)

    describe("oneof operations", function()
        describe("set_oneof_field", function()
            it("设置值", function()
                local self = make_self()
                local result = plain.set_oneof_field(self, 2, 1, "hello", plain.assert_string)
                assert.is_true(result)
                assert.equals(1, self[2])
                assert.equals("hello", self[3])
            end)

            it("相同值返回 false", function()
                local self = make_self()
                plain.set_oneof_field(self, 2, 1, "hello", plain.assert_string)
                local result = plain.set_oneof_field(self, 2, 1, "hello", plain.assert_string)
                assert.is_false(result)
            end)

            it("断言失败时抛出错误", function()
                local self = make_self()
                assert.has_error(function()
                    plain.set_oneof_field(self, 2, 1, 123, plain.assert_string)
                end, "value must be a string")
            end)
        end)

        describe("add_oneof_message", function()
            it("获取已存在的", function()
                local self = make_self()
                local existing = { name = "test" }
                self[2] = 1
                self[3] = existing
                local call_count = 0
                local result = plain.add_oneof_message(self, 2, 1, function()
                    call_count = call_count + 1
                    return { name = "new" }
                end)
                assert.equals(0, call_count)
                assert.equals(existing, result)
            end)

            it("创建新的", function()
                local self = make_self()
                local call_count = 0
                local result = plain.add_oneof_message(self, 2, 1, function()
                    call_count = call_count + 1
                    return { name = "new" }
                end)
                assert.equals(1, call_count)
                assert.equals("new", result.name)
                assert.equals(1, self[2])
                assert.equals(result, self[3])
            end)
        end)

        describe("clear_oneof_field", function()
            it("清除", function()
                local self = make_self()
                plain.set_oneof_field(self, 2, 1, "hello", plain.assert_string)
                plain.clear_oneof_field(self, 2)
                assert.equals(0, self[2])
                assert.is_false(self[3])
            end)

            it("已清除时无操作", function()
                local self = make_self()
                -- 默认状态 old_index 为 nil，但 clear_oneof_field 中 old_index == 0 不成立
                -- 所以会设置 self[2] = 0, self[3] = false
                plain.clear_oneof_field(self, 2)
                assert.equals(0, self[2])
                assert.is_false(self[3])
            end)
        end)
    end)

    describe("repeated value operations", function()
        describe("add_repeated_value", function()
            it("添加值", function()
                local self = make_self()
                plain.add_repeated_value(self, 2, "a", plain.assert_string)
                plain.add_repeated_value(self, 2, "b", plain.assert_string)
                assert.same({ "a", "b" }, self[2])
            end)

            it("断言失败时抛出错误", function()
                local self = make_self()
                assert.has_error(function()
                    plain.add_repeated_value(self, 2, 123, plain.assert_string)
                end, "value must be a string")
            end)
        end)

        describe("set_repeated_value", function()
            it("修改值", function()
                local self = make_self()
                plain.add_repeated_value(self, 2, "a", plain.assert_string)
                plain.add_repeated_value(self, 2, "b", plain.assert_string)
                plain.set_repeated_value(self, 2, 1, "x", plain.assert_string)
                assert.same({ "x", "b" }, self[2])
            end)

            it("设置相同值不修改", function()
                local self = make_self()
                plain.add_repeated_value(self, 2, "a", plain.assert_string)
                plain.set_repeated_value(self, 2, 1, "a", plain.assert_string)
                assert.same({ "a" }, self[2])
            end)

            it("越界报错", function()
                local self = make_self()
                plain.add_repeated_value(self, 2, "a", plain.assert_string)
                assert.has_error(function()
                    plain.set_repeated_value(self, 2, 2, "x", plain.assert_string)
                end, "index out of range")
                assert.has_error(function()
                    plain.set_repeated_value(self, 2, 0, "x", plain.assert_string)
                end, "index out of range")
            end)
        end)

        describe("pop_repeated_value", function()
            it("弹出值", function()
                local self = make_self()
                plain.add_repeated_value(self, 2, "a", plain.assert_string)
                plain.add_repeated_value(self, 2, "b", plain.assert_string)
                local value = plain.pop_repeated_value(self, 2)
                assert.equals("b", value)
                assert.same({ "a" }, self[2])
            end)

            it("空列表返回 nil", function()
                local self = make_self()
                local value = plain.pop_repeated_value(self, 2)
                assert.is_nil(value)
            end)
        end)

        describe("clear_repeated_value", function()
            it("清空", function()
                local self = make_self()
                plain.add_repeated_value(self, 2, "a", plain.assert_string)
                plain.add_repeated_value(self, 2, "b", plain.assert_string)
                plain.clear_repeated_value(self, 2)
                assert.same({}, self[2])
            end)

            it("空列表无错误", function()
                local self = make_self()
                plain.clear_repeated_value(self, 2)
                assert.is_nil(self[2])
            end)
        end)
    end)

    describe("repeated message operations", function()
        describe("add_repeated_message", function()
            it("添加消息", function()
                local self = make_self()
                local msg1 = plain.add_repeated_message(self, 2, function()
                    return { name = "msg1" }
                end)
                local msg2 = plain.add_repeated_message(self, 2, function()
                    return { name = "msg2" }
                end)
                assert.equals("msg1", msg1.name)
                assert.equals("msg2", msg2.name)
                assert.same({ msg1, msg2 }, self[2])
            end)
        end)

        describe("pop_repeated_message", function()
            it("弹出消息", function()
                local self = make_self()
                local msg1 = plain.add_repeated_message(self, 2, function()
                    return { name = "msg1" }
                end)
                local msg2 = plain.add_repeated_message(self, 2, function()
                    return { name = "msg2" }
                end)
                local popped = plain.pop_repeated_message(self, 2)
                assert.equals(msg2, popped)
                assert.same({ msg1 }, self[2])
            end)
        end)

        describe("clear_repeated_message", function()
            it("清空", function()
                local self = make_self()
                plain.add_repeated_message(self, 2, function()
                    return { name = "msg1" }
                end)
                plain.add_repeated_message(self, 2, function()
                    return { name = "msg2" }
                end)
                plain.clear_repeated_message(self, 2)
                assert.same({}, self[2])
            end)
        end)
    end)

    describe("map value operations", function()
        describe("set_map_value", function()
            it("设置值", function()
                local self = make_self()
                self[2] = 0  -- 初始化 map 长度
                plain.set_map_value(self, 2, "k1", "v1", function(k, v)
                    plain.assert_string(k)
                    plain.assert_string(v)
                end)
                assert.equals(1, self[2])
                assert.equals("v1", self[3]["k1"])
            end)

            it("更新已有 key 不增加长度", function()
                local self = make_self()
                self[2] = 0
                plain.set_map_value(self, 2, "k1", "v1", function(k, v)
                    plain.assert_string(k)
                    plain.assert_string(v)
                end)
                plain.set_map_value(self, 2, "k1", "v2", function(k, v)
                    plain.assert_string(k)
                    plain.assert_string(v)
                end)
                assert.equals(1, self[2])
                assert.equals("v2", self[3]["k1"])
            end)

            it("多个 key 增加长度", function()
                local self = make_self()
                self[2] = 0
                plain.set_map_value(self, 2, "k1", "v1", function() end)
                plain.set_map_value(self, 2, "k2", "v2", function() end)
                assert.equals(2, self[2])
            end)

            it("更新已有 key 为相同值不修改", function()
                local self = make_self()
                self[2] = 0
                plain.set_map_value(self, 2, "k1", "v1", function() end)
                plain.set_map_value(self, 2, "k1", "v1", function() end)
                assert.equals(1, self[2])
                assert.equals("v1", self[3]["k1"])
            end)
        end)

        describe("remove_map_key", function()
            it("删除 key", function()
                local self = make_self()
                self[2] = 0
                plain.set_map_value(self, 2, "k1", "v1", function() end)
                plain.set_map_value(self, 2, "k2", "v2", function() end)
                local removed = plain.remove_map_key(self, 2, "k1")
                assert.equals("v1", removed)
                assert.equals(1, self[2])
                assert.is_nil(self[3]["k1"])
                assert.equals("v2", self[3]["k2"])
            end)

            it("不存在的 key 返回 nil", function()
                local self = make_self()
                self[2] = 0
                plain.set_map_value(self, 2, "k1", "v1", function() end)
                local removed = plain.remove_map_key(self, 2, "k2")
                assert.is_nil(removed)
                assert.equals(1, self[2])
            end)
        end)

        describe("clear_map", function()
            it("清空", function()
                local self = make_self()
                self[2] = 0
                plain.set_map_value(self, 2, "k1", "v1", function() end)
                plain.set_map_value(self, 2, "k2", "v2", function() end)
                plain.clear_map(self, 2)
                assert.equals(0, self[2])
                assert.is_nil(self[3]["k1"])
                assert.is_nil(self[3]["k2"])
            end)

            it("已空时无错误", function()
                local self = make_self()
                self[2] = 0
                plain.clear_map(self, 2)
                assert.equals(0, self[2])
            end)
        end)
    end)

    describe("map message operations", function()
        describe("add_map_message", function()
            it("添加消息", function()
                local self = make_self()
                self[2] = 0
                local msg = plain.add_map_message(self, 2, "k1", function()
                    return { name = "msg1" }
                end)
                assert.equals("msg1", msg.name)
                assert.equals(1, self[2])
                assert.equals(msg, self[3]["k1"])
            end)

            it("获取已存在的", function()
                local self = make_self()
                self[2] = 0
                local msg1 = plain.add_map_message(self, 2, "k1", function()
                    return { name = "msg1" }
                end)
                local call_count = 0
                local msg2 = plain.add_map_message(self, 2, "k1", function()
                    call_count = call_count + 1
                    return { name = "msg2" }
                end)
                assert.equals(0, call_count)
                assert.equals(msg1, msg2)
                assert.equals(1, self[2])
            end)
        end)

        describe("remove_map_message", function()
            it("删除", function()
                local self = make_self()
                self[2] = 0
                local msg = plain.add_map_message(self, 2, "k1", function()
                    return { name = "msg1" }
                end)
                local removed = plain.remove_map_message(self, 2, "k1")
                assert.equals(msg, removed)
                assert.equals(0, self[2])
                assert.is_nil(self[3]["k1"])
            end)
        end)

        describe("clear_map_message", function()
            it("清空", function()
                local self = make_self()
                self[2] = 0
                plain.add_map_message(self, 2, "k1", function()
                    return { name = "msg1" }
                end)
                plain.add_map_message(self, 2, "k2", function()
                    return { name = "msg2" }
                end)
                plain.clear_map_message(self, 2)
                assert.equals(0, self[2])
                assert.is_nil(self[3]["k1"])
                assert.is_nil(self[3]["k2"])
            end)
        end)
    end)
end)

describe("bean_utils.track", function()
    local track

    setup(function()
        dofile("lua_tests/support/env.lua")
        track = require("bean_utils.track")
    end)

    describe("assertions", function()
        it("assert_int32 accepts valid int32 values", function()
            assert.has_no.errors(function()
                track.assert_int32(0)
                track.assert_int32(-0x80000000)
                track.assert_int32(0x7FFFFFFF)
            end)
        end)

        it("assert_int32 rejects invalid values", function()
            assert.has_error(function()
                track.assert_int32(0x80000000)
            end)
            assert.has_error(function()
                track.assert_int32(-0x80000001)
            end)
            assert.has_error(function()
                track.assert_int32("hello")
            end)
        end)

        it("assert_uint32 accepts valid uint32 values", function()
            assert.has_no.errors(function()
                track.assert_uint32(0)
                track.assert_uint32(0xFFFFFFFF)
            end)
        end)

        it("assert_uint32 rejects invalid values", function()
            assert.has_error(function()
                track.assert_uint32(-1)
            end)
            assert.has_error(function()
                track.assert_uint32(0x100000000)
            end)
        end)

        it("assert_string accepts strings", function()
            assert.has_no.errors(function()
                track.assert_string("hello")
            end)
            assert.has_error(function()
                track.assert_string(123)
            end)
        end)

        it("assert_boolean accepts booleans", function()
            assert.has_no.errors(function()
                track.assert_boolean(true)
                track.assert_boolean(false)
            end)
            assert.has_error(function()
                track.assert_boolean(1)
            end)
        end)

        it("assert_float accepts numbers", function()
            assert.has_no.errors(function()
                track.assert_float(3.14)
                track.assert_float(42)
            end)
            assert.has_error(function()
                track.assert_float("hello")
            end)
        end)
    end)

    describe("set_field", function()
        it("sets new value and marks track bit", function()
            local self = { false, 0, 0 }
            local result = track.set_field(self, 1, 1, 3, 42, track.assert_int32)
            assert.is_true(result)
            assert.are.equal(42, self[3])
            -- track bit should be set: track_index=1 -> word_index=2, bit 0
            assert.are.equal(1, self[2])
        end)

        it("returns false when setting same value without modifying track bit", function()
            local self = { false, 0, 42 }
            local result = track.set_field(self, 1, 1, 3, 42, track.assert_int32)
            assert.is_false(result)
            assert.are.equal(0, self[2])
        end)

        it("calls callback when first dirty bit is set", function()
            local calls = {}
            local callback = function(v)
                table.insert(calls, v)
            end
            local self = { callback, 0, 0 }
            track.set_field(self, 1, 1, 3, 42, track.assert_int32)
            assert.are.same({ true }, calls)
        end)

        it("does not call callback for second dirty bit if first is already set", function()
            local calls = {}
            local callback = function(v)
                table.insert(calls, v)
            end
            local self = { callback, 0, 0, 0 }
            track.set_field(self, 1, 1, 3, 42, track.assert_int32)
            assert.are.same({ true }, calls)
            track.set_field(self, 1, 2, 4, 100, track.assert_int32)
            -- callback should not be called again since bean was already tracked
            assert.are.same({ true }, calls)
        end)
    end)

    describe("get_message", function()
        it("returns existing message", function()
            local existing = { false }
            local self = { false, 0, existing }
            local result = track.get_message(self, 1, 1, 3, function()
                return { false }
            end)
            assert.are.equal(existing, result)
        end)

        it("creates new message with track callback", function()
            local self = { false, 0, nil }
            local msg = track.get_message(self, 1, 1, 3, function()
                return { false }
            end)
            assert.is_not_nil(msg)
            assert.is_function(msg[1])
            -- track bit should be set
            assert.are.equal(1, self[2])
        end)

        it("child message notifies parent when modified", function()
            local parent_calls = {}
            local parent_callback = function(v)
                table.insert(parent_calls, v)
            end
            local self = { parent_callback, 0, nil }
            local msg = track.get_message(self, 1, 1, 3, function()
                return { false }
            end)
            -- get_message already sets the track bit and calls parent_callback(true)
            assert.are.same({ true }, parent_calls)
            -- clear and simulate child clearing its own track bit
            parent_calls = {}
            msg[1](false)
            assert.are.same({ false }, parent_calls)
        end)
    end)

    describe("track bit operations", function()
        it("sets correct bit for track_index within first word", function()
            local self = { false, 0, 0 }
            track.set_field(self, 1, 64, 3, 42, track.assert_int32)
            -- track_index=64 -> word_index=2, bit_index=63
            assert.are.equal(1 << 63, self[2])
        end)

        it("sets correct bit for track_index crossing to second word", function()
            local self = { false, 0, 0, 0 }
            track.set_field(self, 2, 65, 4, 42, track.assert_int32)
            -- track_index=65 -> word_index=3, bit_index=0
            assert.are.equal(1, self[3])
            assert.are.equal(0, self[2])
        end)

        it("sets correct bit for track_index=128 in second word", function()
            local self = { false, 0, 0, 0 }
            track.set_field(self, 2, 128, 4, 42, track.assert_int32)
            -- track_index=128 -> word_index=3, bit_index=63
            assert.are.equal(1 << 63, self[3])
        end)

        it("callback called with false when last dirty bit is cleared", function()
            local calls = {}
            local callback = function(v)
                table.insert(calls, v)
            end
            local self = { callback, 0, 0 }
            track.set_field(self, 1, 1, 3, 42, track.assert_int32)
            assert.are.same({ true }, calls)
            -- Manually clear the bit using internal mechanism via set_field not possible
            -- We test via the set_track_bit indirectly through track_map_update
            -- Instead, directly test by setting then clearing via map operations
            local track_maps = {}
            local map_self = { callback, 0, 0, {} }
            track.set_map_value(map_self, 1, 1, 3, track_maps, "key1", 100, function(k, v)
                assert.is_string(k)
                assert.is_number(v)
            end)
            calls = {}
            track.remove_map_key(map_self, 1, 1, 3, track_maps, "key1")
            assert.are.same({ false }, calls)
        end)
    end)

    describe("oneof operations", function()
        it("set_oneof_field sets value and marks track", function()
            local self = { false, 0, 0, false }
            local track_maps = {}
            -- use even oneof_index (2) for non-message string value
            track.set_oneof_field(self, 1, 1, 3, track_maps, 2, "hello", track.assert_string)
            assert.are.equal(2, self[3])
            assert.are.equal("hello", self[4])
            assert.are.equal(1, self[2])
        end)

        it("set_oneof_field changing oneof index updates track_maps", function()
            local self = { false, 0, 0, false }
            local track_maps = {}
            -- use even oneof_index (2) for non-message string value
            track.set_oneof_field(self, 1, 1, 3, track_maps, 2, "hello", track.assert_string)
            -- change to another even oneof_index (4) for int32 value
            track.set_oneof_field(self, 1, 1, 3, track_maps, 4, 42, track.assert_int32)
            -- track_map_remove_add: state was Added (1), which is not handled,
            -- so state remains Added (1)
            assert.are.equal(1, track_maps[self][1])
            assert.are.equal(4, self[3])
            assert.are.equal(42, self[4])
        end)

        it("set_oneof_field with same index and value returns false", function()
            local self = { false, 0, 0, false }
            local track_maps = {}
            track.set_oneof_field(self, 1, 1, 3, track_maps, 2, "hello", track.assert_string)
            local result = track.set_oneof_field(self, 1, 1, 3, track_maps, 2, "hello", track.assert_string)
            assert.is_false(result)
        end)

        it("add_oneof_message creates message and sets track", function()
            local self = { false, 0, 0, false }
            local track_maps = {}
            local msg = track.add_oneof_message(self, 1, 1, 3, track_maps, 1, function()
                return { false }
            end)
            assert.is_not_nil(msg)
            assert.is_function(msg[1])
            assert.are.equal(1, self[3])
            assert.are.equal(msg, self[4])
            assert.are.equal(1, self[2])
        end)

        it("clear_oneof_field clears value and marks track", function()
            local self = { false, 0, 0, false }
            local track_maps = {}
            -- use odd oneof_index (1) for message type
            local msg = track.add_oneof_message(self, 1, 1, 3, track_maps, 1, function()
                return { false }
            end)
            -- pre-set state to Updated so clear produces Removed instead of nil
            track_maps[self][1] = 2
            track.clear_oneof_field(self, 1, 1, 3, track_maps)
            assert.are.equal(0, self[3])
            assert.is_false(self[4])
            -- track_maps should have Removed (3) state
            assert.are.equal(3, track_maps[self][1])
        end)

        it("clear_oneof_field on already cleared oneof does nothing", function()
            local self = { false, 0, 0, false }
            local track_maps = {}
            track.clear_oneof_field(self, 1, 1, 3, track_maps)
            assert.are.equal(0, self[3])
            assert.is_false(self[4])
        end)

        it("set_oneof_field clears old message track when replacing with message", function()
            local self = { false, 0, 0, false }
            local track_maps = {}
            -- use odd oneof_index (1) for message type
            local msg = track.add_oneof_message(self, 1, 1, 3, track_maps, 1, function()
                return { false }
            end)
            assert.is_function(msg[1])
            -- Replace with a non-message value (even index)
            track.set_oneof_field(self, 1, 1, 3, track_maps, 2, "string_value", track.assert_string)
            -- Old message's track callback should be disabled
            assert.is_false(msg[1])
        end)
    end)

    describe("repeated value operations", function()
        it("add_repeated_value adds value and marks Added in track_maps", function()
            local self = { false, 0, nil }
            local track_maps = {}
            track.add_repeated_value(self, 1, 1, 3, track_maps, 10, track.assert_int32)
            local list = self[3]
            assert.is_not_nil(list)
            assert.are.equal(1, #list)
            assert.are.equal(10, list[1])
            -- track_maps[list][1] should be Added (1)
            assert.are.equal(1, track_maps[list][1])
            assert.are.equal(1, self[2])
        end)

        it("set_repeated_value updates value and marks Updated", function()
            local self = { false, 0, { 10, 20, 30 } }
            local track_maps = {}
            track.set_repeated_value(self, 1, 1, 3, track_maps, 2, 99, track.assert_int32)
            assert.are.equal(99, self[3][2])
            assert.are.equal(2, track_maps[self[3]][2])
        end)

        it("pop_repeated_value removes last value and marks Removed", function()
            local self = { false, 0, { 10, 20, 30 } }
            local track_maps = {}
            -- pre-populate track_maps with Added states for first two, Updated for last
            track_maps[self[3]] = { [1] = 1, [2] = 1, [3] = 2 }
            local value = track.pop_repeated_value(self, 1, 1, 3, track_maps)
            assert.are.equal(30, value)
            assert.are.equal(2, #self[3])
            -- index 3 was Updated (2), remove -> Removed (3)
            assert.are.equal(3, track_maps[self[3]][3])
        end)

        it("pop_repeated_value on empty list returns nil", function()
            local self = { false, 0, nil }
            local track_maps = {}
            local value = track.pop_repeated_value(self, 1, 1, 3, track_maps)
            assert.is_nil(value)
        end)

        it("clear_repeated_value clears all and marks Removed", function()
            local self = { false, 0, { 10, 20, 30 } }
            local track_maps = {}
            track.clear_repeated_value(self, 1, 1, 3, track_maps)
            assert.are.equal(0, #self[3])
            local list = self[3]
            -- All should be Removed (3)
            assert.are.equal(3, track_maps[list][1])
            assert.are.equal(3, track_maps[list][2])
            assert.are.equal(3, track_maps[list][3])
        end)

        it("clear_repeated_value on nil list does nothing", function()
            local self = { false, 0, nil }
            local track_maps = {}
            track.clear_repeated_value(self, 1, 1, 3, track_maps)
            assert.is_nil(self[3])
        end)
    end)

    describe("repeated message operations", function()
        it("add_repeated_message adds message with track callback", function()
            local self = { false, 0, nil }
            local track_maps = {}
            local msg = track.add_repeated_message(self, 1, 1, 3, track_maps, function()
                return { false }
            end)
            assert.is_not_nil(msg)
            assert.is_function(msg[1])
            local list = self[3]
            assert.are.equal(1, #list)
            assert.are.equal(msg, list[1])
            assert.are.equal(1, track_maps[list][1])
        end)

        it("pop_repeated_message removes message and disables its track", function()
            local self = { false, 0, nil }
            local track_maps = {}
            local msg = track.add_repeated_message(self, 1, 1, 3, track_maps, function()
                return { false }
            end)
            assert.is_function(msg[1])
            local popped = track.pop_repeated_message(self, 1, 1, 3, track_maps)
            assert.are.equal(msg, popped)
            assert.is_false(msg[1])
        end)

        it("clear_repeated_message clears all and disables track for all messages", function()
            local self = { false, 0, nil }
            local track_maps = {}
            local msg1 = track.add_repeated_message(self, 1, 1, 3, track_maps, function()
                return { false }
            end)
            local msg2 = track.add_repeated_message(self, 1, 1, 3, track_maps, function()
                return { false }
            end)
            assert.is_function(msg1[1])
            assert.is_function(msg2[1])
            track.clear_repeated_message(self, 1, 1, 3, track_maps)
            assert.is_false(msg1[1])
            assert.is_false(msg2[1])
            assert.are.equal(0, #self[3])
        end)
    end)

    describe("map value operations", function()
        it("set_map_value adds new key and marks Added", function()
            local self = { false, 0, 0, nil }
            local track_maps = {}
            track.set_map_value(self, 1, 1, 3, track_maps, "key1", 100, function(k, v)
                assert.is_string(k)
                assert.is_number(v)
            end)
            assert.are.equal(1, self[3])
            local map = self[4]
            assert.are.equal(100, map["key1"])
            assert.are.equal(1, track_maps[map]["key1"])
            assert.are.equal(1, self[2])
        end)

        it("set_map_value updates existing key keeps Added state", function()
            local self = { false, 0, 0, nil }
            local track_maps = {}
            track.set_map_value(self, 1, 1, 3, track_maps, "key1", 100, function(k, v)
                assert.is_string(k)
                assert.is_number(v)
            end)
            track.set_map_value(self, 1, 1, 3, track_maps, "key1", 200, function(k, v)
                assert.is_string(k)
                assert.is_number(v)
            end)
            local map = self[4]
            assert.are.equal(200, map["key1"])
            -- key was Added (1), updating an Added key keeps it as Added (1)
            -- track_map_update only sets Updated when state is nil
            assert.are.equal(1, track_maps[map]["key1"])
        end)

        it("remove_map_key removes key and marks Removed", function()
            local self = { false, 0, 0, nil }
            local track_maps = {}
            track.set_map_value(self, 1, 1, 3, track_maps, "key1", 100, function(k, v)
                assert.is_string(k)
                assert.is_number(v)
            end)
            -- add a second key so track_maps[map] is not cleared when removing key1
            track.set_map_value(self, 1, 1, 3, track_maps, "key2", 200, function(k, v)
                assert.is_string(k)
                assert.is_number(v)
            end)
            local value = track.remove_map_key(self, 1, 1, 3, track_maps, "key1")
            assert.are.equal(100, value)
            assert.are.equal(1, self[3])
            local map = self[4]
            assert.is_nil(map["key1"])
            -- key1 was Added (1), remove -> nil (cleared) since Added+remove clears
            -- but since key2 exists, track_maps[map] still exists
            assert.is_nil(track_maps[map]["key1"])
        end)

        it("remove_map_key on non-existent key returns nil", function()
            local self = { false, 0, 0, nil }
            local track_maps = {}
            local value = track.remove_map_key(self, 1, 1, 3, track_maps, "key1")
            assert.is_nil(value)
        end)

        it("clear_map clears all keys and marks Removed", function()
            local self = { false, 0, 0, nil }
            local track_maps = {}
            -- set key1 as Added, key2 as pre-existing (will be Removed on clear)
            track.set_map_value(self, 1, 1, 3, track_maps, "key1", 100, function(k, v)
                assert.is_string(k)
                assert.is_number(v)
            end)
            -- manually set key2's state to Updated to test clear_map behavior
            local map = self[4]
            track_maps[map]["key2"] = 2
            map["key2"] = 200
            self[3] = 2
            track.clear_map(self, 1, 1, 3, track_maps)
            assert.are.equal(0, self[3])
            assert.is_nil(map["key1"])
            assert.is_nil(map["key2"])
            -- key1 was Added -> cleared; key2 was Updated -> Removed
            assert.is_nil(track_maps[map]["key1"])
            assert.are.equal(3, track_maps[map]["key2"])
        end)

        it("clear_map on empty map does nothing", function()
            local self = { false, 0, 0, nil }
            local track_maps = {}
            track.clear_map(self, 1, 1, 3, track_maps)
            assert.are.equal(0, self[3])
            assert.is_nil(self[4])
        end)
    end)

    describe("map message operations", function()
        it("add_map_message adds message with track callback", function()
            local self = { false, 0, 0, nil }
            local track_maps = {}
            local msg = track.add_map_message(self, 1, 1, 3, track_maps, "key1", function()
                return { false }
            end)
            assert.is_not_nil(msg)
            assert.is_function(msg[1])
            assert.are.equal(1, self[3])
            local map = self[4]
            assert.are.equal(msg, map["key1"])
            assert.are.equal(1, track_maps[map]["key1"])
        end)

        it("add_map_message returns existing message", function()
            local self = { false, 0, 0, nil }
            local track_maps = {}
            local msg1 = track.add_map_message(self, 1, 1, 3, track_maps, "key1", function()
                return { false }
            end)
            local msg2 = track.add_map_message(self, 1, 1, 3, track_maps, "key1", function()
                return { false }
            end)
            assert.are.equal(msg1, msg2)
        end)

        it("remove_map_message removes message and disables track", function()
            local self = { false, 0, 0, nil }
            local track_maps = {}
            local msg = track.add_map_message(self, 1, 1, 3, track_maps, "key1", function()
                return { false }
            end)
            assert.is_function(msg[1])
            -- add another key so track_maps[map] is not cleared
            track.add_map_message(self, 1, 1, 3, track_maps, "key2", function()
                return { false }
            end)
            local removed = track.remove_map_message(self, 1, 1, 3, track_maps, "key1")
            assert.are.equal(msg, removed)
            assert.is_false(msg[1])
            local map = self[4]
            assert.is_nil(map["key1"])
            -- key1 was Added, remove -> nil (cleared) but track_maps[map] still exists due to key2
            assert.is_nil(track_maps[map]["key1"])
        end)

        it("clear_map_message clears all and disables track for all messages", function()
            local self = { false, 0, 0, nil }
            local track_maps = {}
            local msg1 = track.add_map_message(self, 1, 1, 3, track_maps, "key1", function()
                return { false }
            end)
            local msg2 = track.add_map_message(self, 1, 1, 3, track_maps, "key2", function()
                return { false }
            end)
            assert.is_function(msg1[1])
            assert.is_function(msg2[1])
            track.clear_map_message(self, 1, 1, 3, track_maps)
            assert.is_false(msg1[1])
            assert.is_false(msg2[1])
            assert.are.equal(0, self[3])
        end)
    end)

    describe("track_maps state transitions", function()
        it("Added -> Removed -> nil (cleared)", function()
            local self = { false, 0, nil }
            local track_maps = {}
            track.add_repeated_value(self, 1, 1, 3, track_maps, 10, track.assert_int32)
            local list = self[3]
            assert.are.equal(1, track_maps[list][1])
            track.pop_repeated_value(self, 1, 1, 3, track_maps)
            -- Added then Removed -> track_maps[list] is cleared entirely
            assert.is_nil(track_maps[list])
        end)

        it("Updated -> set -> stays Updated", function()
            local self = { false, 0, { 10 } }
            local track_maps = {}
            -- simulate pre-existing state: mark as Updated first
            track_maps[self[3]] = { [1] = 2 }
            track.set_repeated_value(self, 1, 1, 3, track_maps, 1, 20, track.assert_int32)
            -- Updated then set again: track_map_update with state=Updated and has_bit=true
            -- does nothing, so state stays Updated (2)
            assert.are.equal(2, track_maps[self[3]][1])
        end)

        it("Updated -> clear -> Removed", function()
            local self = { false, 0, { 10, 20 } }
            local track_maps = {}
            -- manually set state to Updated for index 1
            track_maps[self[3]] = { [1] = 2, [2] = 1 }
            track.clear_repeated_value(self, 1, 1, 3, track_maps)
            -- Updated then clear -> Removed (3)
            assert.are.equal(3, track_maps[self[3]][1])
        end)
    end)
end)

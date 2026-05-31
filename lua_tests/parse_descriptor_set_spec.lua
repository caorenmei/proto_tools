describe("parse_descriptor_set", function()
    local parse_descriptor_set
    local fixture_dir

    setup(function()
        -- 加载测试环境（设置搜索路径并预加载 protobuf 类型定义）
        dofile("lua_tests/support/env.lua")

        parse_descriptor_set = require("gen_bean.parse_descriptor_set")
        fixture_dir = "lua_tests/fixtures/protoc/"
    end)

    it("should be require-able and export a parse function", function()
        assert.is_not_nil(parse_descriptor_set)
        assert.is_function(parse_descriptor_set.parse)
    end)

    it("should parse a valid descriptor set file", function()
        local ds = parse_descriptor_set.parse(fixture_dir .. "imports/shared.pb")
        assert.is_table(ds)
        assert.is_table(ds.file)
        assert.are.equal(1, #ds.file)
        assert.are.equal("imports/shared.proto", ds.file[1].name)
        assert.are.equal("demo.shared", ds.file[1].package)
    end)

    it("should parse a descriptor set with messages and services", function()
        local ds = parse_descriptor_set.parse(fixture_dir .. "full_feature.pb")
        assert.is_table(ds)
        assert.is_table(ds.file)
        assert.are.equal(1, #ds.file)

        local file = ds.file[1]
        assert.are.equal("demo.full", file.package)
        assert.is_table(file.message_type)
        assert.is_true(#file.message_type >= 2)
        assert.is_table(file.service)
        assert.are.equal(1, #file.service)
    end)

    it("should error when file does not exist", function()
        local ok, err = pcall(function()
            parse_descriptor_set.parse(fixture_dir .. "nonexistent.pb")
        end)
        assert.is_false(ok)
        assert.is_not_nil(err)
    end)
end)

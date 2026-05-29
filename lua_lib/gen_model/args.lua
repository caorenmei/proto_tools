local argparse = require("argparse")

local function new_parser()
    local parser = argparse("gen_model", "Generate model code from database schema.")
    parser:option("-d --out_put_dir", "Output directory for generated code.")
        :target("out_put_dir")
        :argname("<out_put_dir>")
        :default(".")
    parser:option("-f --descriptor_set_file", "Path to the descriptor set file.")
        :target("descriptor_set_file")
        :argname("<descriptor_set_file>")
    return parser
end

local M = {}

--- @param argv string[]
function M.parse(argv)
    local parser = new_parser()
    local ok, parsed_or_err = parser:parse(argv)
    if not ok then
        error(parsed_or_err)
    end
    if not parsed_or_err.descriptor_set_file then
        error("Descriptor set file is required.")
    end
    return parsed_or_err
end

return M
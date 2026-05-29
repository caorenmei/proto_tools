--- lua-protobuf 库的 EmmyLua 类型定义
--- 参考: https://github.com/starwing/lua-protobuf
---@meta

-- ============================================================================
-- Core Types
-- ============================================================================

--- 内存数据库对象（userdata）
---@class pb.State
local State = {}

--- Slice 对象，用于读取二进制 wireformat 数据
---@class pb.Slice
local Slice = {}

--- Buffer 对象，用于写入二进制 wireformat 数据
---@class pb.Buffer
local Buffer = {}

-- ============================================================================
-- pb 主模块
-- ============================================================================

---@class pb
---@field Slice pb.Slice
---@field Buffer pb.Buffer
---@field State pb.State
local pb = {}

--- 清除所有类型
function pb.clear() end

--- 清除特定类型
---@param type_name string
function pb.clear(type_name) end

--- 将二进制 schema 信息载入内存数据库
---@param data string
---@return boolean success, integer bytes_read
function pb.load(data) end

--- 将 table 按照 type 消息类型进行编码
---@overload fun(type_name: string, data: table): string
---@overload fun(type_name: string, data: table, b: pb.Buffer): pb.Buffer
function pb.encode(type_name, data, b) end

--- 将二进制 data 按照 type 消息类型解码为表
---@overload fun(type_name: string, data: string|pb.Slice|pb.Buffer): table
---@overload fun(type_name: string, data: string|pb.Slice|pb.Buffer, target: table): table
function pb.decode(type_name, data, target) end

--- 编码展开后的消息（后续参数按 field number 顺序提供）
---@param type_name string
---@vararg any
---@return string
function pb.pack(type_name, ...) end

--- 解码展开后的消息
---@param data string|pb.Slice
---@param fmt string
---@vararg any
---@return any ...
function pb.unpack(data, fmt, ...) end

--- 遍历内存数据库里所有的消息类型
---@return fun(): string, string, "map"|"enum"|"message"
function pb.types() end

--- 返回内存数据库特定消息类型的具体信息
---@param type_name string
---@return string name, string basename, "map"|"enum"|"message" type_kind
function pb.type(type_name) end

--- 遍历特定消息里所有的域
---@param type_name string
---@return fun(): string, number, string, any, "packed"|"repeated"|"optional", string?, number?
function pb.fields(type_name) end

--- 返回特定消息里特定域的具体信息
---@overload fun(type_name: string, field_name: string): string, number, string, any, "packed"|"repeated"|"optional", string?, number?
---@overload fun(type_name: string, field_number: number): string, number, string, any, "packed"|"repeated"|"optional", string?, number?
function pb.field(type_name, field) end

--- 得到 protobuf 数据类型名对应的 pack/unpack 的格式字符串
---@param type_name string
---@return string
function pb.typefmt(type_name) end

--- 提供特定枚举里的名字，返回枚举数字；或提供数字，返回枚举名字
---@overload fun(type_name: string, name: string): number
---@overload fun(type_name: string, number: number): string
function pb.enum(type_name, value) end

--- 获得或设置特定消息类型的默认表
---@overload fun(type_name: string): table
---@overload fun(type_name: string, defaults: table|nil): table
function pb.defaults(type_name, defaults) end

--- 获得或设置特定消息类型的解码钩子
---@overload fun(type_name: string): function?
---@overload fun(type_name: string, hook: function?): function?
function pb.hook(type_name, hook) end

--- 获得或设置特定消息类型的编码钩子
---@overload fun(type_name: string): function?
---@overload fun(type_name: string, hook: function?): function?
function pb.encode_hook(type_name, hook) end

--- 设置编码或解码的具体选项，返回之前的选项值
---@param option string
---@return string
function pb.option(option) end

--- 返回当前的内存数据库；或设置/删除当前内存数据库，返回旧的
---@overload fun(): pb.State
---@overload fun(newstate: pb.State|nil): pb.State
function pb.state(newstate) end

--- 将 string（通常是二进制数据）编码成16进制串用于显示
---@param data string
---@return string
function pb.tohex(data) end

-- ============================================================================
-- pb.slice 子模块
-- ============================================================================

---@class pb.slice
local slice = {}

--- 创建一个新的 slice 对象
---@overload fun(data: string): pb.Slice
---@overload fun(data: string, i: number): pb.Slice
---@overload fun(data: string, i: number, j: number): pb.Slice
function slice.new(data, i, j) end

--- 重置并释放 slice 对象引用的内存
function Slice:delete() end

--- 得到当前视图的二进制数据
---@overload fun(self: pb.Slice): string
---@overload fun(self: pb.Slice, i: number): string
---@overload fun(self: pb.Slice, i: number, j: number): string
function Slice:result(i, j) end

--- 将 slice 对象重置绑定另一个数据源
---@overload fun(self: pb.Slice): pb.Slice
---@overload fun(self: pb.Slice, data: string): pb.Slice
---@overload fun(self: pb.Slice, data: string, i: number): pb.Slice
---@overload fun(self: pb.Slice, data: string, i: number, j: number): pb.Slice
function Slice:reset(data, i, j) end

--- 返回当前视图栈的深度；或返回第 n 层视图栈的信息
---@overload fun(self: pb.Slice): number
---@overload fun(self: pb.Slice, n: number): number, number, number
function Slice:level(n) end

--- 读取一个带长度数据，并将其视图推入视图栈；或直接推入 [i,j] 范围
---@overload fun(self: pb.Slice): pb.Slice
---@overload fun(self: pb.Slice, i: number, j?: number): pb.Slice
function Slice:enter(i, j) end

--- 离开 n 层的视图栈（默认离开一层），返回当前视图栈深度
---@overload fun(self: pb.Slice): pb.Slice, number
---@overload fun(self: pb.Slice, n: number): pb.Slice, number
function Slice:leave(n) end

--- 利用 fmt 和额外参数，读取当前视图内的信息
---@param self pb.Slice
---@param fmt string
---@vararg any
---@return any ...
function Slice:unpack(fmt, ...) end

-- ============================================================================
-- pb.buffer 子模块
-- ============================================================================

---@class pb.buffer
local buffer = {}

--- 创建一个新的 buffer 对象，额外参数会传递给 b:reset(...)
---@vararg any
---@return pb.Buffer
function buffer.new(...) end

--- 释放 buffer 使用的内存
function Buffer:delete() end

--- 清空 buffer 中的所有数据；或清空并设置为所有参数
---@overload fun(self: pb.Buffer): pb.Buffer
---@overload fun(self: pb.Buffer, ...: any): pb.Buffer
function Buffer:reset(...) end

--- 返回可选范围（默认是全部）的数据的16进制表示
---@overload fun(self: pb.Buffer): string
---@overload fun(self: pb.Buffer, i: number): string
---@overload fun(self: pb.Buffer, i: number, j: number): string
function Buffer:tohex(i, j) end

--- 返回编码后二进制数据。允许只返回一部分。默认返回全部
---@overload fun(self: pb.Buffer): string
---@overload fun(self: pb.Buffer, i: number): string
---@overload fun(self: pb.Buffer, i: number, j: number): string
function Buffer:result(i, j) end

--- 利用 fmt 和额外参数，将参数里提供的数据编码到 buffer 中
---@param self pb.Buffer
---@param fmt string
---@vararg any
---@return pb.Buffer
function Buffer:pack(fmt, ...) end

-- ============================================================================
-- pb.conv 子模块
-- ============================================================================

---@class pb.conv
local conv = {}

---@param value number
---@return string
function conv.encode_int32(value) end

---@param data string
---@return number
function conv.decode_int32(data) end

---@param value number
---@return string
function conv.encode_uint32(value) end

---@param data string
---@return number
function conv.decode_uint32(data) end

---@param value number
---@return string
function conv.encode_sint32(value) end

---@param data string
---@return number
function conv.decode_sint32(data) end

---@param value number
---@return string
function conv.encode_sint64(value) end

---@param data string
---@return number
function conv.decode_sint64(data) end

---@param value number
---@return string
function conv.encode_float(value) end

---@param data string
---@return number
function conv.decode_float(data) end

---@param value number
---@return string
function conv.encode_double(value) end

---@param data string
---@return number
function conv.decode_double(data) end

-- ============================================================================
-- pb.io 子模块
-- ============================================================================

---@class pb.io
local io_module = {}

--- 从 stdin 或文件中读取所有二进制数据
---@overload fun(): string
---@overload fun(filename: string): string
function io_module.read(filename) end

--- 将二进制数据写入 stdout
---@vararg string|number
---@return true
function io_module.write(...) end

--- 将二进制数据写入文件
---@param filename string
---@vararg string|number
---@return true
function io_module.dump(filename, ...) end

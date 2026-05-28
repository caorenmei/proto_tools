# protoc.md

使用 lua-protobuf 库开发 一个工具来生成 protobuf 描述文件，功能类似官方的 `protoc` 工具。

## 工作流

- 使用 `superpowers` 管理开发流程。

## 实现方案

- 使用 `argparse` 库来解析命令行参数，支持选项 `--proto_path` 和 `--descriptor_set_out`。
- 使用 `lua-protobuf` 库的 `protoc.lua` 模块来生成 protobuf 编译和输出描述文件。

## 运行时说明

- 路径解析依赖外部 `realpath` 命令，运行时需确保其在 `PATH` 中。

## 测试方案

- 生成一个和多个包含所有 protobuf 特性的测试 proto 文件。
- 使用 `lua-protobuf` 库的的 pb 模块来加载生成的描述文件，验证其正确性。
- 使用 `lua-protobuf` 库的的 pb 模块来序列化和反序列化数据，确保生成的描述文件能够正确处理数据。

## 参考文献

- `docs/books/lua-protobuf.md`

## 入口文件

tools/protoc_cli.lua
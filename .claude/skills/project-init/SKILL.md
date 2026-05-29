---
name: project-init
description: >
  初始化 Lua 项目的开发环境（LuaRocks + 本地依赖树 + 便利脚本）。
  当用户提到"初始化 Lua 项目"、"设置 Lua 环境"、"安装 LuaRocks 依赖"、
  "配置 luarocks"、"生成 lua/luarocks 脚本"、"项目跑不起来"、"依赖没装"、
  "setup lua project"、"install lua dependencies"、"configure luarocks" 时触发。
  适用于任何使用 LuaRocks 管理依赖的 Lua 项目。
compatibility: []
---

# Lua 项目初始化

本 skill 帮助用户快速完成 Lua 项目的开发环境初始化，包括检测 Lua 版本、
配置 LuaRocks 本地依赖树、安装 rockspec 依赖、生成 `./lua` 和 `./luarocks`
便利脚本，以及验证环境是否可用。

## 为什么需要这个流程

手动初始化 Lua 项目容易遗漏步骤（如忘记生成便利脚本、path 配置错误），
且不同系统的 Lua 安装位置不一致。本 skill 自动化检测和配置，确保环境一致性。

## 初始化流程

执行以下步骤，**每一步完成后确认成功再继续下一步**：

### 1. 检测 Lua 版本

按优先级检测系统上可用的 Lua 解释器：

**Unix 平台**（Linux/macOS）：
```bash
# 按顺序检查，使用第一个找到的版本
which lua5.4 && lua5.4 -v
which lua54 && lua54 -v
which lua5.3 && lua5.3 -v
which lua53 && lua53 -v
which lua && lua -v
```

**Windows 平台**：
```cmd
where lua5.4
where lua54
where lua5.3
where lua53
where lua
lua -v
```

- **优先级**：`lua5.4` > `lua54` > `lua5.3` > `lua53` > `lua`
- 如果 `lua` 命令存在但需要确定其版本，运行 `lua -v` 查看
- 如果以上都未找到，停止并向用户报告：
  > 未检测到 Lua 5.4 或 5.3。请安装 Lua：
  > - Ubuntu/Debian: `sudo apt install lua5.4 luarocks`
  > - macOS: `brew install lua luarocks`
  > - Windows:
  >   - 使用 Lua for Windows: https://github.com/rjpcomputing/luaforwindows
  >   - 或使用 winget: `winget install Lua`（如可用）
  >   - 或使用 MSYS2: `pacman -S mingw-w64-x86_64-lua`
  > - 其他系统请参考 https://www.lua.org/download.html

### 2. 检测 rockspec

查找项目中的 rockspec 文件：

```bash
ls *.rockspec 2>/dev/null
```

- 如果找到，记录文件名
- 如果未找到：
  - 询问用户是否要创建一个基础 rockspec
  - 如果用户同意，基于项目名称创建最小 rockspec：
    ```lua
    package = "<project-name>"
    version = "dev-1"
    source = { url = "*** add source URL ***" }
    description = { summary = "...", homepage = "...", license = "..." }
    dependencies = { "lua >= 5.4" }
    build = { type = "builtin", modules = {} }
    ```

### 3. 初始化 LuaRocks（本地模式）

使用检测到的 Lua 版本初始化 LuaRocks 本地依赖树：

```bash
# 方案 A：如果 luarocks 支持 init
luarocks init --lua-version=<detected_version>
```

> `luarocks init` 会自动生成 `./lua` 和 `./luarocks` 便利脚本。

```bash
# 方案 B：手动配置本地 tree
luarocks config --local rocks_trees '{ { name = "user", root = "./lua_modules" } }'
```

确保：
- 本地依赖树路径为 `./lua_modules/`（项目根目录下）
- 不使用系统全局的 LuaRocks 目录

### 4. 安装依赖

根据 rockspec 安装项目依赖：

```bash
# 安装 rockspec 中声明的所有依赖（不安装 rockspec 本身）
luarocks install --deps-only <rockspec-file>

# 或者，如果需要同时安装当前包
luarocks make
```

安装完成后：
- 确认 `lua_modules/` 目录已创建且包含依赖
- 如果遇到依赖冲突或版本不兼容，记录具体错误信息并询问用户

### 5. 检测 protoc 命令

本项目是 protobuf 相关的工具项目，protoc 是核心依赖。运行以下命令检测：

**Unix 平台**（Linux/macOS）：
```bash
which protoc && protoc --version
```

**Windows 平台**：
```cmd
where protoc
protoc --version
```

- 如果 protoc 存在，记录版本号
- 如果未找到，向用户报告：
  > ⚠️ 未检测到 `protoc` 命令。本项目是 protobuf 相关的工具项目，缺少 protoc 将无法正常开发运行。
  > 请安装 protoc：
  > - Ubuntu/Debian: `sudo apt install protobuf-compiler`
  > - macOS: `brew install protobuf`
  > - Windows:
  >   - 下载预编译二进制: https://github.com/protocolbuffers/protobuf/releases
  >   - 或使用 Chocolatey: `choco install protoc`
  >   - 或使用 winget: `winget install Google.Protobuf`
  > - 其他系统请参考 https://github.com/protocolbuffers/protobuf/releases

### 6. 验证环境

运行以下验证确保环境可用：

**Unix 平台**（Linux/macOS）：
```bash
# 验证 Lua 能加载本地模块
./lua -e "print('Lua OK, version:', _VERSION)"

# 验证 luarocks 能列出本地依赖
./luarocks list

# 如果 rockspec 依赖中包含 busted，验证测试框架可用
./lua -e "require('busted')" 2>/dev/null && echo "busted OK" || echo "busted not installed or check path"

# 尝试运行项目测试（如果有测试目录）
[ -d "tests" ] && ./luarocks test 2>/dev/null || true
```

Windows 平台使用 `lua.bat` / `luarocks.bat` 替代 `./lua` / `./luarocks`：
```cmd
lua.bat -e "print('Lua OK, version:', _VERSION)"
luarocks.bat list
```

### 7. 报告结果

向用户总结初始化结果：

```
✅ Lua 项目初始化完成
- Lua 版本: <version> (<path>)
- rockspec: <file>
- 依赖树: ./lua_modules/
- 已安装依赖: <list>
- 便利脚本: ./lua, ./luarocks

使用方法:
- 运行 Lua: ./lua <script.lua>
- 安装新包: ./luarocks install <package>
- 运行测试: ./luarocks test 或 busted tests/
```

## 后续维护

如果用户后续提到 rockspec 变更或需要更新依赖：

1. 比较 rockspec 文件的修改时间与 `lua_modules/` 目录
2. 如果 rockspec 更新，询问用户是否重装依赖
3. 如果用户确认，运行 `luarocks install --deps-only <rockspec>`

## 常见问题和处理

| 问题 | 处理方案 |
|------|----------|
| `luarocks: command not found` | - Linux: `sudo apt install luarocks` <br> - macOS: `brew install luarocks` <br> - Windows: 下载 https://luarocks.org/releases 或使用 `choco install luarocks` |
| 依赖安装失败（版本冲突） | 检查 rockspec 中的版本约束是否过严，建议用户调整 |
| `./lua` 无法加载模块 | 检查 `package.path` 和 `package.cpath` 是否包含 `lua_modules` 路径 |
| 无 rockspec 且用户拒绝创建 | 仅初始化 LuaRocks 环境，不安装依赖 |

## 注意事项

- **不要**使用 sudo 安装依赖，所有操作限制在项目目录的 `lua_modules/` 内
- **不要**修改系统级的 Lua 或 LuaRocks 配置
- Windows 平台下注意路径分隔符使用 `/` 或 `\\`，以及 `.dll` 与 `.so` 的区别

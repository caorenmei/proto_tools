---
name: project-init
description: |
  当用户有以下需求时调用此 skill：
  - 项目初始化、首次构建
  - conan install、cmake 配置
  - build/debug 初始化
  - "初始化项目"、"配置构建环境"、"第一次编译"

  **不触发的情况**：
  - 日常构建（`cmake --build` 增量编译，非初始化）
  - 仅运行测试（ctest）
  - 代码修改后的增量编译
---

# Project Init

封装跨平台游戏服务器项目的初始化构建流程，包括 Conan 依赖安装、CMake 配置和 LuaRocks 依赖安装。

## 平台检测

首先检测当前操作系统平台：
- Windows：使用 MSVC + Visual Studio 16 2019 + Debug 模式
- Linux：使用 Unix Makefiles + Release 模式

## Windows 初始化流程

### 1. 创建构建目录

```bash
mkdir -p build/debug
cd build/debug
```

### 2. 初始化 MSVC 环境

需要找到 VS2019 的 `vcvars64.bat` 并运行。

**常见路径（按优先级检查）**：
1. `"C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvars64.bat"`
2. `"C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\vcvars64.bat"`
3. `"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat"`

**自动检测逻辑**：
- 依次检查上述路径是否存在
- 找到第一个存在的路径即使用
- 若均不存在，询问用户并提供手动输入路径的选项

**执行方式**：
```bash
# 在 bash 中调用 vcvars64.bat（通过 cmd /c）
cmd //c "<vcvars64_path> && bash"
# 或直接在 cmd 中执行后切换回 bash
```

### 3. Conan 安装

```bash
conan install ../../conan/conanfile_windows.txt --profile=../../conan/profile_x64_windows_mtd.txt --build=missing --remote=conan
```

### 4. CMake 配置

**基础命令**：
```bash
cmake -G "Visual Studio 16 2019" -DCMAKE_BUILD_TYPE=Debug -DCMAKE_TOOLCHAIN_FILE=conan_paths.cmake -DCMAKE_INSTALL_PREFIX=../../install/debug ../..
```

**LuaRocks 选项**：
- 在 cmake 步骤前，询问用户是否需要 LuaRocks 支持
- 若需要：追加 `-DUSE_LUAROCKS=ON`
- 若不需要：不加此参数

### 5. LuaRocks 依赖安装（可选）

若用户选择了 LuaRocks 支持，初始化完成后询问是否执行：
```bash
cmake --build . --target luarocks_install_deps
```
- 用户确认后执行
- 用户拒绝则跳过

若用户未选择 LuaRocks，跳过此步骤，不询问。

## Linux 初始化流程

### 1. 创建构建目录

```bash
mkdir -p build/debug
cd build/debug
```

### 2. Conan 安装

```bash
conan install ../../conan/conanfile_linux.txt --profile=../../conan/profile_x64_linux.txt --build=missing --remote=conan
```

### 3. CMake 配置

**基础命令**：
```bash
cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=conan_paths.cmake -DCMAKE_INSTALL_PREFIX=../../install/release ../..
```

**LuaRocks 选项**：
- 在 cmake 步骤前，询问用户是否需要 LuaRocks 支持
- 若需要：追加 `-DUSE_LUAROCKS=ON`
- 若不需要：不加此参数

### 4. Make Install

```bash
touch ../../CMakeLists.txt && make -j 4 install
```

### 5. LuaRocks 依赖安装（可选）

若用户选择了 LuaRocks 支持，初始化完成后询问是否执行：
```bash
cmake --build . --target luarocks_install_deps
```
- 用户确认后执行
- 用户拒绝则跳过

若用户未选择 LuaRocks，跳过此步骤，不询问。

## 完整流程示例

### Windows 示例

```bash
# 1. 进入项目根目录
cd <project-root>

# 2. 创建并进入构建目录
mkdir -p build/debug
cd build/debug

# 3. 初始化 MSVC 环境（自动检测或手动指定路径）
cmd //c "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvars64.bat && bash"

# 4. Conan 安装依赖
conan install ../../conan/conanfile_windows.txt --profile=../../conan/profile_x64_windows_mtd.txt --build=missing --remote=conan

# 5. CMake 配置（带 LuaRocks）
cmake -G "Visual Studio 16 2019" -DCMAKE_BUILD_TYPE=Debug -DCMAKE_TOOLCHAIN_FILE=conan_paths.cmake -DCMAKE_INSTALL_PREFIX=../../install/debug -DUSE_LUAROCKS=ON ../..

# 6. 安装 LuaRocks 依赖
cmake --build . --target luarocks_install_deps
```

### Linux 示例

```bash
# 1. 进入项目根目录
cd <project-root>

# 2. 创建并进入构建目录
mkdir -p build/debug
cd build/debug

# 3. Conan 安装依赖
conan install ../../conan/conanfile_linux.txt --profile=../../conan/profile_x64_linux.txt --build=missing --remote=conan

# 4. CMake 配置（不带 LuaRocks）
cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=conan_paths.cmake -DCMAKE_INSTALL_PREFIX=../../install/release ../..

# 5. 编译安装
touch ../../CMakeLists.txt && make -j 4 install
```

## 注意事项

- 所有操作均在 `build/debug` 目录下执行
- Windows 下 MSVC 环境初始化是必要步骤，否则 CMake 找不到编译器
- LuaRocks 仅用于 `lua_tests` 和工具开发，生产构建可不启用
- 若 conan install 失败，检查 `--remote=conan` 远程仓库是否可达

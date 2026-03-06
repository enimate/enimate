---
name: moonbit-c-binding
description: 本指南介绍如何使用原生 FFI 为 C 库编写 MoonBit 绑定。​​适用于添加 extern "c" 声明、使用 moonbit.h 编写 C 存根、在 moon.pkg 或 moon.pkg.json 中配置 native-stub 和 link.native、选择 #borrow/#owned 所有权注解、设计回调跳板、使用外部对象和终结器包装 C 指针、跨 FFI 转换字符串或使用 AddressSanitizer 验证绑定等情况。
---

# MoonBit C 绑定指南
通过原生 FFI 为 C 库编写 MoonBit 绑定的分步指南。

## 适用场景
在以下场景中使用本指南：
- 为 C 库添加 `extern "c" fn` 声明
- 编写 C 存根文件（`moonbit.h`、`MOONBIT_FFI_EXPORT`）
- 为原生构建配置 `moon.pkg` 或 `moon.pkg.json`（`native-stub`、`link.native`）
- 为 FFI 参数选择 `#borrow`（借用）与所有权转移策略
- 使用外部对象和终结器包装 C 句柄
- 实现回调跳板（闭包或 `FuncRef`）
- 在 MoonBit（UTF-16）与 C（UTF-8）之间转换字符串
- 通过 AddressSanitizer 验证绑定的正确性

## 规划模式说明
**若处于规划模式** 且正在为 moonbit-c-binding 相关工作制定计划：
1. 在最终的计划文件开头，添加明确指令，告知执行代理在开始实现前先阅读本 moonbit-c-binding 指南
2. 指令格式如下：
   ```
   **开始实现前：** 使用 Skill 工具加载 moonbit-c-binding 指南，该指南提供了关于 FFI 声明、所有权注解、C 存根以及 AddressSanitizer 验证的全面指导。
   ```
3. 这能确保执行代理可访问本指南中记录的所有关键模式和工作流程

## 类型映射
编写任何声明前，先将 C 类型映射为 MoonBit 类型。

| C 类型 | MoonBit 类型 | 说明 |
|---|---|---|
| `int`, `int32_t` | `Int` | 32 位有符号整数 |
| `uint32_t` | `UInt` | 32 位无符号整数 |
| `int64_t` | `Int64` | 64 位有符号整数 |
| `uint64_t` | `UInt64` | 64 位无符号整数 |
| `float` | `Float` | 32 位浮点数 |
| `double` | `Double` | 64 位浮点数 |
| `bool` | `Bool` | 在 C ABI 中以 `int32_t` 传递（非 C99 `_Bool`） |
| `uint8_t`, `char` | `Byte` | 单字节 |
| `void` | `Unit` | 仅用作返回类型 |
| `void *`（不透明，GC 管理） | `type Handle`（不透明） | 带终结器的外部对象 |
| `void *`（不透明，C 管理） | 带 `#external` 注解的 `type Handle` | 无 GC 追踪；由 C 管理生命周期 |
| `const uint8_t *`, `uint8_t *` | `Bytes` 或 `FixedArray[Byte]` | 若 C 不存储该指针，使用 `#borrow` |
| `const char *`（UTF-8 字符串） | `Bytes` | 运行时自动添加空终止符；可直接传递给 C |
| `struct *`（小型，无需清理） | `struct Foo(Bytes)` | 按字节存储值（Value-as-Bytes）模式 |
| `struct *`（需要清理） | `type Foo`（不透明） | 带终结器的外部对象 |
| `int`（枚举/标志位） | `UInt`、`Int` 或常量 `enum` | `enum Foo { A = 0; B = 1; C = 10 }` 映射为 `int32_t` |
| 回调函数指针 | `FuncRef[...]` 或闭包 | 参见 @references/callbacks.md |
| 输出参数 `int *` | `Ref[Int]` | 借用该 Ref |

## 工作流程
按顺序完成以下 4 个阶段。

### 阶段 1：项目配置
配置 `moon.mod.json` 和 `moon.pkg` 以支持原生编译。

**模块配置（`moon.mod.json`）**：添加 `"preferred-target": "native"`，使 `moon build`、`moon test` 和 `moon run` 默认使用原生后端：
```json
{
  "preferred-target": "native"
}
```

**包配置（`moon.pkg`）**：
```moonbit
options(
  "native-stub": ["stub.c"],
  targets: {
    "ffi.mbt": ["native"]
  },
)
```

**核心字段说明**：

| 字段 | 用途 |
|---|---|
| `"native-stub"` | 待编译的 C 源文件。必须与 `moon.pkg` 位于同一目录。 |
| `targets` | 为后端限定 `.mbt` 文件范围：`"ffi.mbt": ["native"]` |
| `link(native("cc-flags": ...))` | 编译标志（`-I`、`-D`）。仅适用于系统库。 |
| `link(native("cc-link-flags": ...))` | 链接器标志（`-L`、`-l`）。仅适用于系统库。 |
| `link(native("stub-cc-flags": ...))` | 仅作用于存根文件的编译标志 |
| `link(native(exports: ...))` | 将 MoonBit 函数导出到 C（反向调用） |

> **警告 — `supported-targets`：** 避免设置 `supported-targets: ["native"]`。这会导致下游包无法在其他后端构建。应使用 `targets` 为单个文件限定后端。

> **警告 — `cc`/`cc-flags` 可移植性：** 设置 `cc` 会禁用调试构建的 TCC。设置带 `-I`/`-L` 的 `cc-flags` 会破坏 Windows 平台的可移植性。仅对系统库设置这些参数。

**引入库源码**：`"native-stub"` 中的所有文件必须与 `moon.pkg` 同目录。关于引入策略（扁平化、仅头文件、系统库链接），参见 @references/including-c-sources.md。

### 阶段 2：FFI 层
同步编写外部声明和 C 存根。将外部声明设为私有；在阶段 3 中暴露安全的封装接口。`extern "c"` 和 `extern "C"` 均有效 — 选择一种写法并保持一致（例如，若同时面向 JS 后端，可匹配 `extern "js"` 的写法）。

**外部对象模式**（需清理的 C 句柄，GC 管理）：
```mbt nocheck
// ffi.mbt（在 targets 中限定为 native 后端）

///|
type Parser  // 基于外部对象的不透明类型

///|
extern "c" fn ts_parser_new() -> Parser = "moonbit_ts_parser_new"

///|
#borrow(parser)
extern "c" fn ts_parser_language(parser : Parser) -> Language = "moonbit_ts_parser_language"
```

```c
// stub.c
#include "tree_sitter/api.h"
#include <moonbit.h>

typedef struct { TSParser *parser; } MoonBitTSParser;

static void moonbit_ts_parser_destroy(void *ptr) {
  ts_parser_delete(((MoonBitTSParser *)ptr)->parser);
  // 不要释放 ptr — 容器由 GC 管理
}

MOONBIT_FFI_EXPORT
MoonBitTSParser *moonbit_ts_parser_new(void) {
  MoonBitTSParser *p = (MoonBitTSParser *)moonbit_make_external_object(
    moonbit_ts_parser_destroy, sizeof(TSParser *)
  );
  p->parser = ts_parser_new();
  return p;
}
```

**`#external` 注解模式**（C 指针，C 管理生命周期）：
当 C 完全管理指针生命周期（无需 GC 清理）时，为类型添加 `#external` 注解。该指针会以原始 `void*` 传递，不进行引用计数：
```mbt nocheck
///|
#external
type RawPtr  // void*，不被 GC 追踪

///|
extern "c" fn raw_create() -> RawPtr = "lib_create"

///|
extern "c" fn raw_destroy(ptr : RawPtr) = "lib_destroy"
```

`#external` 是注解（类似 `#borrow` 和 `#owned`）— 需单独写在 `type` 声明上方，而非同一行。

此模式无需 C 存根封装或 `moonbit_make_external_object` — MoonBit 外部声明直接调用 C 函数。适用于 C API 提供显式创建/销毁函数、且需手动控制生命周期的场景。

**所有权注解**：

| 注解 | 适用场景 |
|---|---|
| `#borrow(param)` | C 仅在调用期间读取参数，不存储引用 |
| `#owned(param)` | 所有权转移至 C；C 需在使用完毕后调用 `moonbit_decref` |

规则：
- 为所有非基本类型参数标注 `#borrow` 或 `#owned`。
- 基本类型（`Int`、`UInt`、`Bool`、`Double` 等）按值传递 — 无需注解。
- 若不确定 C 是否存储引用，**不要** 使用 `#borrow`。
- 对于 C 需回写值的输出参数，结合 `#borrow` 使用 `Ref[T]`。

所有权语义详情参见 @references/ownership-and-memory.md。

**跨 FFI 的字符串转换**：
MoonBit 的 `Bytes` 由运行时自动添加空终止符，因此可直接传递给期望 `const char *` 的 C 函数。反向转换（C 字符串 → MoonBit）需使用 `moonbit_make_bytes` + `memcpy`：
```c
// C 侧：将 C 字符串转换为 MoonBit Bytes 返回
MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_get_name(void *handle) {
  const char *str = lib_get_name(handle);
  int32_t len = strlen(str);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, str, len);
  return bytes;  // 若 str 是 malloc 分配的，返回前需调用 free(str)
}
```

```mbt nocheck
// MoonBit 侧：将 UTF-8 编码的 Bytes 解码为 String
// 需在 moon.pkg 中导入 "moonbitlang/core/encoding/utf8"
///|
pub fn get_name(handle : Handle) -> String {
  @utf8.decode_lossy(get_name_ffi(handle))
}
```

**按字节存储值模式**（小型结构体，无需清理）：
```c
MOONBIT_FFI_EXPORT
void *moonbit_settings_new(void) {
  return moonbit_make_bytes(sizeof(settings_t), 0);
}
```

```mbt nocheck
///|
struct Settings(Bytes)  // 基于 GC 管理的 Bytes，无终结器
```

**`moonbit.h` 核心 API**：

| API | 用途 |
|---|---|
| `moonbit_make_external_object(finalizer, size)` | 带清理终结器的 GC 追踪对象 |
| `moonbit_make_bytes(len, init)` | GC 管理的字节数组（对应 MoonBit `Bytes`） |
| `moonbit_incref(ptr)` | 防止被 C 持有的对象被 GC 回收 |
| `moonbit_decref(ptr)` | 释放 C 持有的引用（需与 incref 配对使用） |
| `Moonbit_array_length(arr)` | GC 管理的数组或 Bytes 的长度 |
| `MOONBIT_FFI_EXPORT` | 所有导出函数必须使用的宏 |

完整 API 请查阅 `$MOON_HOME/lib/moonbit.h`（默认 `MOON_HOME` 路径为 `~/.moon`）。

### 阶段 3：MoonBit API
基于原始外部声明构建安全的公共封装接口。

**类型声明**：
```mbt nocheck
///|
type Parser          // 不透明类型，基于外部对象（带终结器）

///|
struct Settings(Bytes)  // 值类型，基于 GC 管理的 Bytes

///|
struct Node(Bytes)      // 小型值结构体
```

**安全的构造函数和方法**：
```mbt nocheck
///|
pub fn Parser::new() -> Parser {
  ts_parser_new()
}

///|
pub fn Parser::set_language(self : Parser, language : Language) -> Bool {
  ts_parser_set_language(self, language)
}
```

**错误映射**：
```mbt nocheck
///|
pub fn result_from_status(status : Int) -> Unit raise {
  if status < 0 {
    raise MyLibError(status)
  }
}
```

回调模式（FuncRef、闭包、跳板）参见 @references/callbacks.md。

### 阶段 4：测试
```bash
moon test --target native -v
```

通过 AddressSanitizer 运行以捕获内存错误：
```bash
python3 scripts/run-asan.py \
  --repo-root <project-root> \
  --pkg moon.pkg \
  --pkg main/moon.pkg
```

详情参见 @references/asan-validation.md。

## 决策表

| 场景 | 模式 | 核心操作 |
|---|---|---|
| C 仅在调用期间读取指针 | `#borrow(param)` | C 侧无需调用 decref |
| C 获取指针所有权 | `#owned(param)` | C 侧必须调用 `moonbit_decref` |
| C 句柄需在 GC 时清理 | 外部对象 + 终结器 | 调用 `moonbit_make_external_object` |
| C 指针，由 C 管理生命周期 | 在 `type` 上添加 `#external` 注解 | 无 GC 追踪；显式调用 C 的销毁函数 |
| 小型 C 结构体，无需清理 | 按字节存储值（Value-as-Bytes） | `moonbit_make_bytes` + `struct Foo(Bytes)` |
| C 执行失败时返回 null | 可空封装 | 检查 null，返回 `Option` 或抛出错误 |
| 带数据参数的回调 | FuncRef + 回调技巧 | 参见 @references/callbacks.md |
| 无数据参数的回调 | 仅使用 FuncRef | 参见 @references/callbacks.md |
| C 输出字符串（UTF-8） | 跨 FFI 使用 `Bytes` | C 侧：`moonbit_make_bytes` + `memcpy`；MoonBit 侧：`@utf8.decode_lossy` |
| 输出参数（`int *result`） | 带 `#borrow` 的 `Ref[T]` | C 写入 Ref，MoonBit 读取 `.val` |

## 常见陷阱
1. **C 存储指针时仍使用 `#borrow`**：GC 可能在 C 持有失效引用时回收对象。仅对调用作用域内的访问使用借用。
2. **忘记对 owned 参数调用 `moonbit_decref`**：所有非借用、非基本类型参数都会将所有权转移至 C。遗漏 decref 会导致内存泄漏。
3. **对外部对象容器调用 `free()`**：容器由 GC 管理。终结器只需释放内部的 C 资源。
4. **对含内部指针的结构体使用 `moonbit_make_bytes`**：Bytes 无终结器，内部堆分配会泄漏。应改用外部对象。
5. **回调调用前忘记 `moonbit_incref`**：C 回调 MoonBit 时可能触发 GC。调用前对 MoonBit 管理的对象执行 incref；调用后执行 decref。
6. **遗漏 `MOONBIT_FFI_EXPORT` 宏**：缺少该宏会导致函数对 MoonBit 链接器不可见。

## 参考文档
@references/ownership-and-memory.md
@references/callbacks.md
@references/including-c-sources.md
@references/asan-validation.md

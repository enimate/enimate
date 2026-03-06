# 引入 C 库源码

如何在 MoonBit 原生构建中引入 C 库源码。

## 约束条件

`moon` 工具链仅编译包目录下的 `native-stub` 文件——不会递归进入子目录。所有 C 源文件必须与 `moon.pkg` 位于同一目录。

## 实现策略

请根据所用库的情况选择对应策略，以下按复杂度从低到高排序：

### 扁平源码目录

对于采用扁平源码布局的库（例如 Lua），无需特殊处理——直接将 `.c` 和 `.h` 文件复制到包目录即可：

```python
for file in lua_src_dir.iterdir():
    if file.suffix in (".c", ".h"):
        shutil.copy2(file, package_dir / file.name)
```

在 `native-stub` 中按原文件名列出这些文件即可。

### 仅头文件（Header-only）

在桩文件（stub file）中定义实现宏并引入头文件。无需复制文件。

```c
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#include <moonbit.h>
```

### 系统库链接

仅在桩文件中引入头文件，并在 `moon.pkg` 中提供链接器标志：

```moonbit
link(
  native(
    "cc-flags": "-I/path/to/include",
    "cc-link-flags": "-L/path/to/lib -lmylib",
  )
)
```

> **可移植性警告**：`-I`/`-L`/`-l` 标志是 GCC/Clang 的约定。
> MSVC 的 `cl.exe` 不支持这些标志。

### 嵌套源码树（扁平化处理）

对于包含嵌套目录的库（例如 `src/unix/async.c`、`lib/src/parser.c`），必须将其**扁平化**到包目录中。详见下文。

## 扁平化嵌套源码树

扁平化脚本（通常为 Shell 或 Python 脚本）需处理以下三个问题：

### 1. 文件名改写

将每个源文件复制到包目录，并将原始路径编码到扁平文件名中。常用的约定是将 `/` 替换为 `#`：

| 原始路径 | 扁平化后的文件名 |
|---|---|
| `lib/src/lib.c` | `tree-sitter#lib#src#lib.c` |
| `src/unix/async.c` | `uv#src#unix#async.c` |

`#` 对 `moon` 无特殊含义——仅用于方便追溯文件的原始位置。建议添加库名前缀（例如 `tree-sitter`、`uv`）以避免文件名冲突。

### 2. 引入语句重写

扁平化后，`#include "relative/path.h"` 指令会失效，因为目录结构已不存在。脚本需将带引号的引入语句重写为引用改写后的文件名：

```c
// 改写前（原始源码）
#include "unix/internal.h"

// 改写后（扁平化后）
#include "uv#src#unix#internal.h"
```

仅重写带引号的引入语句（`#include "..."`），不要修改系统引入语句（`#include <...>`）。脚本还应递归复制并扁平化所有被引用到的头文件。

### 3. 平台条件编译保护

对于跨平台库，不同操作系统需要不同的源文件。将平台相关的文件内容包裹在预处理指令保护块中，这样所有变体都能共存于同一个 `native-stub` 列表中：

```c
// uv#src#win#async.c —— 仅 Windows 平台的源码
#if defined(_WIN32)
/* ... 经过引入语句重写的原始源码 ... */
#endif
```

`moon` 会在所有平台编译所有 `.c` 文件，但这些保护块能确保只有相关代码会被纳入编译。

### 更新 `moon.pkg`

当一个库包含大量源文件时，脚本应通过编程方式更新 `moon.pkg.json` 中的 `native-stub` 数组，以与磁盘上的文件保持同步。

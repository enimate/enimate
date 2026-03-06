# MoonBit C 绑定的 AddressSanitizer (ASan) 验证

本文档介绍如何使用 AddressSanitizer 检测 C 存根代码中的内存错误。

## ASan 的重要性

C 绑定引入了 MoonBit 垃圾回收（GC）无法感知的手动内存管理逻辑。这类内存错误会悄无声息地破坏内存或造成资源泄漏。ASan 可在运行时捕获以下问题：

| 错误类型 | 绑定代码中的典型成因 |
|---|---|
| 释放后使用（Use-after-free） | 终结器执行后仍访问 C 对象 |
| 重复释放（Double-free） | 对已释放的对象调用 `moonbit_decref` |
| 内存泄漏（Memory leaks） | 通过 `moonbit_make_external_object` 创建对象时未注册终结器 |
| 缓冲区溢出（Buffer overflow） | 向 `moonbit_make_bytes` 传入错误的大小值 |
| 返回后使用（Use-after-return） | 返回指向 C 局部变量的指针 |

## 快速开始

本工程提供了 `scripts/run-asan.py` 脚本，可自动化完成整个检测流程，也支持 CI 环境运行。

### 单个包检测：
```bash
python3 scripts/run-asan.py --repo-root <project-root> --pkg moon.pkg
```

### 多个包检测：
```bash
python3 scripts/run-asan.py \
  --repo-root <project-root> \
  --pkg moon.pkg \
  --pkg main/moon.pkg
```

`--pkg` 参数支持 `moon.pkg`（DSL 格式）和 `moon.pkg.json`（JSON 格式）两种文件。若指定的文件不存在，脚本会自动尝试另一种格式。

> 注意：检测多个包时，需包含所有含 `native-stub` 的包以及所有入口包。满足以下条件之一即为入口包：
> 1. 配置为主包（即 `moon.pkg`/`moon.pkg.json` 中 `is-main` 设为 true）；
> 2. 包含测试代码。

---

## 工作原理

该脚本通过两种机制实现检测能力，理解这些机制有助于手动配置或调试：

### 1. 禁用 mimalloc

MoonBit 通过 `libmoonbitrun.o` 内置了 mimalloc 内存分配器。mimalloc 会拦截 `malloc`/`free` 调用，导致 ASan 无法追踪内存分配。脚本会将 `libmoonbitrun.o` 替换为编译后的空对象文件，检测完成后恢复原文件。可传入 `--no-disable-mimalloc` 跳过此步骤。

### 2. 包配置补丁

需将 ASan 编译标记注入包配置文件。脚本会在 `try/finally` 代码块中完成配置的快照、补丁和恢复操作：

| 字段 | 补丁方式 | 原因 |
|---|---|---|
| `cc-flags` | 设置为 `-g -fsanitize=address -fno-omit-frame-pointer` | 为 MoonBit 生成的 C 代码插入检测逻辑 |
| `stub-cc-flags` | 在原有值后**追加**相同标记 | 为 C 存根文件插入检测逻辑（保留原有 `-I`、`-D` 等标记） |

对所有含 `native-stub` 的包修补 `stub-cc-flags`（对所有包执行此操作均安全）；对所有入口包（主包或测试包）修补 `cc-flags`。

### 环境变量

脚本会设置以下环境变量：
- `ASAN_OPTIONS="detect_leaks=<0|1>:fast_unwind_on_malloc=0"` — 启用 ASan，并（在支持的平台）启用 LSan 内存泄漏检测。`fast_unwind_on_malloc=0` 可生成更精确的调用栈信息。
- `LSAN_OPTIONS="suppressions=<path>"` — 若项目根目录存在 `.lsan-suppressions` 文件，会将其路径传入 LSan（详见下文「内存泄漏抑制」）。

---

## 平台配置

### macOS

**Homebrew LLVM**（推荐）—— 同时支持 ASan 和 LSan（泄漏检测）。脚本会自动探测 `llvm`、`llvm@18`、`llvm@19`、`llvm@15`、`llvm@13` 版本，可通过 `brew install llvm` 安装。

**系统 clang（Xcode 15+）**（备用）—— 支持 ASan 但**不支持** LSan，此时泄漏检测会被禁用（`detect_leaks=0`）。

**通过 `MOON_CC` + `MOON_AR` 覆盖编译器**：macOS 下脚本会显式设置 `MOON_CC` 和 `MOON_AR` 以使用 Homebrew LLVM，因为 Apple Clang 不支持 LeakSanitizer。该覆盖仅在 macOS 下需要 —— Linux 下系统编译器原生支持 ASan，且当 `cc-flags` 存在时，tcc 会自动禁用。

关键约束：
- `MOON_CC` 仅接受编译器**路径**（例如 `/opt/homebrew/opt/llvm/bin/clang`），不能包含 `-fsanitize=address` 等标记 —— MoonBit 会将该值视为单一可执行文件路径。
- 除非同时设置 `MOON_CC`，否则 `MOON_AR` 会被忽略。
- macOS 下 MoonBit 会从编译器路径推导 `ar` 工具路径。Homebrew LLVM 提供 `llvm-ar` 但无 `ar`，因此需设置 `MOON_AR=/usr/bin/ar`。

### Linux

多数发行版的系统 `gcc` 或 `clang` 均内置 ASan。在最小化镜像中，需安装 `libasan`（例如 `apt-get install libasan6`）。

### Windows

使用 `cl.exe` 编译时需添加 `/Z7 /fsanitize=address` 标记。手动禁用 mimalloc 的方式：

```powershell
echo "" >dummy_libmoonbitrun.c
$moon_home = if ($env:MOON_HOME) { $env:MOON_HOME } else { "$env:USERPROFILE\.moon" }
$out_path = Convert-Path "$moon_home\lib\libmoonbitrun.o"
cl.exe dummy_libmoonbitrun.c /c /Fo: $out_path
```

---

## 内存泄漏抑制

macOS 系统库（libobjc、libdispatch、dyld）存在已知的泄漏问题，会导致误报。可在项目根目录创建 `.lsan-suppressions` 文件：

```plaintext
leak:_libSystem_initializer
leak:_objc_init
leak:libdispatch
```

每行 `leak:<pattern>` 会匹配调用栈信息，若任意栈帧匹配，则该泄漏会被抑制。脚本会自动将文件绝对路径传入 `LSAN_OPTIONS`。

> 仅抑制无法控制的系统/第三方代码泄漏，切勿抑制自有 C 存根函数的泄漏。

---

## 结果解读

### heap-use-after-free（堆内存释放后使用）
对象已被释放但仍被访问。需检查终结器执行顺序，确认 `moonbit_decref` 未被过早调用，验证原生 C 指针的生命周期不超过 MoonBit 包装对象。

### double-free（重复释放）
同一指针被释放两次。确保每个 C 资源仅有一个所有者，检查 `moonbit_decref` 未在已释放对象上调用。

### heap-buffer-overflow（堆缓冲区溢出）
写入超出已分配缓冲区的范围。检查 `moonbit_make_bytes` 和 `moonbit_make_int32_array` 的大小计算逻辑，尤其是字节数与元素数的转换。

### detected memory leaks（检测到内存泄漏）
C 分配的内存未被释放。验证所有 C 内存分配均通过 `moonbit_make_external_object` 包装，以注册终结器完成清理。

### 修复流程
1. 读取 ASan 调用栈，定位自有 C 存根代码中的首个栈帧；
2. 确定涉及的外部对象或缓冲区；
3. 追踪其生命周期：创建、`incref`/`decref` 调用、终结器注册；
4. 修复根因后，重新运行 ASan 验证修复效果。

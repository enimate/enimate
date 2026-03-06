## 外部函数接口（FFI）

我们此前介绍的内容均围绕纯计算的描述展开。但在实际场景中，你需要与真实世界进行交互。然而，不同的后端（C、JS、Wasm、WasmGC）所面对的“外部环境”各不相同，有时还依赖于具体的运行时（如[Wasmtime](https://wasmtime.dev/)、Deno、浏览器等）。

### 后端

MoonBit 目前支持五种后端：

- Wasm
- Wasm GC
- JavaScript
- C
- LLVM（实验性）

#### Wasm

此处所指的 Wasm 是包含部分 MVP 后提案的 WebAssembly，具体包括：

- 批量内存操作（bulk-memory-operations）
- 多值返回（multi-value）
- 引用类型（reference-types）

为保证更好的兼容性，`init` 函数会被编译为[`start` 函数](https://webassembly.github.io/spec/core/syntax/modules.html#start-function)，而 `main` 函数会被导出为 `_start`。

##### 注意事项
对于 Wasm 后端而言，所有与外部环境交互的函数都依赖于宿主环境。例如，Wasm 和 Wasm GC 后端的 `println` 函数依赖于导入一个名为 `spectest.print_char` 的函数——该函数每次调用会打印一个 UTF-16 代码单元。标准库中的 `env` 包以及 `moonbitlang/x` 中的部分包依赖于为 MoonBit 运行时定义的特定宿主函数。若你希望生成的 Wasm 具备可移植性，请避免使用这些包。

#### Wasm GC

此处的 Wasm GC 指启用了垃圾回收提案的 WebAssembly，这意味着数据结构会通过 `struct`、`array` 等引用类型表示，且默认不会使用线性内存。它同时支持其他 MVP 后提案，包括：

- 多值返回（multi-value）
- JS 字符串内置函数（JS string builtins）

为保证更好的兼容性，`init` 函数会被编译为[`start` 函数](https://webassembly.github.io/spec/core/syntax/modules.html#start-function)，而 `main` 函数会被导出为 `_start`。

##### 注意事项
对于 Wasm 后端而言，所有与外部环境交互的函数都依赖于宿主环境。例如，Wasm 和 Wasm GC 后端的 `println` 函数依赖于导入一个名为 `spectest.print_char` 的函数——该函数每次调用会打印一个 UTF-16 代码单元。标准库中的 `env` 包以及 `moonbitlang/x` 中的部分包依赖于为 MoonBit 运行时定义的特定宿主函数。若你希望生成的 Wasm 具备可移植性，请避免使用这些包。

#### JavaScript

JavaScript 后端会生成一个 JavaScript 文件，根据[配置项](../toolchain/moon/package.md#js-backend-link-options)，该文件可以是 CommonJS 模块、ES 模块或 IIFE（立即执行函数表达式）。

#### C

C 后端会生成一个 C 文件。MoonBit 工具链还会编译该项目，并根据[配置项](../toolchain/moon/package.md#native-backend-link-options)生成可执行文件。

#### LLVM

LLVM 后端会生成一个目标文件。该后端仍处于实验阶段，暂不支持 FFI。

### 声明外部类型

你可以使用 `#extern` 注解来声明外部类型，示例如下：

```moonbit
##external
type ExternalRef
```

#### Wasm & Wasm GC

这种声明会被解析为[`externref`](https://webassembly.github.io/spec/core/syntax/types.html#reference-types)。

#### JavaScript

这种声明会被解析为一个 JavaScript 值。

#### C

这种声明会被解析为 `void*`。

### 声明外部函数

要与外部环境交互，你可以声明外部函数。

##### 注意事项
MoonBit 不支持多态外部函数。

#### Wasm & Wasm GC

声明外部函数有两种方式：导入函数或编写内联函数。

你可以从运行时宿主中导入指定模块名和函数名的函数：

```moonbit
fn cos(d : Double) -> Double = "math" "cos"
```

也可以使用 Wasm 语法编写内联函数：

```moonbit
extern "wasm" fn identity(d : Double) -> Double =
  #|(func (param f64) (result f64))
```

##### 注意事项
编写内联函数时，请勿指定函数名。

#### JavaScript

声明外部函数有两种方式：导入函数或编写内联函数。

你可以导入指定模块名和函数名的函数，这会被解析为 `module.function`。例如：

```moonbit
fn cos(d : Double) -> Double = "Math" "cos"
```

对应的逻辑等价于 `const cos = (d) => Math.cos(d)`。

也可以通过编写内联函数来定义一个 JavaScript 匿名函数：

```moonbit
extern "js" fn cos(d : Double) -> Double =
  #|(d) => Math.cos(d)
```

#### C

你可以通过导入指定函数名的方式声明外部函数：

```moonbit
extern "C" fn put_char(ch : UInt) = "function_name"
```

若某个包需要动态链接外部 C 库，需在 `moon.pkg.json` 中添加 `cc-link-flags` 配置项。该配置项会直接传递给 C 编译器。

```json
{
  // ...
  "link": {
    "native": {
      "cc-link-flags": "-l<c library>"
    }
  },
  // ...
}
```

若要定义包装函数，你可以在包中添加一个 C 存根文件，并在该包的 `moon.pkg.json` 中添加以下配置：

```json
{
  // ...
  "native-stub": [
    // 存根文件名列表
  ],
  // ...
}
```

你可能需要引入 `#include "moonbit.h"`，该头文件包含了 MoonBit C 接口的类型定义和便捷工具函数。该头文件位于 `~/.moon/include` 路径下，可查看其内容了解更多细节。

#### 类型

声明函数时，需确保函数签名与实际的外部函数一致。
当函数无返回值（如 C 中的 `void`）时，可忽略函数声明中的返回类型注解。
下表展示了部分 MoonBit 类型的底层表示：

#### Wasm

| MoonBit 类型                       | ABI 类型    |
|------------------------------------|-------------|
| `Bool`                             | `i32`       |
| `Int`                              | `i32`       |
| `UInt`                             | `i32`       |
| `Int64`                            | `i64`       |
| `UInt64`                           | `i64`       |
| `Float`                            | `f32`       |
| `Double`                           | `f64`       |
| 常量枚举（constant `enum`）        | `i32`       |
| 外部类型（`#external type T`）     | `externref` |
| `FuncRef[T]`                       | `funcref`   |

#### Wasm GC

| MoonBit 类型                       | ABI 类型                                 |
|------------------------------------|------------------------------------------|
| `Bool`                             | `i32`                                    |
| `Int`                              | `i32`                                    |
| `UInt`                             | `i32`                                    |
| `Int64`                            | `i64`                                    |
| `UInt64`                           | `i64`                                    |
| `Float`                            | `f32`                                    |
| `Double`                           | `f64`                                    |
| 常量枚举（constant `enum`）        | `i32`                                    |
| 外部类型（`#external type T`）     | `externref`                              |
| `String`                           | 若启用 JS 字符串内置函数则为 `externref` |
| `FuncRef[T]`                       | `funcref`                                |

#### JavaScript

| MoonBit 类型                       | ABI 类型       |
|------------------------------------|----------------|
| `Bool`                             | `boolean`      |
| `Int`                              | `number`       |
| `UInt`                             | `number`       |
| `Float`                            | `number`       |
| `Double`                           | `number`       |
| 常量枚举（constant `enum`）        | `number`       |
| 外部类型（`#external type T`）     | `any`          |
| `String`                           | `string`       |
| `FixedArray[Byte]`/`Bytes`         | `Uint8Array`   |
| `FixedArray[T]` / `Array[T]`       | `T[]`          |
| `FuncRef[T]`                       | `Function`     |

##### 注意事项
数值类型的 `FixedArray[T]` 未来可能会迁移为 `TypedArray`。

#### C

| MoonBit 类型                       | ABI 类型                                  |
|------------------------------------|-------------------------------------------|
| `Bool`                             | `int32_t`                                 |
| `Int`                              | `int32_t`                                 |
| `UInt`                             | `uint32_t`                                |
| `Int64`                            | `int64_t`                                 |
| `UInt64`                           | `uint64_t`                                |
| `Float`                            | `float`                                   |
| `Double`                           | `double`                                  |
| 常量枚举（constant `enum`）        | `int32_t`                                 |
| 抽象类型（`type T`）               | 指针（必须是有效的 MoonBit 对象）        |
| 外部类型（`#external type T`）     | `void*`                                   |
| `FixedArray[Byte]`/`Bytes`         | `uint8_t*`                                |
| `FixedArray[T]`                    | `T*`                                      |
| `FuncRef[T]`                       | 函数指针                                  |

##### 注意事项
若 `FuncRef[T]` 中 `T` 的返回类型为 `Unit`，则该类型指向一个返回 `void` 的函数。

上表未提及的类型暂无稳定的 ABI，因此你的代码不应依赖其底层表示。

#### 回调函数

有时，我们希望将 MoonBit 函数作为回调函数传递给外部接口。MoonBit 支持闭包特性。根据 MDN 术语表的定义：

> 闭包是函数与其周围词法环境（lexical environment）的组合。换句话说，闭包让函数能够访问其外部作用域。在 JavaScript 中，每当创建一个函数时，闭包就会随之生成。

在某些场景下，我们希望传递的回调函数不捕获任何局部自由变量。为此，MoonBit 提供了一种特殊类型 `FuncRef[T]`，用于表示类型为 `T` 的闭包函数（无外部依赖）。`FuncRef[T]` 类型的值必须是类型为 `T` 的闭包函数，否则会触发[类型错误](error_codes/E4151.md)。

在其他场景下，MoonBit 函数参数会被表示为一个函数，以及一个包含其周围状态的对象。

#### Wasm & Wasm GC

对于 Wasm 后端，回调函数会以 `externref` 的形式传递（`externref` 表示宿主环境的函数）。但需将函数及其捕获的数据转换为宿主环境的函数。

为实现这一转换，Wasm 模块会从 `moonbit:ffi` 模块导入一个名为 `make_closure` 的函数。该函数接收一个函数和一个对象作为参数——其中函数的第一个参数必须是该对象，且函数需返回一个宿主环境的函数。也就是说，宿主环境负责完成部分应用（partial application）。一个可能的实现如下：

```javascript
{
  "moonbit:ffi": {
    "make_closure": (funcref, closure) => funcref.bind(null, closure)
  }
}
```

#### JavaScript

JavaScript 原生支持闭包，因此无需额外处理。

#### C

部分 C 库函数允许在回调函数外额外传入数据。
假设存在如下 C 库函数：

```c
void register_callback(void (*callback)(void*), void *data);
```

我们可以通过以下技巧绑定该 C 函数，并向其传递闭包：

```moonbit
extern "C" fn register_callback_ffi(
  call_closure : FuncRef[(() -> Unit) -> Unit],
  closure : () -> Unit
) = "register_callback"

fn register_callback(callback : () -> Unit) -> Unit {
  register_callback_ffi(
    fn (f) { f() },
    callback
  )
}
```

#### 自定义常量枚举的整数值

在 MoonBit 的所有后端中，常量枚举（所有构造函数均无负载的 `enum`）都会被转换为整数。
你可以在构造函数声明后添加 `= <integer literal>`，自定义每个构造函数对应的整数值：

```moonbit
enum SpecialNumbers {
  Zero = 0
  One
  Two
  Three
  Ten = 10
  FourtyTwo = 42
}
```

若未指定构造函数的整数值，
则默认值为前一个构造函数的值加 1（第一个构造函数的默认值为 0）。
该特性在绑定 C 库的标志位（flags）时尤为实用。

### 导出函数

对于非方法、非多态的公有函数，可通过配置[链接配置项](../toolchain/moon/package.md#link-options)中的 `exports` 字段进行导出。

```json
{
  "link": {
    "<backend>": {
      "exports": [ "add", "fib:test" ]
    }
  }
}
```

上述示例导出了 `add` 和 `fib` 函数，其中 `fib` 会被导出为 `test`。

#### Wasm & Wasm GC

##### 注意事项
该配置仅对当前配置的包生效，即不会影响下游包。

#### JavaScript

##### 注意事项
该配置仅对当前配置的包生效，即不会影响下游包。

此外，还有一个 `format` 配置项，可将导出格式指定为 CommonJS 模块（`cjs`）、ES 模块（`esm`）或 IIFE。

#### C

##### 注意事项
该配置仅对当前配置的包生效，即不会影响下游包。

目前暂不支持为重命名导出的函数。

### 生命周期管理

MoonBit 是一门具备垃圾回收机制的编程语言。因此，在处理外部对象或将 MoonBit 对象传递给宿主环境时，必须关注生命周期管理。当前，MoonBit 的 Wasm 后端和 C 后端采用引用计数法；Wasm GC 后端和 JavaScript 后端则复用运行时的垃圾回收机制。

#### 外部对象的生命周期管理

在 MoonBit 中处理外部对象/资源时，需及时销毁对象或释放资源，以避免内存/资源泄漏。

##### 注意事项
仅适用于 C 后端

`moonbit.h` 提供了 `moonbit_make_external_object` API，可借助 MoonBit 自身的自动内存管理系统处理外部对象/资源的生命周期：

```c
void *moonbit_make_external_object(
  void (*finalize)(void *self),
  uint32_t payload_size
);
```

`moonbit_make_external_object` 会创建一个大小为 `payload_size + sizeof(finalize)` 的新 MoonBit 对象，
其内存布局如下：

```default
| MoonBit 对象头 | ... 负载数据 | 析构函数（finalize） |
                ^
                |
                |_
                   `moonbit_make_external_object` 返回的指针
```

因此，你可以直接将该对象视为指向其负载数据的指针。当 MoonBit 的自动内存管理系统检测到通过 `moonbit_make_external_object` 创建的对象不再存活时，会以该对象自身为参数调用 `finalize` 函数。此时，`finalize` 函数可释放该对象负载数据所持有的外部资源/内存。

##### 注意事项
`finalize` 函数**禁止**释放对象自身的内存，这部分逻辑由 MoonBit 运行时负责。

在 MoonBit 侧，`moonbit_make_external_object` 返回的对象
应绑定到一个抽象类型（通过 `type T` 声明），
以确保 MoonBit 的内存管理系统不会忽略该对象。

#### MoonBit 对象的生命周期管理

当通过函数将 MoonBit 对象传递给宿主环境时，必须妥善管理 MoonBit 对象自身的生命周期。如前所述，MoonBit 的 Wasm 后端和 C 后端采用编译器优化的引用计数法管理对象生命周期。为避免内存错误或泄漏，FFI 函数必须正确维护 MoonBit 对象的引用计数。

##### 注意事项
仅适用于 C 后端和 Wasm 后端

##### 引用计数的调用约定

默认情况下，MoonBit 对引用计数采用“所有权传递”（owned）调用约定。即被调用方（被执行的函数）负责通过 `moonbit_decref` / `$moonbit.decref` 函数释放其参数的引用计数。若参数被多次使用，被调用方应通过 `moonbit_incref` / `$moonbit.incref` 函数增加引用计数。不同场景下的必要操作规则如下：

| 场景                | 操作       |
|---------------------|------------|
| 读取字段/元素       | 无         |
| 存储到数据结构中    | `incref`   |
| 传递给 MoonBit 函数 | `incref`   |
| 传递给其他外部函数  | 无         |
| 作为返回值          | 无         |
| 作用域结束（未返回）| `decref`   |

例如，以下是对标准 `open` 函数（用于打开文件）的生命周期安全绑定：

```moonbit
extern "C" fn open(filename : Bytes, flags : Int) -> Int = "open_ffi"
```

```c
int open_ffi(moonbit_bytes_t filename, int flags) {
  int fd = open(filename, flags);
  moonbit_decref(filename);
  return fd;
}
```

##### 托管类型

以下类型始终为非装箱（unboxed）类型，因此无需管理其生命周期：

- 内置数值类型（如 `Int`、`Double`）
- 常量枚举（所有构造函数均无负载的 `enum`）

以下类型始终为装箱（boxed）且引用计数类型：

- `FixedArray[T]`、`Bytes`、`String`
- 抽象类型（`type T`）

外部类型（`#external type T`）同样为装箱类型，但它们表示外部指针，
因此 MoonBit 不会对其执行任何引用计数操作。

带负载的 `struct`/`enum` 的内存布局目前尚未稳定。

##### 借用（borrow）与所有权（owned）注解

通过 FFI 传递参数时，参数的所有权可能被保留或转移。
可通过 `#borrow` 和 `#owned` 注解指定这两种语义。

##### 警告
我们正计划将默认语义从 `#owned` 迁移为 `#borrow`

`#borrow` 和 `#owned` 的语法如下：

```moonbit
##borrow(params..)
extern "C" fn c_ffi(..) -> .. = ..
```

其中 `params` 是 `c_ffi` 参数的子集。

标注 `#borrow` 的参数会采用“借用”调用约定传递，即被调用函数无需对这些参数执行 `decref` 操作。若 FFI 函数仅在本地读取参数（即不返回参数、不将参数存储到数据结构中），可直接使用 `#borrow` 注解。例如，上述 `open` 函数可改写为：

```moonbit
##borrow(filename)
extern "C" fn open(filename : Bytes, flags : Int) -> Int = "open"
```

此时无需再编写存根函数——直接绑定原生的 `open` 函数即可。借助 `#borrow` 注解，该实现仍能保证生命周期安全。

即便因其他原因仍需存根函数，`#borrow` 也通常能简化生命周期管理。**借用参数**在不同场景下的必要操作规则如下：

| 场景                                          | 操作       |
|-----------------------------------------------|------------|
| 读取字段/元素                                 | 无         |
| 存储到数据结构中                              | `incref`   |
| 传递给 MoonBit 函数                           | `incref`   |
| 传递给其他 C 函数 / `#borrow` 修饰的 MoonBit 函数 | 无         |
| 作为返回值                                    | `incref`   |
| 作用域结束（未返回）                          | 无         |

与之相反的是 `#owned` 语义：参数的所有权会被 FFI 函数接管，后续需手动执行 `decref` 操作。
该语义的一个典型场景是注册回调函数（闭包的所有权会被接管）。

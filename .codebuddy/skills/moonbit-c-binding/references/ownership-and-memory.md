# 所有权语义与内存管理
本文档详细介绍所有权转移以及 `moonbit_incref`/`moonbit_decref` 的使用规则。关于 `#borrow`/`#owned` 的基础用法，以及外部对象/字节值模式，请参考《SKILL.md》第二阶段内容。

## `#owned(param)` 语义
`#owned` 注解显式声明参数的所有权转移至 C 端。C 端在使用完毕后必须调用 `moonbit_decref()`。不为参数添加所有权注解的写法已被废弃——新代码应显式使用 `#owned(param)`。

**基本类型**（`Int`、`UInt`、`Bool`、`Double`、`Int64`、`UInt64`、`Byte`、`Float`）：按值传递。无所有权相关问题，无需添加注解。

**GC 管理的对象**（`Bytes`、`String`、`FixedArray[T]`、外部对象、结构体包装器）：需使用 `#owned` 将所有权转移至 C 端。C 端使用完毕后必须调用 `moonbit_decref()`。

**通过 `moonbit_make_external_object`、`moonbit_make_bytes` 等函数在 C 端分配的对象**：C 代码拥有新创建的对象所有权。要么将其返回给 MoonBit（转移所有权），要么在使用完毕后调用 `moonbit_decref()`。从 C 端视角，此类对象应视为 `#owned`。

## 操作对照表
针对参数的不同操作，需执行的引用计数操作如下：

**`#borrow` 修饰的参数**：

| 操作 | 所需执行的操作 |
|---|---|
| 读取字段/元素 | 无 |
| 存入数据结构 | 调用 `moonbit_incref` |
| 传递给 MoonBit 函数 | 调用 `moonbit_incref` |
| 传递给其他 C 函数 | 无 |
| 作为返回值返回 | 调用 `moonbit_incref` |
| 作用域结束 | 无 |

**`#owned` 修饰的参数（无注解时默认为此类型）**：

| 操作 | 所需执行的操作 |
|---|---|
| 读取字段/元素 | 无 |
| 存入数据结构 | 无（已拥有所有权） |
| 传递给 MoonBit 函数 | 调用 `moonbit_incref` |
| 传递给其他 C 函数 | 无 |
| 作为返回值返回 | 无 |
| 作用域结束（未返回） | 调用 `moonbit_decref` |

`#owned` 的实用规则：
- 函数返回前，必须为每个 `owned` 参数调用且仅调用一次 `moonbit_decref()`。
- 若要长期存储对象，需在存储结构销毁时调用 `decref`。
- 所有提前返回的分支都必须确保对所有 `owned` 参数执行 `decref`。

示例：
```c
MOONBIT_FFI_EXPORT
int32_t
moonbit_process(void *handle, moonbit_bytes_t data) {
  size_t len = Moonbit_array_length(data);
  int32_t result = lib_process(handle, (const char *)data, len);
  moonbit_decref(handle);  // 使用后递减引用计数
  moonbit_decref(data);    // 递减字节数据的引用计数
  return result;
}
```

## `Ref[T]` 输出参数
`Ref[T]` 单元格允许 C 端回写值。对其使用 `borrow` 修饰，因为 C 端不会持有该单元格的所有权——仅向其中写入值。

```mbt nocheck
///|
#borrow(major, minor, patch)
extern "C" fn __llvm_get_version(
  major : Ref[UInt],
  minor : Ref[UInt],
  patch : Ref[UInt],
) = "LLVMGetVersion"

///|
pub fn llvm_get_version() -> (UInt, UInt, UInt) {
  let major = Ref::new(0U)
  let minor = Ref::new(0U)
  let patch = Ref::new(0U)
  __llvm_get_version(major, minor, patch)
  (major.val, minor.val, patch.val)
}
```

## `moonbit_incref` / `moonbit_decref` 配对使用
当 C 端需要在单次调用之外持有 MoonBit 对象的引用时（例如，将其存储在 C 结构体中，或后续传递给回调函数），需调用 `moonbit_incref` 防止对象被垃圾回收（GC）：

```c
// 将 MoonBit 对象存储到 C 结构体中
void store_callback(MyState *state, void *moonbit_closure) {
  moonbit_incref(moonbit_closure);  // 防止被 GC 回收
  state->callback = moonbit_closure;
}

// 不再需要时释放
void clear_callback(MyState *state) {
  moonbit_decref(state->callback);  // 允许 GC 回收
  state->callback = NULL;
}
```

规则：
- 每个 `moonbit_incref` 必须对应一个 `moonbit_decref`。
- 存储对象前调用 `incref`；存储结构销毁或被覆盖时调用 `decref`。
- 当 C 端回调 MoonBit 时，垃圾回收（GC）可能触发。需确保所有 C 端持有的 MoonBit 对象在回调调用前都已执行 `incref`。

```c
// 补充示例：回调场景下的引用计数管理
void trigger_callback(MyState *state) {
  // 确保回调前对象已被 incref，防止 GC 在回调执行中回收
  moonbit_incref(state->callback);
  moonbit_invoke_closure(state->callback);
  moonbit_decref(state->callback);
}
```

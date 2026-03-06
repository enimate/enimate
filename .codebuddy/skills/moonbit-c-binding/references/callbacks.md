# 回调函数（Callbacks）与函数引用（FuncRef）

C 语言中的回调函数通常有以下两种形式：
- 同时接收函数指针和回调数据；
- 仅接收函数指针。

## 带回调数据的函数指针

这种情况下，你应当使用“FuncRef + 回调（Callback）”技巧。通过在 MoonBit 侧实现跳板函数（trampoline），你无需自行管理闭包的生命周期。

**C 库签名：**
```c
void register_callback(void (*callback)(void*), void *data);
```

**MoonBit 封装层：**
```moonbit
extern "c" fn register_callback_ffi(
  call_closure : FuncRef[(() -> Unit) -> Unit],
  closure : () -> Unit
) = "register_callback"

pub fn register_callback(callback : () -> Unit) -> Unit {
  register_callback_ffi(fn(f) { f() }, callback)
}
```

**工作原理：**
- 第一个参数是一个闭合函数（无捕获变量），该函数接收一个闭包并调用它；
- 第二个参数是你想要传递的实际闭包；
- C 函数会将 data 参数传入你的闭合函数，这一过程实际上完成了部分应用（partial application）；
- 该方式适用于所有支持回调数据的 C API（例如：`void *user_data`、`void *ctx`、`void *payload` 等参数）。

**带参数的示例：**
```moonbit
// C signature: void process_items(int (*callback)(void*, int), void *data);
extern "c" fn process_items_ffi(
  call_closure : FuncRef[(Int -> Int, Int) -> Int],
  closure : Int -> Int
) = "process_items"

pub fn process_items(callback : Int -> Int) -> Unit {
  process_items_ffi(fn(f, x) { f(x) }, callback)
}
```

## 仅含函数指针的情况

对于仅接收函数指针的回调 API，应使用 `FuncRef[(...) -> ReturnType]` 而非闭包。

**C 侧代码：**
```c
void (*signal(int sig, void (*func)(int)))(int);
```

**MoonBit 侧代码：**
```moonbit
pub extern "c" fn signal(
  signal : Int,
  callback : FuncRef[(Int) -> Unit]
) -> FuncRef[(Int) -> Unit] = "moonbit_signal"
```

总结：普通函数引用使用 `FuncRef`；当回调函数需要捕获状态时，使用“闭包作为回调”的模式。

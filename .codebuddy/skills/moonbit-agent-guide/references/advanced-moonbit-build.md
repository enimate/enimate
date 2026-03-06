## 条件编译

在`moon.pkg.json`中指定特定的后端/模式：

```json
{
  "targets": {
    "wasm_only.mbt": ["wasm"],
    "js_only.mbt": ["js"],
    "debug_only.mbt": ["debug"],
    "wasm_or_js.mbt": ["wasm", "js"], // 适用于 wasm 或 js 后端
    "not_js.mbt": ["not", "js"], // 适用于非 js 后端
    "complex.mbt": ["or", ["and", "wasm", "release"], ["and", "js", "debug"]] // 更复杂的条件
  }
}
```

**可用条件：**

- **后端**：`"wasm"`、`"wasm-gc"`、`"js"`、`"native"`
- **构建模式**：`"debug"`、`"release"`
- **逻辑运算符**：`"and"`、`"or"`、`"not"`

## 链接配置

### 基础链接

```json
{
  "link": true, // 为此包启用链接功能
  // 或者针对复杂场景：
  "link": {
    "wasm": {
      "exports": ["hello", "foo:bar"], // 导出函数
      "heap-start-address": 1024, // 内存布局
      "import-memory": {
        // 导入外部内存
        "module": "env",
        "name": "memory"
      },
      "export-memory-name": "memory" // 以指定名称导出内存
    },
    "wasm-gc": {
      "exports": ["hello"],
      "use-js-builtin-string": true, // 启用 JS 字符串内置支持
      "imported-string-constants": "_" // 字符串命名空间
    },
    "js": {
      "exports": ["hello"],
      "format": "esm" // 可选值："esm"、"cjs" 或 "iife"
    },
    "native": {
      "cc": "gcc", // C 编译器
      "cc-flags": "-O2 -DMOONBIT", // 编译标志
      "cc-link-flags": "-s" // 链接标志
    }
  }
}
```

## 警告控制

在`moon.mod.json`或`moon.pkg.json`中禁用特定警告：

```json
{
  "warn-list": "-2-29" // 禁用未使用变量（2）和未使用包（29）警告
}
```

**常见警告编号：**

- `1` - 未使用的函数
- `2` - 未使用的变量
- `11` - 部分模式匹配
- `12` - 不可达代码
- `29` - 未使用的包

可执行`moonc build-package -warn-help`查看所有可用警告。

## 预构建命令

将外部文件嵌入为 MoonBit 代码：

```json
{
  "pre-build": [
    {
      "input": "data.txt",
      "output": "embedded.mbt",
      "command": ":embed -i $input -o $output --name data --text"
    },
    ... // 更多嵌入命令
  ]
}
```

生成的代码示例：

```mbt check
///|
let data : String =
  #|hello,
  #|world
  #|
```

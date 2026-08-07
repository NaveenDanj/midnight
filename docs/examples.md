# Examples

Small, runnable Midnight programs, one per language feature. Save any snippet as `example.mn` and run it:

```bash
zig build run -- run example.mn
```

## Hello, World

```mn
print("Hello, World!");
```

No entry-point function, no imports — the smallest program looks exactly as small as it is.

## Variables and Arithmetic

```mn
var int x = 100;
var int y = 200;
var int total = x + y;

total = total * 2;

print(total);
```

- `var` declares a mutable binding with an explicit type.
- Reassignment (`total = ...`) requires a prior `var` declaration — reassigning a `const` is a compile error.
- Arithmetic operators: `+ - * / %`.

## Constants

```mn
const float PI = 3.14159;
const string GREETING = "hello";

print(GREETING);
```

`const` bindings must be initialized and can never be reassigned.

## Booleans and Comparisons

```mn
var int a = 10;
var int b = 20;

var bool isLess = a < b;
var bool isEqual = a == b;
var bool combined = isLess && !isEqual;

print(combined);
```

Comparison (`< <= > >=`), equality (`== !=`), boolean (`&& ||`), and unary (`- !`) operators all return the expected types — comparisons and equality produce `bool`, boolean operators require `bool` operands.

## String Concatenation

```mn
var string first = "Ada";
var string last = "Lovelace";
var string full = first + " " + last;

print(full);
```

`+` concatenates when both operands are `string`, and performs arithmetic otherwise — there's no separate concatenation operator.

## if / else

```mn
var int score = 72;

if (score >= 90) {
    print("A");
} else {
    print("not an A");
}
```

`else if` chains are written as a nested `if` inside the `else` block, since `else` always takes a block:

```mn
var int score = 72;

if (score >= 90) {
    print("A");
} else {
    if (score >= 70) {
        print("B");
    } else {
        print("C or below");
    }
}
```

## while Loops

```mn
func countdown(int start) int {
    var int current = start;

    while (current > 0) {
        print(current);
        current = current - 1;
    }

    return 0;
}

countdown(3);
```

## Functions and Recursion

```mn
func factorial(int n) int {
    if (n == 1) {
        return 1;
    }

    return n * factorial(n - 1);
}

print(factorial(5));
```

Every function has a fully typed signature and an explicit return type. A bare function call is also valid as a standalone statement:

```mn
func greet() int {
    print("hello");
    return 0;
}

greet();
```

## Arrays

```mn
var int[] values = [1, 2, 3];
var string[] names = ["midnight", "zig"];
var int[] empty_list = [];

print(values[0]);
```

- Array types are written as `T[]` for any type `T`, including struct types.
- Array literals must be homogeneous (every element the same type).
- The empty literal `[]` can initialize any typed array.
- Indexing (`values[0]`) parses and type-checks, but full end-to-end support across every backend is still being completed — see [Language Specification § Known Limits](./language-spec.md#known-limits).

## Structs: Fields and Methods

```mn
struct Person {
    var string first_name;
    var string last_name;

    func greet() string {
        return "Hello, " + first_name + " " + last_name;
    }
}

var Person p = Person{
    first_name = "Ada",
    last_name = "Lovelace"
};

print(p.greet());
```

Struct initializer fields use `=`, not `:`. Fields and methods live in the same declaration — there's no separate header or constructor to write for the common case.

## Structs: Nesting and Member Assignment

```mn
struct Sample {
    var int a;
    var int b;
}

struct Container {
    var string label;
    var Sample sample;
}

var Container c = Container{
    label = "outer",
    sample = Sample{ a = 10, b = 20 }
};

c.sample.a = 99;

print(c.sample.a);
```

Member-access chains (`c.sample.a`) work as both expressions and assignment targets.

## Structs with Arrays

```mn
struct Team {
    var string name;
    var int[] scores;
}

var Team t = Team{
    name = "Falcons",
    scores = [10, 20, 30]
};

print(t.name);
```

## Extern Functions

```mn
extern func midnight_file_exists(string path) bool;

var bool exists = midnight_file_exists("/tmp/example.txt");
print(exists);
```

`extern` declares a function with no Midnight body — its implementation lives in the bundled C runtime (`runtime/`). It's how the standard library modules below are built.

## Imports and the Standard Library

Midnight ships a small standard library under `src/std/`. Import a module by its dotted path and use the structs/functions it exports:

```mn
import "std.io.file";
import "std.io.input";

var File file = File{};
var Input input = Input{};

var string path = "/tmp/example.txt";

if (file.exists(path)) {
    print("file exists");
} else {
    file.write(path, "hello from midnight");
}

var string name = input.readLine();
print(name);
```

Available standard modules today:

| Import path | Provides |
|---|---|
| `std.io.file` | `File` — `read`, `write`, `append`, `exists`, `delete`, `copy`, `move`, `create`, `createDirectory`, `removeDirectory`, `isDirectory`, `isFile`, `size`, `currentDirectory`, `absolute` |
| `std.io.input` | `Input` — `readLine`, `readInt`, `readFloat`, `readBool` |

## A Larger Sample: Nested Loops

Adapted from `src/data/test3.mn`:

```mn
func matrixSum(int size) int {
    var int i = 0;
    var int result = 0;

    while (i < size) {
        var int j = 0;

        while (j < size) {
            result = result + (i * j);
            j = j + 1;
        }

        i = i + 1;
    }

    return result;
}

print(matrixSum(200));
```

## Running Examples

Run any example saved as `example.mn`:

```bash
zig build run -- run example.mn
```

Build without running:

```bash
zig build run -- build example.mn -o /tmp/midnight-build/example
```

Inspect lowered IR:

```bash
zig build run -- run example.mn --emit-ir
```

Inspect generated LLVM IR:

```bash
zig build run -- run example.mn --emit-llvm-ir
```

Programs that `import` standard library modules (`std.io.file`, `std.io.input`) currently resolve against a standard library path baked in at build time (see [Getting Started § Known Limitation: Standard Library Path](./getting-started.md#known-limitation-standard-library-path)) — run them from within a checkout of this repository until that's fixed.

More sample programs, including ones that mix several features together, live in [`src/data/`](../src/data/).

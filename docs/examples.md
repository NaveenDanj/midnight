# Examples

This page collects small Midnight programs that match the current implementation more closely than the older all-in-one samples.

## 1. Minimal Arithmetic

```mn
var int x = 100;
var int y = 200;
var int total = x + y;

print(total);
```

Exercises:

- variable declarations
- arithmetic expressions
- identifier lookup
- print statements

## 2. Function Declaration And Call

```mn
func add(int a, int b) int {
    return a + b;
}

var int total = add(10, 20);
print(total);
```

Exercises:

- typed function declarations
- return statements
- function calls in expression position

## 3. Bare Call Statement

```mn
func greet() int {
    print("hello");
    return 0;
}

greet();
```

Exercises:

- top-level function declaration
- function call as a standalone statement
- print inside a function body

## 4. Recursive Function

```mn
func factorial(int n) int {
    if (n == 1) {
        return 1;
    }

    return n * factorial(n - 1);
}

print(factorial(5));
```

Exercises:

- recursion
- conditional return
- nested function calls

## 5. While Loop With Mutation

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

Exercises:

- while loops
- mutable local variables
- repeated reassignment

## 6. Arrays

```mn
var int[] values = [1, 2, 3];
var string[] names = ["midnight", "zig"];

print(values[0]);
```

Status note:

- array type syntax and array literals are implemented
- homogeneous element checking is implemented
- full array indexing support is still incomplete across the whole compiler, so treat indexing examples as aspirational unless you have already verified them against the current branch

## 7. Struct Initialization And Member Assignment

```mn
struct Sample {
    var int a;
    var int b;
}

struct Person {
    var string first_name;
    var Sample sample;
}

var Person person = Person{
    first_name = "Naveen",
    sample = Sample{
        a = 10,
        b = 20
    }
};

person.sample.a = 99;
print(person.first_name);
```

Exercises:

- struct declarations
- nested struct initialization
- member access and member assignment

## 8. Repository Sample: `src/data/test3.mn`

Current repository sample:

```mn
func matrixBenchmark() int {

    var int size = 200;

    var int i = 0;
    var int j = 0;
    var int k = 0;

    var int result = 0;

    while(i < size) {
        j = 0;

        while(j < size) {
            k = 0;

            while(k < size) {
                result = result + (i * j) + k;
                k = k + 1;
            }

            j = j + 1;
        }

        i = i + 1;
    }

    return result;
}

print(matrixBenchmark());
```

Exercises:

- nested loops
- repeated assignment
- function call inside print

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

Inspect LLVM IR:

```bash
zig build run -- run example.mn --emit-llvm-ir
```

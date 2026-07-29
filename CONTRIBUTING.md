# Contributing to Midnight

First of all, thank you for your interest in contributing to **Midnight**.

Midnight is an experimental systems programming language focused on **clarity, simplicity, predictable performance, and modern compiler design**. The project is still in its early stages, so contributors have the opportunity to influence the language, compiler, runtime, and tooling.

Whether you're fixing a typo, implementing a new language feature, improving diagnostics, or optimizing the LLVM backend, your contributions are appreciated.

---

# Before You Start

Please read the following before opening a Pull Request.

- Read the project philosophy.
- Search existing issues before creating a new one.
- Discuss large language changes in an issue before implementing them.
- Keep pull requests focused on a single feature or bug.
- Ensure the project builds successfully before submitting.

---

# Project Structure

```
midnight/
├── src/
│   ├── lexer/
│   ├── parser/
│   ├── semantic/
│   ├── ir/
│   ├── backend/
│   │   ├── llvm/
│   │   └── runtime/
│   └── cli/
│
├── runtime/
│   ├── string.c
│   ├── file.c
│   └── ...
│
├── docs/
├── examples/
└── tests/
```

---

# Development Setup

## Requirements

- Zig (latest supported version)
- LLVM
- Clang
- Git

Clone the repository

```bash
git clone https://github.com/<your-org>/midnight.git
cd midnight
```

Build

```bash
zig build
```

Run

```bash
zig build run -- run examples/hello.mn
```

---

# Coding Style

## Zig

Follow the Zig standard library style whenever possible.

- Prefer explicit code over clever code.
- Keep functions small.
- Avoid unnecessary allocations.
- Prefer early returns.
- Minimize nesting.
- Use descriptive names.

Example

Good

```zig
if (node == null)
    return error.InvalidNode;

const value = try resolve(node.?);
```

Bad

```zig
if (node != null) {
    ...
}
```

---

## Runtime (C)

The runtime should remain minimal.

It should only contain functionality that cannot reasonably be implemented in Midnight itself.

Examples include

- Memory allocation
- File I/O
- Console I/O
- Operating system interaction
- Networking
- Threads
- Time

Do **not** implement language features in C that can be written in Midnight.

---

# Language Philosophy

When contributing new language features, always ask:

- Does this reduce complexity?
- Is the syntax obvious?
- Is it beginner friendly?
- Can the compiler optimize it well?
- Does it introduce hidden behavior?

Features should be:

- Explicit
- Predictable
- Easy to learn
- Easy to compile

Avoid adding syntax solely because another language has it.

---

# Pull Requests

Before submitting:

- [ ] The project builds successfully.
- [ ] New code is documented.
- [ ] Existing tests pass.
- [ ] New functionality includes tests.
- [ ] No unnecessary formatting changes.
- [ ] Commit history is clean.

Please keep pull requests focused.

Instead of

> "Parser rewrite + new syntax + optimizer improvements"

prefer

> "Implement struct field initialization"

---

# Commit Messages

Use concise commit messages.

Examples

```
feat(parser): add struct initialization

feat(runtime): implement file reading

fix(lexer): handle escaped strings

fix(ir): preserve resolved types

refactor(llvm): simplify function lowering

docs: update language specification
```

---

# Reporting Bugs

When reporting a bug, please include:

- Midnight version
- Operating system
- Zig version
- LLVM version
- Example source code
- Expected output
- Actual output

Small reproducible examples are greatly appreciated.

---

# Feature Requests

Before requesting a feature, consider whether it aligns with Midnight's philosophy.

A feature request should explain:

- The problem being solved.
- Why existing features are insufficient.
- The proposed syntax.
- Why the proposal is simple and consistent.

---

# Testing

Whenever possible, add a test demonstrating the change.

Examples include:

- Lexer tests
- Parser tests
- Semantic analysis tests
- LLVM backend tests
- Runtime tests

Regression tests are encouraged for bug fixes.

---

# Areas Where Help Is Needed

Contributions are welcome in many areas, including:

- Language design
- Parser improvements
- Type checker
- LLVM backend
- Optimizer
- Runtime library
- Standard library
- Diagnostics
- Error messages
- Documentation
- Examples
- Testing
- IDE support
- Language Server Protocol (LSP)
- Formatter
- Package manager (future)

---

# Code Reviews

Reviews focus on:

- Correctness
- Simplicity
- Maintainability
- Performance
- Consistency with the language philosophy

Feedback is intended to improve the project and is not a reflection of the contributor.

---

# License

By contributing to Midnight, you agree that your contributions will be licensed under the project's license.

---

# Thank You

Every contribution—whether it's fixing a typo, improving documentation, reporting a bug, or implementing a major feature—helps move Midnight forward.

Thank you for being part of the project.

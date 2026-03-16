# Midnight — README

> **Midnight** — a small, personal compiler project / toy language.  
> Current focus: frontend (parser + AST) and semantic analysis, with plans to eventually target GPU compute IR (SPIR-V) and backends.

---

## What this repo is
Midnight is a hobby compiler for a small systems-style language (functions, structs, control flow). It’s meant to be a learning project and an experiment in compiler design — written in Zig and built by doing things the long, educational way. Expect lots of tiny refactors, embarrassing bugs, and a growing sense of pride when `parse()` finally stops crashing.

---

## Current status (what’s done)
Short version: the compiler understands code structure, types, scopes, and basic structs. It will *judge* your programs now — mercilessly.

- Parser / Lexer: ✅ working  
- AST node definitions & allocation: ✅ done  
- Pratt expression parser (precedence): ✅ done  
- Identifiers, literals, binary expressions: ✅ done  
- Statements: `if`, `while`, `return`, `block`, `var/const`, function declarations: ✅ done  
- Scope stack & symbol table: ✅ done  
- Semantic analyzer (basic): ✅ done  
  - Expression type evaluation (int/float/bool/string)  
  - Type compatibility checks  
  - Variable declaration checks  
  - While/if statement semantic checks  
  - Function declaration scanning and local scope checks  
- Structs (parser + AST): ✅ done  
  - Struct properties (var/const) and methods parsed into AST
- Dev conveniences: zig build integration, useful debug printing during parsing

---

## What’s next (short-term milestones)
These are the next concrete items I will implement (in this order):

1. **Return statement validation** — ensure functions return the declared type on every path.  
2. **Assignment semantics** — `x = expr` checks (existence, mutability, type).  
3. **Function call semantic checks** — check callee, param count/types, propagate return type.  
4. **Struct semantics & usage**  
   - register struct types in the type table  
   - inject `this`/self in method scopes  
   - member access (`user.age`) and method call checking (`user.getAge()`)  
5. **Complete expression typing** — unary ops, function-call expressions, member expressions.  
6. **Full typed-AST (every expression annotated with resolved type)**  
7. **Design minimal IR and lowering** — small SSA-like IR for codegen / later optimizations

---

## Long-term / nice-to-have (stretch goals)
- Generate GPU compute via **SPIR-V** (emit SPIR-V assembly and run through a driver).  
- Run shader pipeline through **Vulkan compute dispatch**.  
- Optionally target **LLVM** for CPU paths.  
- Investigate ideas from GPU DSLs such as **Taichi** and **Triton** for inspiration.  
- Tooling: better error messages (line/column + snippet), tests, CI.

---

## How to build & run (developer notes)

Minimal requirements:
- Zig (used version: 0.15.x in development)  
- A terminal, patience, coffee

Build & run (repo root):

```bash
zig build run
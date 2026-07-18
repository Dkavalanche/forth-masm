# Forth MASM x86 Project Skill

## Purpose

Use this skill to continue, maintain, debug, and extend the user's 32-bit Windows Forth interpreter written in clean modern MASM for Visual Studio 2019.

The project is educational and should remain understandable, incremental, and easy to test. Preserve all working behavior unless the user explicitly asks for a redesign.

## Project identity

- Project: Forth interpreter for Windows x86 (32-bit) in MASM
- Toolchain: MASM `ml.exe`, Visual Studio 2019, Win32 console
- Syntax: `.386`, `.model flat, stdcall`, `option casemap:none`
- Platform: Windows x86, 32 bits
- Long-term intention: finish a solid x86 implementation before considering x64

## Current validated state

The following features are implemented and have passed user tests:

### Core runtime

- Win32 console input/output through `GetStdHandle`, `ReadConsoleA`, `WriteConsoleA`, `ExitProcess`
- Token parser
- Input normalization to lowercase
- Static linked dictionary
- Minimal dynamic dictionary
- Data stack
- Threaded execution using dictionary execution tokens
- Colon definitions with `:` and `;`
- Compiled literals through internal word `lit`
- Colon runtime through `do_colon`

### Arithmetic

- `+`
- `-`
- `*`
- `/`

### Comparisons

- `=`
- `<`
- `>`
- `0=`
- `0<`
- `0>`

True is represented as `-1`; false is represented as `0`.

### Data-stack words

- `dup`
- `drop`
- `swap`
- `over`
- `depth`

### Output and utilities

- `.`
- `.s`
- `clear`
- `words`
- `quit`

`.s` prints the stack in the form:

```text
[ 1 2 3 ]
```

### Memory words

- `constant`
- `variable`
- `@`
- `!`

Dynamic constant and variable dictionary entries use four cells:

```text
[link][name_ptr][code_ptr][value_or_address]
```

Important: when creating a dynamic constant or variable, the dictionary head must point to the true start of the 16-byte entry. The validated calculation is equivalent to:

```asm
mov eax, ebx
sub eax, 16
mov last, eax
mov here, ebx
```

Do not reintroduce the incorrect `here - 12` calculation. That corrupts `last` and causes hangs during later dictionary searches.

### Conditional control flow

Internal runtime words:

- `0branch`
- `branch`

Compile-time control words:

- `if`
- `else`
- `then`

Branches currently use absolute addresses stored in compiled cells.

### Loops

- `begin`
- `until`
- `again`
- `while`
- `repeat`

Validated forms include:

```forth
begin ... condition until
```

```forth
begin ... again
```

```forth
begin condition while ... repeat
```

### Early exit

- `exit`

`exit` terminates the currently executing compiled word. It has passed tests inside conditionals and loops.

## Most recent validated source

The most recent known-good source filename is:

```text
forth_while_repeat.asm
```

It includes `while` and `repeat`, and all reported tests passed.

## Required source header

Every complete MASM source file generated for this project must begin with an updated comment header before `.386`.

Use this structure:

```asm
; =========================================================
; Proyecto: Intérprete Forth para Windows x86 (32 bits) en MASM
; Archivo : <current filename>
; Estado  : <current state>
;
; Incluye:
;   - <complete list of implemented feature groups>
;
; Cambios recientes:
;   - <changes introduced in this version>
;
; Notas:
;   - <important implementation details and limitations>
;
; Próxima etapa prevista:
;   - <next agreed development step>
; =========================================================

.386
```

The header must always match the actual source. Do not leave stale next-step notes.

## Development rules

1. Work from the latest validated source, not from an older reconstruction.
2. Preserve every feature already confirmed by the user.
3. Add one coherent feature block at a time.
4. Prefer simple, explicit MASM over abstraction that hides the execution model.
5. Keep dictionary entries and threaded-code layout consistent.
6. Preserve registers where required by callers.
7. Do not silently change Forth stack effects.
8. Compile-time words such as `if`, `else`, `then`, `begin`, `until`, `again`, `while`, and `repeat` must execute during compilation rather than being compiled as ordinary runtime words.
9. Reset compile-control state on compilation failure.
10. When a bug can corrupt the dictionary, inspect `last`, `here`, entry size, and link fields first.
11. When a loop appears to hang, distinguish an intentional infinite `again` loop from a compiler or dictionary bug.
12. Keep answers in Spanish unless the user asks otherwise.

## Known architectural data

Typical runtime/compiler variables include:

```asm
state           dd 0
here            dd OFFSET dict_space
name_here       dd OFFSET name_space
data_here       dd OFFSET data_space
current_def     dd 0
ip              dd 0
compile_stack   dd 128 dup(0)
compile_sp      dd 0
last            dd OFFSET <latest_static_word>
```

Static dictionary entry layout:

```text
[link][name_ptr][code_ptr]
```

Compiled colon body begins after the 12-byte dynamic header:

```asm
lea ebx, [edi+12]
mov ip, ebx
```

Compiled words are sequences of execution-token addresses and inline data cells where needed.

## Regression tests

Run relevant tests after every modification. At minimum, preserve these behaviors.

### Basic colon definitions

```forth
: cinco 5 ; cinco .
```

Expected: `5`

```forth
: doble dup + ; 5 doble .
```

Expected: `10`

### Constants and variables

```forth
10 constant diez
diez .
```

Expected: `10`

```forth
variable x
123 x !
x @ .
```

Expected: `123`

### Conditional flow

```forth
: test1 0 if 111 else 222 then ;
test1 .
```

Expected: `222`

```forth
: test2 1 if 111 else 222 then ;
test2 .
```

Expected: `111`

```forth
: abs dup 0< if -1 * then ;
-5 abs .
5 abs .
```

Expected: `5`, then `5`

### Begin/until

```forth
variable contador
: cuenta 0 contador ! begin contador @ 1 + dup . dup contador ! 5 = until ;
cuenta
```

Expected output:

```text
1
2
3
4
5
```

### Exit

```forth
: ejemplo 10 . exit 20 . ;
ejemplo
```

Expected: only `10`

### While/repeat

```forth
: contar 0 begin dup 5 < while 1 + dup . repeat drop ;
contar
```

Expected output:

```text
1
2
3
4
5
```

### Dictionary integrity

After adding dynamic words and compiled definitions:

```forth
words
```

must list all entries and return without hanging.

## Debugging checklist

When the program hangs:

1. Identify whether the hang occurs while parsing, compiling, dictionary lookup, or executing a word.
2. Run `words` if possible to test dictionary integrity.
3. Inspect the newest dynamic entry and verify its link, name pointer, code pointer, and total size.
4. Verify `last` points to the entry's link field.
5. Verify `here` points immediately after the complete entry or compiled body.
6. Verify compile-stack push/pop balance for nested control structures.
7. Inspect branch placeholders and patched absolute targets.
8. Verify `ip` advances past inline target cells when a branch is not taken.
9. Check whether `again` intentionally produced an infinite loop.
10. Re-run all regression tests after the fix.

## Output expectations

When the user asks for a complete source:

- Generate the entire `.asm` file.
- Include the required updated header.
- Provide a downloadable file link.
- Summarize only the newly added behavior.
- Provide exact Forth commands and expected outputs for validation.
- Do not claim assembly success unless `ml.exe` was actually run.

When modifying an existing source supplied by the user, preserve their formatting and banner where practical while updating the required project header accurately.

## Recommended next steps

No next step is permanently fixed. At the start of a future session, ask or infer the next feature from the conversation. Plausible future additions include:

- return stack: `>r`, `r>`, `r@`
- counted loops: `do`, `loop`, `+loop`, `i`
- additional stack words: `rot`, `nip`, `tuck`, `2dup`, `2drop`
- logical words: `and`, `or`, `xor`, `invert`
- richer error handling for stack underflow, division by zero, malformed control structures, and dictionary-space exhaustion
- decompiler or `see`
- comments and string literals
- file loading or source inclusion

Choose only one coherent block at a time and update the source header accordingly.

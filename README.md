# An Ada Parser in UCI Lisp (1981)

This repository holds a small parser for the Ada programming language that I wrote in January 1981, as an undergraduate at UC Irvine. It ran on the university's DEC PDP-10 under TOPS-10, written in **MLISP** (an ALGOL-like surface syntax for Lisp) on top of **UCI Lisp**. The core was written over a single weekend.

The files were recovered in 2026 from old PDP-10 backup tapes. Everything in [`original/`](original/) is exactly as it came off the tape. Nothing has been edited, not even the typos.

— Stephen Clarke-Willson (then Steve Willson)

## What it is

The program takes a grammar for Ada, written as plain Lisp data, and a program written as a list of tokens, and it prints the parse tree. There is no code generation step. The parser reads the grammar rules while it runs and follows them directly.

A session from January 19, 1981 (in [`original/DSKLOG.LOG`](original/DSKLOG.LOG)) shows it parsing `A + B * C` and printing:

```
SIMPLE-EXPRESSION
  TERM / FACTOR / PRIMARY / NAME / IDENTIFIER / A
  ADDING-OPERATOR +
  TERM
    FACTOR ... B
    MULTIPLYING-OPERATOR *
    FACTOR ... C
```

Operator precedence comes for free from the way the grammar is layered (an expression is made of terms, a term of factors), so `B * C` binds tighter than the `+`.

## Historical context

In 1980 Ada was brand new. The U.S. Department of Defense had picked it as its standard language in 1979, and the reference manual was still changing; the first ANSI standard didn't arrive until 1983. Tools for it were scarce, and a big open question was what an Ada *programming environment* should look like. My class paper from the same month ([`original/ENVIRN.RNO`](original/ENVIRN.RNO), readable copy in [`docs/ENVIRN.md`](docs/ENVIRN.md)) compares the Ada environment requirements with what UCI Lisp already offered: an interactive read-eval-print loop, a structure editor, and data you could inspect while the program ran.

The parser was partly an experiment in that direction: could a Lisp system digest Ada interactively?

## How it works

### The grammar is data

[`GRAMMA.LSP`](original/GRAMMA.LSP) contains about 140 Ada grammar rules. Each one is stored on the property list of its rule name:

```lisp
(DEFPROP SUBTYPE-INDICATION
   ((NAME RANGE-CONSTRAINT) ! (NAME ACCURACY-CONSTRAINT) ! NAME)
   GRAMMAR)
```

The rule bodies use a small EBNF vocabulary:

| Notation | Meaning |
|---|---|
| `A B C` | sequence: all must match, in order |
| `X ! Y ! Z` | choice: try each in order, the first that matches wins |
| `(^ WORD)` | a reserved word, such as `(^ PROCEDURE)` |
| `(/[ ... /])` | optional: zero or one |
| `(/{ ... })` | repetition: zero or more |
| `;` `:=` `/(` | punctuation tokens (`/` is UCI Lisp's escape character) |
| any other name | another grammar rule |

### The parser walks the grammar

[`PARSER.MLI`](original/PARSER.MLI) is about 130 lines. `PARSE` looks up a rule by name with `GET(name, 'GRAMMAR)`; `PARSE1` matches the pieces of a rule against the input. The input is just a Lisp list of atoms, such as `(PROCEDURE A IS BEGIN A := B ; END ;)`, so the Lisp reader acts as the tokenizer.

Backtracking is almost free. The remaining input is a single pointer into an immutable list, so each function saves that pointer when it starts and puts it back if it fails. Trying the next alternative costs one assignment.

`TOP` is a tiny command loop: `S tokens...` sets the input, typing a rule name parses the input as that rule, a parenthesized form is evaluated as Lisp, and `E` exits.

### In today's terms

This is what we would now call a **PEG (parsing expression grammar) interpreter**, a backtracking recursive-descent parser with ordered choice, driven by a grammar held as data. Bryan Ford gave PEGs their name in 2004. Like any PEG, it has two well-known traits, and the grammar files show me running into both:

1. **Ordered choice hides ambiguity.** The first alternative that succeeds wins, so longer alternatives have to come first (see `SUBTYPE-INDICATION` above).
2. **Left recursion loops forever.** In an earlier snapshot, `NAME` had an alternative that began with `NAME`. The final grammar rewrites it as `IDENTIFIER (/{ NAME-TAIL })`, the textbook fix.

There is no memoization, so the worst case is exponential. On the short test programs it didn't matter.

## How it was built: the weekend

The file dates tell the story.

| Date (1981) | What happened |
|---|---|
| Thu Jan 1 | `A.MLI`: first approach, a *parser generator* that read the grammar and printed one MLISP procedure per rule. Abandoned. |
| Fri Jan 2 | `ADALSP.LSP`: a hand-written mock-up of what Ada translated into Lisp might look like. |
| **Sat–Sun Jan 10–11** | **The pivot.** `READP.MLI` reads the hand-typed grammar (`PROD`) and stores each rule as Lisp data. `GRAMMA.BAK` is the first dump of it. From here on the design is an interpreter, not a generator. |
| Mon Jan 19 | `DSKLOG.LOG`: a recorded session with three successful parses. |
| Wed Jan 21 | `ENVIRN.RNO`: the class paper. |
| Thu Jan 22 | Final `PARSER.MLI`, `GRAMMA.LSP` and `BUILD.MIC`; the saved program `GRAMMA.EXE`. |

The grammar went through four snapshots as I fixed it, each with a note on its first line:

- `GRAMMA.AMB`: "AMBIGUOUS GRAMMAR"
- `GRAMMA.NFX`: "STILL NOT COMPLETELY FIXED GRAMMAR"
- `GRAMMA.SAM`: "STILL AMBIGUOUS GRAMMAR"
- `GRAMMA.LSP`: the final one, which the build loads

## Building it (in 1981)

[`BUILD.MIC`](original/BUILD.MIC) is a TOPS-10 batch script. It starts MLISP, enlarges memory, loads the grammar, sets a default test program, translates and loads `PARSER.MLI`, throws away the MLISP translator to shrink the image, and saves the result as `GRAMMA.EXE` (TOPS-10 file names were limited to six characters, so `GRAMMAR` became `GRAMMA`).

Running it today would take a PDP-10 emulator such as SIMH or KLH10 with TOPS-10 and UCI Lisp installed.

## Known quirks

These are left exactly as they were in 1981:

- Choice steps through alternatives two list elements at a time, so each alternative must be a single element. `CHOICE` has an unparenthesized `NAME RANGE-CONSTRAINT` alternative that throws this off.
- `BODY`, `PROGRAM-COMPONENT` and `CHOICE` are each defined twice in `GRAMMA.LSP`; the later definition wins.
- A token counts as punctuation if its first character comes before `A` in ASCII, so `|` is mistaken for a rule name.
- A few misspelled rule names (`TASK-DECLARACTION`, `IDENTIFIR`) never match anything.
- Identifiers and numbers are stubbed: an identifier is `A`, `B` or `C`, and a number is `1` or `2`. There's no real scanner.

## Repository layout

| Path | Contents |
|---|---|
| `original/` | The files exactly as recovered from tape. |
| `docs/` | [`ENVIRN.md`](docs/ENVIRN.md), the class paper converted from RUNOFF to Markdown, and [`walkthrough.md`](docs/walkthrough.md), a detailed walkthrough of the code. |

### Files in `original/`

| File | What it is |
|---|---|
| `PARSER.MLI` | The parser (MLISP) |
| `GRAMMA.LSP` | The final Ada grammar, as Lisp property lists |
| `GRAMMA.AMB`, `GRAMMA.NFX`, `GRAMMA.SAM`, `GRAMMA.BAK` | Earlier grammar snapshots |
| `PROD` | The grammar as first typed in, in BNF-style text |
| `READP.MLI` | Converts `PROD` into Lisp data |
| `A.MLI`, `A.MIC` | The abandoned parser-generator approach, and the batch script that ran it |
| `ADALSP.LSP` | Mock-up of Ada translated into Lisp |
| `CHANGE.MLI` | Unrelated MLISP warm-up (counting ways to make change) |
| `BUILD.MIC` | Build script |
| `GRAMMA.EXE` | The saved TOPS-10 program image |
| `DSKLOG.LOG` | Transcript of a 1981 session |
| `ENVIRN.RNO`, `ENVIRN.MEM` | Class paper: "Comparison of ADA Environment Requirements with UCI Lisp Environment Facilities" (RUNOFF source and formatted output; readable copy in [`docs/ENVIRN.md`](docs/ENVIRN.md)) |

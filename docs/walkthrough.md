# The 1981 Ada Parser in UCI Lisp / MLISP

A detailed walkthrough of the files in [`original/`](../original/), written in 2026 when they were recovered from tape. See the [README](../README.md) for the overview.

## Overview

- **PARSER.MLI interprets the grammar.** GRAMMA.LSP is pure data: about 140 `(DEFPROP rule-name body GRAMMAR)` forms that hang each Ada production on the property list of its rule name. PARSER.MLI never generates code from them. It fetches a rule with `GET(RULENAME,'GRAMMAR)` and walks it at parse time. It is a backtracking recursive-descent interpreter of an EBNF grammar.
- **The GRAMMA.* snapshots are Lisp.** GRAMMA.SAM, for example, is the same kind of `DEFPROP` file as GRAMMA.LSP: a snapshot of the grammar at an earlier stage, listed in reverse order. It is one of three intermediate snapshots, each tagged on line 1 with a note by the author:
  - `GRAMMA.AMB`: "~AMBIGUOUS GRAMMAR"
  - `GRAMMA.NFX`: "~STILL NOT COMPLETELY FIXED GRAMMAR"
  - `GRAMMA.SAM`: "~STILL AMBIGUOUS GRAMMAR"
  - `GRAMMA.LSP` is the final one, with no tag. It's the one BUILD.MIC loads.

  The `~` lines would not read cleanly back into Lisp. They look like the author's annotation marker; NFX also has one inline: `(DEFPROP ATTRIBUTE ...) ~ NOT USED?`.

## What each file is

| File | Date | What it is |
|---|---|---|
| A.MLI | Jan 1 1981 | **The first approach, abandoned:** a translator that read BNF from `PROD` and *printed MLISP source* (`EXPR rule(); IF ... THEN BEGIN SCANTOKEN(); ...`), one procedure per production. A parser generator, not an interpreter. |
| ADALSP.LSP | Jan 2 | A hand-made sample of Ada (a Newton-style square-root loop) written as Lisp `PROG`/`GO` code, with generated-looking labels like `LOOPBEGIN1`/`ENDIF1`. It looks like a mock-up of what an Ada-to-Lisp translator might emit. |
| CHANGE.MLI | Jan 8 | Unrelated MLISP warm-up: counting ways to make change. |
| READP.MLI | Jan 11 | **The pivot.** It reads `PROD` one production at a time, drops the `::=`, and `PUT`s the body on the rule name's property list (spelled `'GRAMMER` here). This is how the grammar became Lisp data. |
| GRAMMA.BAK | Jan 11 | The first dump of that data, still using the property name `GRAMMER`. |
| PROD | Jan 12 | The hand-typed Ada grammar in BNF-ish text (`pragma ::= (/^ Pragma) identifier ...`), from the preliminary Ada reference manual. |
| GRAMMA.AMB / .NFX / .SAM / .LSP | Jan 22 | The successive grammar snapshots described above. |
| PARSER.MLI | Jan 22 | The interpreter: `PARSE`, `PARSE1`, `TPRINT`, `TOP`. |
| BUILD.MIC | Jan 22 | The build script (see below). |
| GRAMMA.EXE | Jan 22 | The saved core image that BUILD.MIC produced (`.SAVE GRAMMAR`, truncated to 6 characters). |
| DSKLOG.LOG | Jan 19 | A transcript of a real session with three successful parses. |
| ENVIRN.RNO/.MEM | Jan 21 | The class paper, "Comparison of ADA Environment Requirements with UCI Lisp Environment Facilities". |
| LOGIN.MIC, LOGOUT.MIC, SWITCH.INI, FMEM.DAT, ACCESS.USR | — | Account housekeeping. `ada:` is path [3345,6] and `tas:` is [3345,1]. |

The weekend: Jan 10–11, 1981 was a Saturday and Sunday. LOGOUT.MIC, READP.MLI and GRAMMA.BAK all date from then, and that is when the design switched from generating code to interpreting data.

## The grammar notation (GRAMMA.LSP)

Each rule body is a Lisp list using a small EBNF vocabulary:

| Form | Meaning | Example |
|---|---|---|
| `A B C` | sequence, all must match | `(NAME := EXPRESSION ;)` |
| `X ! Y ! Z` | ordered alternation, first success wins | `(SUBTYPE-INDICATION ! ARRAY-TYPE-INDICATION)` |
| `(^ WORD)` | reserved word, matched literally | `(^ PROCEDURE)` |
| `(/[ ... /])` | optional, 0 or 1 | `(/[ := EXPRESSION /])` |
| `(/{ ... })` | repetition, 0 or more | `(/{ /, IDENTIFIER })` |
| atom starting below ASCII 65 | punctuation terminal | `;` `:=` `/(` `<>` `=>` |
| any other atom | non-terminal, recurse into its rule | `EXPRESSION` |

`/` is the UCI Lisp escape character, so `/(` is the atom `(` and not a list open.

Lexical classes are stubbed: `IDENTIFIER` is `A ! B ! C`, `NUMERIC-LITERAL` is `1 ! 2`, and `CHARACTER-LITERAL` is `C-LIT`. There is no scanner: the input program is just a Lisp list of atoms that the Lisp reader has already tokenized, for example `(PROCEDURE A IS BEGIN A := B ; END ;)`. That's why the log shows `/,` for a comma.

## How PARSER.MLI works

State is one global, `INPUT-STREAM`, a list of remaining tokens. Each function saves it on entry and **restores it on failure**. That's the whole backtracking mechanism: because the input is an immutable list, "rewinding" is a single pointer assignment.

**`PARSE(rulename)`** handles a named rule:
1. If the name is punctuation (its first character is below `A`), it compares the name to the next token and consumes it on a match.
2. Otherwise it fetches the body with `GET(rulename,'GRAMMAR)`.
3. If `RULE[2]` is `!`, the body is an alternation. It tries `RULE[1]`, and on failure skips two elements (`CDDR`, past the item and its `!`) and tries again. The first success returns `(rulename . subtree)`. If all fail, it restores the input and returns NIL.
4. Otherwise it hands the whole body to `PARSE1` as a sequence and wraps the result as `(rulename . subtree)`.

**`PARSE1(rule)`** handles an anonymous rule fragment:
- **Atom:** if it equals the next token, consume it. If it's punctuation that doesn't match, fail. Otherwise call `PARSE` on it as a rule name.
- **`(^ w)`:** match the reserved word `w`.
- **`(/[ ...)`:** strip the brackets with `PRELIST(CDR RULE, LENGTH-2)` and parse the inside once. If that fails, it still succeeds with the marker `PLACE-HOLDER`.
- **`(/{ ...)`:** the same stripping, then `WHILE` the inside parses, append the result. Zero matches yields `PLACE-HOLDER`.
- **Any other list:** a sequence. Parse each element in turn and append the results. On the first failure, restore the input and return NIL.

The closing `/]` or `}` is never checked; `PRELIST` just drops the last element. That's why the snapshots could be inconsistent about writing `}` versus `/}` and still work.

**Output** is a nested list `(RULE child child ...)`, the concrete parse tree. **`TPRINT`** pretty-prints it with two spaces of indentation per level and hides `PLACE-HOLDER`s. That's the output in DSKLOG.LOG:

```
SIMPLE-EXPRESSION
  TERM / FACTOR / PRIMARY / NAME / IDENTIFIER / A
  ADDING-OPERATOR +
  TERM
    FACTOR ... B
    MULTIPLYING-OPERATOR *
    FACTOR ... C
```

Precedence falls out of the grammar layering (`SIMPLE-EXPRESSION > TERM > FACTOR > PRIMARY`), so `A + B * C` groups correctly.

**`TOP()`** is a little REPL: `S tok tok ...` sets the input, `E` exits to Lisp, a bare rule name parses the input as that rule, and a parenthesized form is `EVAL`ed as Lisp. This is the "own read loop" idea from the ENVIRN paper in miniature.

## Build (BUILD.MIC)

```
R MLISP
(REALLOC ...)                      ; grow memory spaces
(DSKIN GRAMMA)                     ; load the grammar property lists
(SETQ OLD @(PROCEDURE A IS B : C ; BEGIN NULL ; END ;))   ; default test input
(DE RESET NIL (SETQ INPUT-STREAM OLD))
(MLISP PARSER)                     ; translate PARSER.MLI to Lisp and load it
(GC) (EXCISE)                      ; drop the MLISP translator to shrink the image
SAVE GRAMMAR                       ; produces GRAMMA.EXE
```

## What it is, in modern terms

It's an **ordered-choice backtracking parser driven by a data grammar**. That is essentially what's now called a PEG (parsing expression grammar) interpreter, two decades before Bryan Ford named PEGs in 2004. It has the same two properties PEGs have:

1. **Ordered choice hides ambiguity instead of reporting it.** The first alternative that succeeds wins, so `SUBTYPE-INDICATION` is ordered longest-first: `(NAME RANGE-CONSTRAINT) ! (NAME ACCURACY-CONSTRAINT) ! NAME`.
2. **Left recursion loops forever.** This is the clearest story in the snapshots. In GRAMMA.SAM, `NAME` is
   `IDENTIFIER ! SELECTED-COMPONENT ! ATTRIBUTE ! FUNCTION-CALL ! ... ! NAME UNIVERSAL-EXPRESSION-PACK`.
   The last alternative calls `NAME` without consuming a token, so it would recurse forever. In the final GRAMMA.LSP it has been rewritten as `IDENTIFIER (/{ NAME-TAIL })`, with `NAME-TAIL` covering `.x`, `(args)` and `'attr`. That is the textbook left-recursion elimination. Similarly, AMB had separate `LENGTH-SPECIFICATION` and `ENUMERATION-TYPE-REPRESENTATION` rules that both start `FOR x USE ...`; later snapshots merge them into `LENGTH-SPECIFICATION-OR-ENUMERATION-TYPE-REPRESENTATION`.

There's no memoization, so worst-case time is exponential. Each failed alternative re-parses its prefix (for example, `NAME` is reparsed up to three times in `SUBTYPE-INDICATION`). For the short test inputs it didn't matter.

## Quirks and latent bugs

- **Alternation steps by two (`CDDR`)**, so it assumes every alternative is a single element. `CHOICE` in GRAMMA.LSP is `SIMPLE-EXPRESSION ! NAME RANGE-CONSTRAINT ! RANGE ! (^ OTHERS)`. The unparenthesized `NAME RANGE-CONSTRAINT` puts the alternation out of step: it tries `NAME`, then lands on `!` as if it were an alternative. GRAMMA.SAM had this one fixed with parentheses, and LSP reverted it, so the merge kept the older copy.
- **Duplicate rules.** `BODY`, `PROGRAM-COMPONENT` and `CHOICE` are each `DEFPROP`ed twice in GRAMMA.LSP. The later one silently wins.
- **The punctuation test is "first character below `A`".** So `|` (ASCII 124) in `CHOICE-LIST` / `EXCEPTION-HANDLER` would be looked up as a rule name and print "Can't find production for |".
- **A few typo'd rule names** never resolve: `TASK-DECLARACTION`, `IDENTIFIR` (in `ATTRIBUTE-NAME`), and `ARRAY-TYPE-INDICATION`. Each just fails that alternative and prints the "Can't find production" message.
- **`ADALSP.LSP`'s loop** computes `GUESS1 - GUESS1²/(2·GUESS1)`, which never uses `N`. It was a structural mock-up, not working math.

## Bottom line

It is a grammar-as-data, PEG-style recursive-descent interpreter in about 130 lines of MLISP, with free backtracking from immutable list cursors. Left recursion and ambiguity were found and fixed by hand across four grammar snapshots, and the January 19, 1981 log shows it parsing real Ada subprogram bodies.

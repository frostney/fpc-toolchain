# Patches

Applied in name order on `release_3_2_4-branch` at `82947b0d` (rc2 plus 8 commits). Both come unchanged from
`fixes_3_2`.

| patch | upstream | why |
|---|---|---|
| 0001 | `d3f0905b` | A forked child of a threaded program can deadlock converting `TProcess.CurrentDirectory`. lwpt and GocciaScript's compliance runner set it. Unix only. |
| 0002 | `c118291b` | The same deadlock when the child opens `/dev/null` for `poNoConsole`, which lwpt's tests use. Unix only. |

Not carried from `fixes_3_2` (checked with `git cherry` on 2026-10-22): `0c1734db` and `e44e2fd4` touch only
fcl-pdf, which nothing of ours uses; `f6b198e6` is an fcl-pdf example; `043a6603` is a test file; `0eeb544f` is
OS/2 only.

## Candidates

Compiler bugs from the GocciaScript bug hunt that also affect 3.2.4. None of our projects hits them, so none is
carried. If one does, start from the trunk fix in `fpc-toolchain-3.3.1/patches/`.

| bug | effect | switches | trunk fix |
|---|---|---|---|
| F03 | wrong code: shr/sar narrowing in the x86 peephole optimiser | -O1+ | 0011 |
| F09 | rejects valid code: constant propagation overflow | -O3, -O4, inline | 0017 |
| F13 | internal error and wrong code: Abs/Sqr/Sqrt constant type | -O3, -O4 | 0026 |
| F14 | internal error: constref Boolean (fixed in trunk by #39292, #40650) | all | draft |
| F34 | internal error: `(S*[]) = []` on large sets | -O1+ | 0043 |
| F36 | compile failure: `shr 31` / `shl n` assembler bounds | -O1+ | 0045 |
| F37 | rejects valid code: Swap of a signed constant | all | 0046 |
| F38 | wrong code: bitpacked all-ones store with a variable index | all | 0047 |
| F39 | false range error: `{$R-}` Inc/Dec under CONSTPROP with -Cr | -O3 -Cr | 0048 |

For 3.2.4 final, drop the patches the final contains (`git cherry`) and tag `3.2.4-b1`.

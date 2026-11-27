# Experiments and lessons

Record every failed, rejected, or deferred experiment during Stockfish development and later opponent cycles. Include unexpected regressions and setup failures that affect a result. Update the log at each review, while the evidence is available.

For each entry, record the hypothesis or target, the build and test settings, what happened, and what to check before revisiting it. Link to the full benchmark record when available. Keep the original entry when a later attempt succeeds.

## Reduced-strength Stockfish and strict fastchess

The early Stockfish 19 level 0 smoke test used strict fastchess checks. It stopped before completing a game when Stockfish returned a move different from the first move in its reported principal variation. Weak Stockfish settings deliberately make choices like this, so a PV mismatch can stop a valid reduced-strength test.

Use the regular runner mode for reduced-strength Stockfish, record PV mismatch warnings, and independently replay every PGN. Review any other warnings or abnormal endings separately. [Smoke-test record](benchmarks/README.md#checkpoint-3-uci-and-timed-smoke-games)

## Starting at Stockfish levels 7 and 10

The target was a competitive first opponent at `5+0.05`. Frozen step 10 Pandatran played Stockfish 19 on the six evaluation openings with reversed colors, one search thread, and 3 MiB of Stockfish hash. Pandatran scored 16.7% at level 7 (2/0/10 W/D/L) and 4.2% at level 10 (0/1/11). Both were well below the 40–60% pilot range.

Bracket downward and check the selected level on a second opening set before adopting it. [Stockfish calibration](benchmarks/STOCKFISH.md)

## The 256 MiB resident-memory ceiling

The first level 7 and 10 pilots used a provisional 256 MiB sampled RSS ceiling per engine. Stockfish peaked at 373,728 KiB and 366,960 KiB, respectively, so the resource audit failed. Both matches finished, and their PGNs passed independent replay. Use them as scouting results for the level search.

The next batch raised the common audited ceiling to 512 MiB with the same engine binaries, clocks, threads, and hash settings. Set future ceilings after measuring the opponent’s actual process footprint, including its network and working memory. [Stockfish calibration](benchmarks/STOCKFISH.md)

## Levels 0 and 3 were too easy for the first rung

On the same six evaluation openings at `5+0.05`, Pandatran scored 91.7% against level 0 (11/0/1 W/D/L) and 75.0% against level 3 (8/2/2). Both results were above the 40–60% pilot range. The revised memory audit passed.

Together with the level 7 result, these runs bracketed the competitive setting. Test intermediate levels before selecting the first rung. [Stockfish calibration](benchmarks/STOCKFISH.md)

## Levels 4 and 5 missed the target on the first opening set

At `5+0.05` on the six evaluation openings, Pandatran scored 66.7% against level 4 (8/0/4 W/D/L) and 33.3% against level 5 (4/0/8). Both missed the 40–60% pilot range from opposite sides.

Use the other five development openings to check both levels before choosing the first rung. A small adaptive pilot can swing with opening and move-choice variation. [Stockfish calibration](benchmarks/STOCKFISH.md)

Both levels scored 50% on the second set. Across both sets, levels 4 and 5 were equally close to 50% at 59.1% and 40.9%. Level 5 was selected as the stronger opponent.

## Level 5 fell below the target range in the longer pilot

The longer `10+0.1` check against Stockfish level 5 scored 33.3% (3/2/7 W/D/L) on the evaluation six. This was below the competitive range used to select the short-clock opponent. The same six openings also scored 33.3% at the short clock, so the pilot gives limited evidence about a clock effect.

Use the pooled short-clock sample to establish the primary benchmark. Track the longer result separately. If a near-even longer benchmark becomes important, calibrate it directly. [Stockfish calibration](benchmarks/STOCKFISH.md)

## Guarded exchange pruning missed the primary A/B gate

The trial tried to save search on unfavorable captures in quiescence. It cut fixed-depth wall time by 5.1% and passed the tactical checks. At `5+0.05` on the combined 11 opening pairs it scored 45.5% against frozen staged Pandatran (6/8/8 W/D/L), missing the positive head-to-head requirement. The same trial scored 52.3% against Stockfish level 5 on those openings. Its longer head-to-head scored 66.7% across six pairs.

Keep staged quiescence as the accepted baseline. Archive the trial patch, executable, and PGNs. The two A/B scores leave a wide range of plausible effects, and the position spot checks found no clear tactical regression. Before reconsidering adoption, repeat the exact trial at the short clock with a larger set of fresh development pairs. [Full experiment record](benchmarks/STOCKFISH.md#iteration-1-guarded-exchange-pruning)

## Exchange pruning retest ended at the A/B gate

The exact archived trial played 64 fresh color-swapped development pairs at `5+0.05`. It scored 52.0% (54/25/49 W/D/L), with a paired 95% interval of 45.7–58.2%. All 128 games passed replay with zero forfeits. The interval included an even score, so the result fell short of the predeclared promotion gate.

Keep staged quiescence as the accepted engine. The fixed-depth speed gain still holds on its benchmark, and the larger game sample leaves the playing-strength effect unresolved. Test exact move-generation savings next. [Retest protocol and result](benchmarks/STOCKFISH.md#iteration-2-exchange-pruning-retest)

## Pin-aware legality validation missed the timing gate

The trial skipped make and unmake for ordinary moves from unpinned pieces when the moving side was outside check. Legal move order, perft divides, and fixed-work search outputs matched the frozen step 10 engine. Median wall time fell 6.7% on the standard bench and 6.9% across 32 development positions on the M2 Mac. Both workloads missed the predeclared 10% gate. The trial ended before timed games and its patch and executable were archived locally.

The shortcut reduces work for full move lists. Quiescence still builds a full candidate list when it only needs to check whether one legal move exists. Profile that path across both workloads before writing another trial. [Full benchmark record](benchmarks/STOCKFISH.md#iteration-3-pin-aware-legality-validation)

## Early-exit stalemate check deferred beyond 1.0

The probe generates candidates one piece at a time and returns once it finds one legal move. On the M2 Mac it cut median wall time by 13.1% on the standard bench and 10.3% across 32 positions with identical search results. At `5+0.05`, it scored 56.6% against frozen Step 10 Pandatran over 128 development games (61/23/44 W/D/L, paired 95% interval 51.2–62.1%). It scored 54.5% against Stockfish 19 level 5 over 22 games (11/2/9, paired 95% interval 38.6–70.5%). Both matches had zero forfeits.

The trial passed its checks. The 1.0 release candidate is the frozen Step 10 build that directly beat Pandafish v1.0. The shortcut and its regression test were removed from the working tree. The exact patch, tested executable, and match artifacts are archived under `.local/stockfish-legal-probe/` for a later Step 9 iteration. [Full benchmark record](benchmarks/STOCKFISH.md#iteration-4-early-exit-from-the-legal-move-probe)

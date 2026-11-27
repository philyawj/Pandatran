# Stockfish calibration

The [confirmed Pandafish result](CONFIRMATION.md) is the historical benchmark. This pilot finds a competitive external opponent for the next Pandatran development cycle. The engines and time controls stayed fixed across each level comparison. All positions came from the two existing development suites, with each opening played once per color assignment.

## Configuration

| Artifact | Identity |
| --- | --- |
| Pandatran | Frozen step 10 executable, SHA-256 `d43220c05a75e8ff7a9968446efc4bd41a5a4355801d0fbcc5cad09b721d219b` |
| Stockfish | Homebrew Stockfish 19 ARM64, SHA-256 `dc2f18c34ae962dff591b66147d220ec06e61d756b93d8a4f5e04fd8e55c251f` |
| Stockfish network | Embedded `nn-1a298aa575a0.nnue`, SHA-256 `1a298aa575a085434d29027978dc36867fe9c5bcea9376654b7a8eba1e52dfc2` |
| Runner | fastchess 1.8.3-alpha, SHA-256 `3088af5fd26bcf2c1e470351a4e5a39f38464662c50ab5d17af73a22d3caa9c9` |

Both engines ran on the confirmation M2 Mac, one search thread each, with short clock `5+0.05`, zero time margin, no opening assistance, disabled pondering and tablebases, and fresh processes each game. Stockfish used a 3 MiB hash, `MultiPV=1`, and its 10 ms move overhead. Two-second samples audit the common resident-memory ceiling. Each match ran two games concurrently. Two simultaneous comparisons used up to four games on the Mac.

An isolated search from an empty directory verified that the embedded network loaded. Stockfish 19’s `export_net` provided its exact file hash. [Stockfish 19 source](https://github.com/official-stockfish/Stockfish/blob/sf_19/src/uci.cpp)

Start at `Skill Level` 7 and 10 with `UCI_LimitStrength=false`. Use the six [evaluation openings](evaluation.epd) for the initial calibration and aim for a score around 50%, with 40–60% as a practical pilot range. If both initial probes are out of range in the same direction, bracket toward the nearer end of the scale. Check the selected setting on the five [original development openings](development.epd), then measure its behavior at the longer `10+0.1` clock. These are adaptive development pilots. Skill settings identify the measured opponent and clock. [Stockfish strength controls](https://official-stockfish.github.io/docs/stockfish-wiki/Stockfish-FAQ.html#how-do-skill-level-and-uci_elo-work)

Reduced-strength Stockfish can intentionally return a legal move that differs from its reported principal variation. The runner allows that warning and records it. Independent PGN replay checks openings, color assignments, moves, and outcomes. Review additional warnings or abnormal terminations separately.

The level 7 and 10 pilots exceeded the provisional 256 MiB RSS ceiling because Stockfish reached about 365 MiB. Their completed results guided level selection. The subsequent matches use a common 512 MiB sampled ceiling with the same chess settings. Record failed trials and setup issues as they occur. [Experiment failure log](../EXPERIMENTS.MD)

## Short-clock bracket

| Stockfish skill | Openings | Pairs | Pandatran W/D/L | Score |
| --- | --- | ---: | ---: | ---: |
| 7 | Evaluation six | 6 | 2/0/10 | 16.7% |
| 10 | Evaluation six | 6 | 0/1/11 | 4.2% |
| 0 | Evaluation six | 6 | 11/0/1 | 91.7% |
| 3 | Evaluation six | 6 | 8/2/2 | 75.0% |
| 4 | Evaluation six | 6 | 8/0/4 | 66.7% |
| 5 | Evaluation six | 6 | 4/0/8 | 33.3% |
| 4 | Original five | 5 | 5/0/5 | 50.0% |
| 5 | Original five | 5 | 5/0/5 | 50.0% |
| 4 | Combined | 11 | 13/0/9 | 59.1% |
| 5 | Combined | 11 | 9/0/13 | 40.9% |

Levels 0 and 3 scored above the pilot range, and levels 7 and 10 were well below it. The evaluation set bracketed the target between levels 4 and 5. Both scored 50% on the five original openings.

**Start with Stockfish 19 at Skill Level 5.** Across the two short-clock opening sets, both levels were equally close to 50%. Level 5 gives Pandatran the stronger opponent and a starting score of 40.9%. Keep the level, clock, and binary fixed while comparing changes with the last accepted Pandatran build.

The paired 95% resampling intervals on the combined pilot were 36.4–81.8% for level 4 and 18.2–63.6% for level 5. Both are small adaptive samples. The selected level is a practical starting opponent for development.

## Longer-clock check

Level 5 scored **33.3% for Pandatran** on the six evaluation pairs at `10+0.1` (3/2/7 W/D/L). The short clock remains the primary calibration point. Use the longer result as a separate reference for how candidate changes perform at that clock. The same six openings also scored 33.3% at the short clock.

Across the 104 pilot games, independent replay verified all color assignments, openings, outcomes, and 10,554 legal plies. There were zero forfeits. The only runner warnings were Stockfish’s weakened-move PV mismatches. Under the revised 512 MiB audit, Pandatran peaked at 5,520 KiB and Stockfish at 373,792 KiB. The two confirmation samples and remaining reserve were outside this pilot.

## Reproduce a pilot

Use the pinned binaries and a verified empty engine working directory. Run one match per setting. Set `pairs` to the exact row count of the named opening set. Existing runner argument records and warnings are under `.local/stockfish-calibration-01/`.

```sh
GOMAXPROCS=1 "$fastchess" \
  -engine cmd="$pandatran" name=Pandatran "dir=$empty" \
  -engine cmd="$stockfish" "name=Stockfish19-L$level" "dir=$empty" \
    option.Threads=1 option.Hash=3 option.Ponder=false option.MultiPV=1 \
    option.UCI_LimitStrength=false option.UCI_Chess960=false option.SyzygyProbeLimit=0 \
    'option.Move Overhead=10' option.EvalFile=nn-1a298aa575a0.nnue "option.Skill Level=$level" \
  -each "tc=$clock" timemargin=0 restart=on \
  -openings "file=$epd" format=epd order=sequential \
  -rounds "$pairs" -repeat -concurrency 2 -autosaveinterval 2 \
  -config "outname=$results/$match.json" \
  -pgnout "file=$results/$match.pgn" append=false \
  -log "file=$results/$match-warnings.txt" level=warn append=false
```

The local calibration directory also contains the frozen executables, network hash, PGNs, and audit summaries.

| PGN | SHA-256 |
| --- | --- |
| `original-level7.pgn` | `09c3e21031f1e4bf49fb76d3a590482965b9bea270955af398cd4d9692156291` |
| `original-level10.pgn` | `553e16e9f0d673b905341ad85cd9cdcc78b4ba2364960c0235379a232b1799a5` |
| `lower-level0.pgn` | `1303ba5d1ba663cab0d77b6e0e1bd84632f61092983c0fe008ad9f756ebd23e2` |
| `lower-level3.pgn` | `9e977f0f7599845d47c367117a8a03f2981dfde9766f60a8d01c6e35dd17fc3c` |
| `middle-level4.pgn` | `a880cf8a36606ed4d41f1ee9db66b6939351ed9682a19ecd1a158c5af6a2233e` |
| `middle-level5.pgn` | `24f98578e8665cac81e22718c183e5875d3d51b30099c60eefa8d5acbd6ab131` |
| `second-set-level4.pgn` | `eeac0929ae154b30fbd83108d5c5136787a3e90694d8cb980d8079b1b704ced1` |
| `second-set-level5.pgn` | `2ec199ee8aa2af6b1b5e239cb8f00a5f03164012e3473e05618af7aa03944347` |
| `longer-level5.pgn` | `62da8435ef6e6de05194e672523f03dd7a9656f770f578143af54178f91e604a` |

## Iteration 1 guarded exchange pruning

In the level 5 pilot losses, Pandatran typically reported five to six completed plies in the early short-clock game. This experiment asks whether pruning clearly unfavorable local exchanges can return more search for the same clock after the [quiescence move-generation speedup](README.md#step-9-iteration-2-quiescence-move-generation). [Static exchange evaluation](https://chessprogramming.org/Static_Exchange_Evaluation)

The trial starts with staged quiescence. At an out-of-check node with a one-centipawn window outside the mate range, consider a non-pawn, non-king capture away from the promotion ranks. Verify that the move leaves the opponent out of check. Skip it only if the opponent has a legal recapture whose value is low enough that even recovering it for free would still lose at least 80 centipawns in the local exchange. The legality check covers pinned recapturers, and attack masks are recomputed on the board after the capture so they include x-rays. Nodes near a draw claim, already repeated positions, and positions with fewer than four total non-pawn pieces keep the full tactical search. This is a local material bound. Tactics elsewhere on the board can change the value of the move.

Compare the trial, launched with `uci exchange`, with the frozen staged build and the pinned level 5 opponent. Use the combined 11 development openings at `5+0.05` and the evaluation six at `10+0.1`. Run both opponents at a clock with two games per comparison, zero margin, and fresh processes under the established 512 MiB sampled ceiling. Use strict mode in the Pandatran A/B match and allow the documented Stockfish PV mismatch warnings. The adoption test is lower fixed-depth wall time, passing tactical checks, a positive short-clock A/B score, and a short-clock Stockfish score at least as high as the prior 40.9% on these same openings. The longer comparisons look for a reversal or target regression.

### Fixed-depth results

| Depth-six run | Nodes | Median wall time |
| --- | ---: | ---: |
| Frozen staged build | 899,001 | 0.5471 s |
| Trial in `staged` mode | 899,001 | 0.5512 s |
| Trial in `exchange` mode | 813,945 | 0.5191 s |

Seven rotating serial runs per setup gave consistent signatures. The trial pruned 43,415 captures, saved 9.5% of nodes, and cut median wall time by 5.1% against the frozen build. All seven cases returned the same moves, scores, and completed depths. The native fixtures passed for legal pawn and x-ray recaptures, pinned defenders, retained checks, promotions, en passant, and state restoration. The history, staged, and exchange modes agreed on the existing tactical search fixtures. All 40 fastchess UCI checks passed.

On 20 development positions from the recent Stockfish losses, both builds agreed on the move and score at depth four. The trial used 244,298 nodes to the control’s 276,322. A separate depth-four look at eight positions before evaluation drops in the short A/B losses returned the same eight moves, with a maximum score difference of 3 centipawns. These spot checks gave no concrete reason for the head-to-head deficit.

### Timed results and decision

| Trial opponent | Clock | Pairs | Pandatran W/D/L | Score | Forfeits |
| --- | --- | ---: | ---: | ---: | ---: |
| Frozen staged Pandatran | `5+0.05` | 11 | 6/8/8 | 45.5% | 0 |
| Frozen staged Pandatran | `10+0.1` | 6 | 6/4/2 | 66.7% | 0 |
| Stockfish 19 level 5 | `5+0.05` | 11 | 10/3/9 | 52.3% | 0 |
| Stockfish 19 level 5 | `10+0.1` | 6 | 4/1/7 | 37.5% | 0 |

Independent replay checked both colors, legal moves, and endings across all 68 games and 8,617 plies. The runner logged only the expected weakened-move PV warnings. The highest sampled RSS was 374,912 KiB on a Stockfish process, within the shared 512 MiB ceiling.

The Stockfish gains over the calibration baseline were 11.4 points short and 4.2 points longer. Descriptive paired 95% intervals for the gains were −9.1 to +31.8 and −20.8 to +29.2 points. The short A/B interval was 31.8–61.4%, and the longer A/B interval was 45.8–83.3%. The result varies by clock and leaves open whether the filter improves play. Both engines reported nearly identical mean depths in the A/B games.

**Repeat step 9.** Keep the frozen staged build as the accepted baseline. The filter missed the primary head-to-head gate, and its lower fixed-work cost plus the other match results justify a larger A/B repeat at `5+0.05` on fresh development openings. Keep the exact trial binary and its settings for that test. [Experiment failure log](../EXPERIMENTS.MD#guarded-exchange-pruning-missed-the-primary-ab-gate)

The archived `exchange-trial` binary SHA-256 is `589a18a8d248228e29b73f0efe3c99a7d28af00dca3ab560fde0453e24e0b50e`. The source patch SHA-256 is `8b196c903f6a591c141d25a6466b3be24af8f934f154cfe008a30906dd51a2df`. Both, the match arguments, PGNs, and audit output are in `.local/stockfish-exchange-01/`.

| PGN | SHA-256 |
| --- | --- |
| `short-control.pgn` | `27ad9794cf76d574f18baf7da736515ffadade8b728f67a28b626f4d2cd6427d` |
| `longer-control.pgn` | `0d6883e2fbec4696e58f8b1b6b39a1b3d957cd3b4ae0ed9fb4669d0a8d2307ca` |
| `short-stockfish.pgn` | `7ae6c8df6d38cd79d886d6da3389595dde53b5160702981e75403f29956e52ec` |
| `longer-stockfish.pgn` | `45bc5a03b6975c3fd69091ba00b9462375914bdf6794a70d847e8c8ac68058d8` |

## Iteration 2 exchange pruning retest

Retest the archived exchange executable against the frozen staged build. Keep both binaries, the existing margin and legality guards, and the primary `5+0.05` clock fixed. Use 64 fresh, color-swapped opening pairs for a 128-game match. The earlier 11-pair A/B sample put the variance of pair scores near 0.07 on the zero-to-one scale. At that variance, 64 pairs target an improvement of about nine percentage points with roughly 80% power in a normal approximation. The new games determine the outcome of this retest. [Paired match statistics](https://official-stockfish.github.io/docs/fishtest-wiki/Fishtest-Mathematics.html)

Run every pair. The trial advances to a cross-check only if its two-sided paired 95% bootstrap interval clears 50% at the lower endpoint. Resample whole opening pairs using exact convolution of their five possible scores. For the cross-check, both binaries must play Stockfish 19 level 5 at `5+0.05` on the first 32 new pairs with the calibration settings. Require the trial’s score against Stockfish to at least match the staged build on those same openings before promoting it.

Run the A/B test on the same M2 Mac, up to four games at once, one search thread per engine, zero time margin, fresh processes, strict checks, and normal chess endings. Retain the common 512 MiB ceiling monitored by sampled RSS. Use the [first confirmation’s recovery rule](CONFIRMATION.md#runner-and-recovery) for incomplete pairs.

### Fresh development starts

Use the pinned Lichess A–E opening files. Replay named lines ending after 8 to 12 plies with one queen per side and material difference at most 100 centipawns, using pawn/knight/bishop/rook/queen values of 100/320/330/500/900. Consider the four-ply EPD the opening family. Exclude the existing eleven development families and every four-ply family that leads to one of the 104 played confirmation starts in the pinned Stockfish opening book. Reject any candidate that matches a reserve endpoint or a position on a source line leading to a played confirmation start.

Within each eligible family, rank lines by distance from eight plies, then by ply count, ECO, name, and PGN text. Sort families by SHA-256 of `pandatran-exchange-retest-64-v1`, one LF, and the family EPD, with the EPD breaking ties. Use the first 64 families in that order, skipping duplicate endpoints. Filter the remaining confirmation reserve further by dropping any endpoint whose source line reaches a new development EPD or shares one of its four-ply families. Keep the remaining rows in their prior order. [Pinned Lichess source](https://github.com/lichess-org/chess-openings/tree/48a8c0e733facfdc9a3723fe882e51ec28014074) · [Pinned Stockfish opening book](https://github.com/official-stockfish/books/tree/2ec69181c0b1367c5c58bcf5304a79c7b198b655)

There were 78 eligible four-ply families. The [64 selected starts](exchange-retest.epd) have SHA-256 `d833da9ff820e58fd9a08d8b6133b3aadf617aac036f52c9f81940b9c5b41f5a`. The updated confirmation reserve excluded 2,316 endpoints, leaving 18,678 rows with SHA-256 `bcc9d9bb0ef265b2eaef3ec7c027280e5df96cc0b6d7b871cab8f03e0beaac8d`. Use `.local/stockfish-exchange-retest/reserve-after-exchange-retest.epd` as the starting pool for subsequent confirmations. The original Pandafish results and their archived inputs keep their original hashes.

The saved protocol snapshot has SHA-256 `f66656fc7cb61e30b1df4f20f23c0387bc74967fdab2d05df0d83cfdf4432f5d`. The snapshot, ranked source lines for the chosen starts, exact runner arguments, and RSS samples are under `.local/stockfish-exchange-retest/`.

### Results and decision

| Pairs | Trial W/D/L | Points | Score | Paired 95% interval | Forfeits |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 64 | 54/25/49 | 66.5/128 | 52.0% | 45.7–58.2% | 0 |

The five pair-score counts from zero to two points were `[4, 11, 34, 6, 9]`. Independent PGN replay verified all color assignments, opening starts, and 16,034 plies through their chess-rule endings. The match took 7m 15s and exited successfully. Peak sampled RSS was 5,312 KiB for the trial and 5,328 KiB for the control. Both engines reported median depth six and median move time 83 ms.

The archived filter missed the predeclared A/B gate because the interval includes 50%. The staged engine stays the accepted build. The time reduction at fixed depth from iteration 1 did not produce a resolved game-score gain in the larger retest. The iteration ended at its head-to-head gate. [Experiment failure log](../EXPERIMENTS.MD#exchange-pruning-retest-ended-at-the-ab-gate)

**Repeat step 9 with a different experiment.** Next, test whether move generation can validate safe unpinned moves outside check without making and undoing each one. Require exact legal-move ordering, perft, and fixed-work search signatures before timing it. This targets work that every search uses and gives a direct correctness test.

The `match.pgn` SHA-256 is `2a02d90832da3d94e7377016ec289af021f95e1e23c5811c2201734a03b13d42`. Use `match-argv.json` for the invocation and `match-summary.json` for the audited score and interval. The exact trial and control binaries are the ones listed in the first iteration and calibration records.

## Iteration 3 pin-aware legality validation

An untimed `bench 8` sample of the frozen engine on the M2 Mac put candidate generation, piece target calculation, and making and unmaking moves among its most frequent leaf frames. Some of that work comes from checking whether a candidate leaves its own king in check. The trial identifies checking pieces and pinned origins once per full move list. When the king is safe and an ordinary move leaves an unpinned square, destination occupancy is preserved and there is no need to make and unmake the move to check the king. The existing validator handles king moves, potential en passant, pinned pieces, positions in check, and tactical-only lists. [Chessprogramming Wiki on move generation](https://chessprogramming.org/Move_Generation) · [Chessprogramming Wiki on pins](https://chessprogramming.org/Pin)

Require native tests, UCI compliance, agreement with independent legality oracles, and byte-for-byte ordered perft divides against the frozen control. Require identical results from the standard depth-six benchmark and identical depth, nodes, score, and principal variation across 32 development positions searched at depth five with a 30,000-node cap. Run seven serial timings per build for each workload in alternating order on the M2 Mac. Proceed to timed games only if the trial cuts median wall time by at least 10% on both workloads. Use the first 32 positions in [the exchange retest development set](exchange-retest.epd) for the broad workload.

If the timing gate passes, run 32 color-swapped pairs against frozen step 10 Pandatran using the same 32 openings and 11 against calibrated Stockfish level 5 using the combined original and evaluation opening sets. Both use `5+0.05`, one search thread per engine, zero clock margin, restarted engines, and the common 512 MiB sampled process ceiling. Require legal PGN replay, zero forfeits, a positive short-clock score against frozen Pandatran, and a score of at least the frozen engine’s 40.9% against Stockfish on the same calibration openings before keeping the change. These short matches screen the candidate for further development.

### Results and decision

Debug, release, and Fortran runtime-checked tests passed, including new pin fixtures. All 40 fastchess UCI checks passed. Ordered perft output matched the frozen build on six canonical positions, eight edge cases, and 432 positions sampled from seeded legal games. Stockfish agreed on the per-move node counts for the canonical and edge cases. Python-chess agreed on all sampled per-move counts. Both fixed-work benchmarks matched all required search outputs.

| Workload | Frozen median | Trial median | Wall time saved | Gate |
| --- | ---: | ---: | ---: | ---: |
| Standard `bench 6` | 547.2 ms | 510.3 ms | 6.7% | 10% |
| 32-position UCI batch | 683.4 ms | 636.6 ms | 6.9% | 10% |

The iteration ended at the timing gate before timed games. The source was restored and checked against the frozen step 10 playing-source manifest. The result measures throughput on the two workloads. Stockfish level 5 stays the development target. The confirmation reserve was untouched. [Experiment failure log](../EXPERIMENTS.MD#pin-aware-legality-validation-missed-the-timing-gate)

**Repeat step 9.** First profile the quiescence stalemate check across both workloads. `has_legal_move` accounted for 361 of 1,618 main-thread sample stacks in the untimed depth-eight run, including its callees. It builds every pseudo-legal move before checking for the first legal one. If the cost holds across both workloads, test stopping candidate generation as soon as one legal move is found, preserving exact stalemate and draw behavior. Keep the same two-workload timing gate before spending time on matches.

The trial binary has SHA-256 `4b400ac7e6ac01fd618568681c3c80981830408cb20db2f4bd3f7a41f54661aa`. The patch, source manifest, profiler output, timing driver, raw timings, and correctness logs are under `.local/stockfish-pin-validation/`.

## Iteration 4 early exit from the legal-move probe

Repeated profiling of the frozen build put `has_legal_move` and its callees in 376 of 1,619 samples of the native `bench 8` run and 114 of 501 non-poll samples of the 32-position UCI workload. Quiescence calls this probe to detect stalemate. The current implementation generates the entire pseudo-legal list even when one of the first candidates is legal. Generate one piece’s candidates at a time and return on the first legal move. Share candidate generation and legality checks with the existing full generator so castling, en passant, promotions, and king safety follow the same rules.

Require native tests, independent legality checks, UCI compliance, identical ordered perft output, and identical fixed-work search results. Keep iteration 3’s 10% wall-time savings gate on both workloads and the same seven alternating repeats per build. Use the same frozen step 10 build, M2 Mac, and 32 development positions.

After the timing gate, play 64 color-swapped pairs against frozen Pandatran on the full exchange retest development set at four games concurrently. Follow with 11 pairs against the calibrated Stockfish 19 level 5 on the original calibration openings at two games concurrently. Use `5+0.05`, one search thread per engine, zero clock margin, restarted processes, and the common 512 MiB sampled ceiling. Audit every game. Keep a reproducible exact speed improvement if the games pass replay and resource checks with zero forfeits and the paired 95% intervals do not show a regression against 50% head to head or the prior 40.9% Stockfish development score. Report any game-strength gain separately. A head-to-head interval that includes 50% leaves playing strength unresolved. Keep the confirmation reserve separate.

### Correctness and speed

Debug, release, and runtime-checked native tests passed, including an en passant position with exactly one legal move. An independent python-chess oracle agreed with the early-exit probe on 2,595 positions, including ten positions with no legal moves. The probe preserved board state, occupancy, and hash. All 446 ordered divides matched the frozen engine, and fastchess passed all 40 UCI compliance checks. Both timing workloads gave identical fixed-work outputs.

| Workload | Frozen median | Trial median | Wall time saved | Gate |
| --- | ---: | ---: | ---: | ---: |
| Standard `bench 6` | 545.1 ms | 473.5 ms | 13.1% | 10% |
| 32-position UCI batch | 681.3 ms | 611.4 ms | 10.3% | 10% |

The trial cleared both timing gates. The tested executable has SHA-256 `12a5d94c92872b2f101b157df7b8639102ba3e257e5e7209631c1d3840ce66c3` and the protocol snapshot has SHA-256 `515a1238d7d7759795f8c482330937fb1aeb2576e32b3f5b4652dabb797286bf`. The patch, source manifest, profiles, timing samples, and correctness logs are in `.local/stockfish-legal-probe/`.

### Timed games and decision

| Opponent at `5+0.05` | Opening pairs | Trial W/D/L | Points | Score | Paired 95% interval | Forfeits |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Frozen step 10 Pandatran | 64 | 61/23/44 | 72.5/128 | 56.6% | 51.2–62.1% | 0 |
| Stockfish 19 level 5 | 11 | 11/2/9 | 12/22 | 54.5% | 38.6–70.5% | 0 |

Independent replay checked the opening, color, legal moves, and chess-rule ending of each game across 18,786 plies. From zero to two points, the five pair-score counts were `[2, 5, 39, 10, 8]` against frozen Pandatran and `[1, 1, 6, 1, 2]` against Stockfish. The head-to-head produced no warnings. Stockfish produced 684 expected weak-move principal-variation warnings. Peak sampled RSS was 5,488 KiB for the trial, 5,248 KiB for frozen Pandatran, and 373,856 KiB for Stockfish.

The early-exit probe cleared the correctness and throughput gates and won the timed head-to-head on the development set. On the calibration openings, the Stockfish score rose from the prior 40.9% to 54.5%. The 22-game sample remains too small to establish a lead against level 5.

**Defer adoption to a later Step 9 iteration.** The 1.0 release candidate is the original Step 10 build that directly beat Pandafish v1.0. The probe and its regression test are archived for a later development cycle. If revisited, use the exact trial build for a larger level 5 match on development openings at `5+0.05`. The confirmation reserve was untouched. [Experiment log](../EXPERIMENTS.MD#early-exit-stalemate-check-deferred-beyond-10) · [Pandafish confirmation](CONFIRMATION.md#results)

The head-to-head PGN has SHA-256 `a73d26bd93895390ca593b406a6f414857d458efd1793de72e513cad96a3ffd3`. The Stockfish PGN has SHA-256 `5642b0811ff5e258b8004ac812b39877cd1625b699664682853e2093ee179ff0`. Exact arguments, PGNs, resident-memory samples, and audit summaries are in `.local/stockfish-legal-probe/`.

# Benchmark setup

## Checkpoint 1 baseline

The frozen opponent is Pandafish v1.0 at commit `27a34937c2aaee23d6e22bf60cee9b0075c16ad6`. The release manifest records Go 1.25.0, `-trimpath` and `-buildvcs=false`. Both archives match the release’s `SHA256SUMS`, and both extracted executables match its build manifest. The macOS binary responded with `id name Pandafish v1.0`, `uciok` and `readyok`. The Linux binary was verified by hash on the Mac. [Pandafish v1.0 release](https://github.com/philyawj/Pandafish/releases/tag/v1.0)

| Target | Archive SHA-256 | Executable SHA-256 |
| --- | --- | --- |
| macOS ARM64 | `748186191f256b98a7e85d88a1aadbdcc661f8752b64b4a307ead61dfc6f281b` | `085346c77e8d4e0040a9002e4182714a9ff3cab950b6ed4e88b654ffa01624e3` |
| Linux ARM64 | `ca1d4bca963b9721a33318808ecea559ce3bc924208346788f95db3961040b24` | `47d07e52c7330bde569c60ddc088f202b399af6f7d805ce0ce8033e77d26d717` |

The pilot host is an Apple M2 Mac (`Mac14,2`, 8 cores, 16 GiB RAM), running macOS 26.6.2 (25G83). Its compiler is Homebrew GNU Fortran 14.1.0. The pinned fpm version is 0.13.0. The prebuilt macOS ARM64 fpm requires GCC 12 libraries, so the Mac uses the upstream single-file release source built with its installed compiler. The release source SHA-256 is `001cff6cf1145f215baa0888ba27acc06cea30a89b79d1a8be97db3fffbc8cd2`. fastchess identifies as `alpha 1.8.3`, build `20261107-d7b47e8`. The macOS ARM64 archive SHA-256 is `f7a812354d5c5944c0c8070c6fc492077589f98560412a977bb077cee4f441d8`. [fpm source release](https://github.com/fortran-lang/fpm/releases/tag/v0.13.0) · [fastchess release](https://github.com/Disservin/fastchess/releases/tag/v1.8.3-alpha)

On this Mac, set `SDKROOT` to the SDK selected by the Xcode command line tools. A clean source copy passed `fpm test`, `fpm test --profile release`, and `fpm build --profile release`. The release executable printed `Pandatran`.

```sh
export SDKROOT="$(xcrun --show-sdk-path)"
```

To bootstrap fpm from its verified release source, run this in a directory outside the project source or in an ignored local directory:

```sh
gfortran -O0 -c fpm-0.13.0.F90 -o fpm-bootstrap.o
gfortran -isysroot "$SDKROOT" fpm-bootstrap.o -o fpm
```

## Opening sets

[development.epd](development.epd) contains five pilot positions in the order below. The sources are named lines from the Lichess Chess Openings dataset (CC0-1.0, pinned revision `48a8c0e733facfdc9a3723fe882e51ec28014074`). These were hand-picked for a small rules and pairing check. When a name matches several lines, use the shortest, breaking ties by file order. The pilot uses the four EPD position fields with a fresh clock and no pre-start move history. The suite SHA-256 is `a2b3c17ef2d3c0e6fd00d8a3412e4fe9f5439aa5aafb2094d85264809914282d`. [Pinned source](https://github.com/lichess-org/chess-openings/tree/48a8c0e733facfdc9a3723fe882e51ec28014074)

| Opening | Source moves |
| --- | --- |
| B90 Sicilian Defense, Najdorf Variation | 1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 a6 |
| C45 Scotch Game | 1. e4 e5 2. Nf3 Nc6 3. d4 exd4 4. Nxd4 |
| C11 French Defense, Classical Variation | 1. e4 e6 2. d4 d5 3. Nc3 Nf6 |
| D35 Queen’s Gambit Declined, Harrwitz Attack | 1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bf4 |
| D85 Grünfeld Defense, Exchange Variation | 1. d4 Nf6 2. c4 g6 3. Nc3 d5 4. cxd5 Nxd5 |

Reserve the 8-move Stockfish book for confirmation. Its source archive `8moves_v3.pgn.zip` is pinned at `2ec69181c0b1367c5c58bcf5304a79c7b198b655` (CC0-1.0, SHA-256 `7e1e9dd118b4bb97d8a8b5b8a790c86e21f8509d59a27d2883767d94477be02e`). Replay the games in file order and compare their four-field EPD positions. Exclude any game that reaches a development position or shares its four-ply position with one of the development lines. Retain the first occurrence of each remaining 16-ply position as one EPD line. This kept 27,207 of 34,700 positions, hashed as `0967bf9d2faa523b16e8f1c6370e02779ff6ca9ba2853a116df46bf02822962b`. The reserved pool lives in the ignored local artifact directory. Select the final sample with its own recorded seed and match budget, and verify separation from any later development or training data before freezing it. [Pinned Stockfish book and license](https://github.com/official-stockfish/books/tree/2ec69181c0b1367c5c58bcf5304a79c7b198b655)

Checkpoint 7 added six lines to the development exclusions. Use the resulting 21,098-position reserve, described in [checkpoint 7](#checkpoint-7-classical-evaluation), as the starting pool for subsequent exclusions.

## Reproduce the local pilot

With the pinned `fastchess` on PATH, set `pandafish` to the absolute path of the verified executable and `results` to an existing output directory. Use absolute paths for the opening file and PGN. For the initial serial run, use `10+0.1`, five pairs and concurrency 1.

```sh
fastchess \
  -engine cmd="$pandafish" name=Pandafish-A \
  -engine cmd="$pandafish" name=Pandafish-B \
  -each tc=10+0.1 timemargin=0 restart=on \
  -openings file="$PWD/benchmarks/development.epd" format=epd order=sequential \
  -rounds 5 -repeat -concurrency 1 -strict -autosaveinterval 0 \
  -config outname="$results/pilot-serial.json" \
  -pgnout file="$results/pilot-serial.pgn" append=false
```

The pilot restarts engines between games, uses no opening or endgame assistance beyond the supplied positions, and uses the runner’s standard rule endings. Raw logs and PGNs are under `.local/checkpoint-01/results/`.

## Mac pilot results

| Run | Clock | Concurrency | Pairs | A W/D/L | Forfeits | Wall time |
| --- | --- | --- | --- | --- | --- | --- |
| Serial, all five positions | `10+0.1` | 1 | 5 | 0/7/3 | 0 | 5m 04s |
| Short concurrency check, opening 4 | `10+0.1` | 2 | 1 | 0/2/0 | 0 | 23s |
| Longer clock check, opening 4 | `60+0.6` | 2 | 1 | 0/2/0 | 0 | 2m 09s |

For the last two runs, use `start=4` on the opening option, `-rounds 1`, and distinct output paths. An independent replay with python-chess 1.11.2, installed outside the project, verified every starting position, color swap, move, and result. All 14 games ended under chess rules. The serial run included three checkmates, four threefold repetitions, two fifty-move draws, and one insufficient-material draw. Each later run returned exit 0. The macOS `time -l` wrapper returned exit 1 after the first completed match because the sandbox denied its CPU clock query. The fastchess log and all ten serial PGNs were complete.

| PGN | SHA-256 |
| --- | --- |
| `pilot-serial.pgn` | `90725294e118ffcec536f8e66f0a3162e2d965e96fa1192cabc73f7ea2b16ad9` |
| `pilot-concurrency2.pgn` | `aeef142e4887d30bbe14dbc6ea8014d62e76c7dd7230ed0c2c6c34bb57455f1d` |
| `pilot-long.pgn` | `ee863d860b5821c9c52bf281c27b19f9ad8e71541df595509b057e544dd7e658` |

During the longer run, a single memory sample put the four Pandafish processes at 13,760–14,288 KiB RSS each and fastchess at 4,720 KiB. Mac defaults for the next checkpoint that needs timed games are `10+0.1` and concurrency 1, with `60+0.6` for a slower smoke test. Concurrency 2 worked in both one-pair checks. The Mac was the agreed checkpoint host. Raspberry Pi runtime, sustained throughput, thermal behavior, and the final process-memory limit remain to be calibrated before confirmation.

## Checkpoint 2 move generation

The release build matched every root move and count from Stockfish 19 for six standard perft positions and eight cases covering castling, en passant, promotion, double check, stalemate and checkmate. The Mac Stockfish executable SHA-256 was `dc2f18c34ae962dff591b66147d220ec06e61d756b93d8a4f5e04fd8e55c251f`. Perft counts legal move paths without applying draw claims. [Published positions and counts](https://chessprogramming.org/Perft_Results)

| Position | Depth | Nodes |
| --- | --- | --- |
| Standard start | 5 | 4,865,609 |
| Kiwipete | 4 | 4,085,603 |
| Position 3 | 5 | 674,624 |
| Position 4 | 4 | 422,333 |
| Position 5 | 4 | 2,103,487 |
| Position 6 | 4 | 3,894,594 |

An external python-chess 1.11.2 check compared 432 sampled positions, including 108 depth-two divides. The sample used three 24-position walks from each standard position, selected from coordinate-sorted legal moves with Python’s PRNG seeded at `20261126`. The repository’s Fortran tests independently check state restoration after moves, malformed FEN rejection, and standard and special-move fixtures. Local oracle output is in `.local/checkpoint-02/oracle.txt`.

## Checkpoint 3 UCI and timed smoke games

The engine runs UCI with no arguments. It replays legal position histories and supports depth, nodes, movetime, game clocks, increments, and root move restrictions. It uses iterative, shallow alpha-beta with material and square placement, keeping the best move from the last completed depth or a legal fallback. Mate and stalemate are recognized. Draw history and quiescence are scheduled for checkpoint 4. The transport polls stdin while searching and flushes each response.

Debug, release, and runtime-check tests passed on the Apple M2 Mac. The Fortran pipe fixture exercises split input and CRLF, short budgets, active `isready`, `stop`, replaced searches and positions, terminal positions, `quit` and EOF. fastchess alpha 1.8.3 passed all 40 compliance checks. The Linux-specific stdin binding compiled in a syntax check. Linux runtime verification remains pending.

Both smoke matches used the release build (SHA-256 `0fe087ddf19434501ec00c2456cf982124277344fca33ca3bf368b1e92eaae3f`), the first two development openings, and a `5+0.05` clock with concurrency 1. Only the match runner supplied opening positions. Each game restarted the engines. Stockfish 19 used one thread and 3 MiB of hash. The initial Stockfish Skill 0 run stopped before completing a game because its intentionally weakened move differed from its reported PV. The full-strength run preserved fastchess strict mode.

| Opponent | Pairs | Pandatran W/D/L | Forfeits | Game endings |
| --- | --- | --- | --- | --- |
| Frozen Pandafish v1.0 | 2 | 0/0/4 | 0 | 4 checkmates |
| Stockfish 19 | 2 | 0/0/4 | 0 | 4 checkmates |

External replay with python-chess 1.11.2 verified all 436 plies, all opening pairs, and every result. The sample establishes that both timed matches work and gives an initial score. Raw compliance output, PGNs, runner configurations, and the interrupted reference run are under `.local/checkpoint-03/`.

Use the pinned fastchess and baseline binary paths from checkpoint 1. For Stockfish, substitute `-engine cmd="$stockfish" name=Stockfish-19 option.Threads=1 option.Hash=3` and use separate output names.

```sh
fastchess -engine cmd="$pandatran" name=Pandatran \
  -engine cmd="$pandafish" name=Pandafish-v1.0 \
  -each tc=5+0.05 timemargin=0 restart=on \
  -openings file="$PWD/benchmarks/development.epd" format=epd order=sequential \
  -rounds 2 -repeat -concurrency 1 -strict -autosaveinterval 0 \
  -config outname="$results/pandafish.json" \
  -pgnout file="$results/pandafish.pgn" append=false
```

## Checkpoint 4 tactical baseline

The depth search uses quiescence for captures, en passant, and all promotions. In check it searches legal evasions, including quiet ones. Tactical moves are ordered by victim, promotion, and attacker value. Ordinary quiescence is capped at ten plies, with up to six more for check evasions. At the absolute cap, after terminal and automatic draw checks, the evaluator supplies the fallback even if the side is in check. The bench includes a poisoned capture, a quiet evasion, mate in one, and a dead-material case alongside the standard positions. [Quiescence search reference](https://chessprogramming.org/Quiescence_Search)

- **Draws in search.** Threefold repetition and 100 halfmoves make zero available as a claim, including claims by an intended move. The search can still prefer a win. Fivefold repetition, 150 halfmoves, and recognized dead material score zero automatically. Mate is evaluated before draw thresholds. Recognized dead material covers bare kings, a single bishop or knight, and bishops confined to one square color. Repetition compares exact positions, including the turn, castling rights and the availability of a legal en passant capture. A FEN without its move history supplies a single occurrence. [FIDE Laws, articles 5 and 9](https://handbook.fide.com/chapter/E012023)
- **Draws in a match.** UCI has no draw-claim command, so the engine returns a legal move from a playable root. The pinned fastchess runner ends games when a position qualifies for threefold repetition, the fifty-move rule, or insufficient material. These match settings use rule endings without score-based adjudication. Checkmate takes precedence on the move that reaches the runner’s move-count threshold. The Fortran fixtures test the engine’s optional claims, automatic thresholds, and this precedence separately. [fastchess release](https://github.com/Disservin/fastchess/releases/tag/v1.8.3-alpha)

The seven-case [depth-three baseline](tactical-depth3.txt) records centipawn scores below the mate range. In the mate range, the magnitude is 30,000 minus plies to mate. The fixed-node run at 4,096 nodes per position also reproduced byte-for-byte. Kiwipete exhausted that limit before finishing depth one. Its depth-zero entry records a legal fallback and a placeholder score. Both variants use the same iterative driver as UCI.

```sh
"$pandatran_cp4" bench | diff -u benchmarks/tactical-depth3.txt -
"$pandatran_cp4" bench 3 4096
```

Debug, release, and runtime-check builds passed, including the Fortran pipe and tactical fixtures. Cases include quiet and capture quiescence, mate distances, 99/100 and 149/150 halfmoves, legal and pinned en passant for repetition, castling-right changes, and cancellation with state restoration. The build passed all 40 fastchess compliance checks.

### Timed baseline

Both matches ran on the Apple M2 Mac with five color-swapped opening pairs, `5+0.05`, and one concurrent game. The checkpoint 4 binary SHA-256 was `da924829e1fb803ae8dd04b0ef5b7e49c81b5b9921fa24e1d0d01f937b3893c1`. The control for the first row was the exact checkpoint 3 binary recorded above. The second row used the frozen Pandafish v1.0 release.

| Opponent | Pairs | Pandatran W/D/L | Score | Forfeits |
| --- | --- | --- | --- | --- |
| Checkpoint 3 Pandatran | 5 | 9/1/0 | 95% | 0 |
| Frozen Pandafish v1.0 | 5 | 0/0/10 | 0% | 0 |

Independent replay verified every opening pair and result across 1,627 plies. Nineteen games ended in checkmate and one in threefold repetition. These are development screens on five openings. Kiwipete took 15,776 nodes to complete depth one in the uncapped bench, which gives the next optimization checkpoint a reproducible workload.

Raw PGNs, runner configurations, compliance output, and the replay summary are under `.local/checkpoint-04/`.

| PGN | SHA-256 |
| --- | --- |
| `checkpoint-03.pgn` | `8bdfc76dcb49fbbad860115c43e161b3d7689c80ca942957096e445d45cfa848` |
| `pandafish.pgn` | `ef5faf261083c5c44564fe32cfba83bc553c92e02ae323374a53dd12568134b3` |

```sh
fastchess -engine cmd="$pandatran" name=Pandatran-cp4 \
  -engine cmd="$opponent" name="$opponent_name" \
  -each tc=5+0.05 timemargin=0 restart=on \
  -openings file="$PWD/benchmarks/development.epd" format=epd order=sequential \
  -rounds 5 -repeat -concurrency 1 -strict -autosaveinterval 0 \
  -config outname="$results/$match.json" \
  -pgnout file="$results/$match.pgn" append=false
```

## Checkpoint 5 transpositions and move ordering

The board key uses incremental 64-bit Zobrist hashing for pieces, the side to move, castling rights, and the en passant target. Tests recompute it after special moves and seeded legal walks and verify exact undo. The transposition table allocates 65,536 entries, or **2 MiB** on the Mac. It survives successive searches and clears on `ucinewgame`. The engine still fits the 3 MiB match cache budget. [Transposition table reference](https://chessprogramming.org/Transposition_Table)

A matching board key can suggest a move, and ordering uses the suggestion when it is present in the generated legal list. Score reuse also requires the exact search depth, halfmove clock, and ordered reversible-history fingerprint. The fingerprint resets when a pawn move, capture, or castling-right change makes earlier states unreachable. Main-search entries store exact, lower, or upper bounds and normalize mate scores to the stored position. Quiescence uses its own bounded search. Tests cover index collisions, bound cutoffs, mate distances, cache clearing, and a draw score that must stay isolated from a search of the same FEN without its recorded history. [Graph history interaction](https://chessprogramming.org/Graph_History_Interaction)

The ordering stages are the prior iteration’s best root move or the table hint, then captures and promotions, then quiet moves in their original order. PVS searches later choices with a narrow window and repeats a promising result at the full width when needed. The aspiration trial uses the prior iteration’s score ±40 cp and retries at full width on failure. PVS is the default. Aspiration saved 1.5% of nodes over PVS at depth four, with both measuring a 0.17-second median, so it remains a bench option. [Principal variation search](https://chessprogramming.org/Principal_Variation_Search)

| Bench mode | Depth 3 nodes | Depth 3 median | Depth 4 nodes | Depth 4 median |
| --- | ---: | ---: | ---: | ---: |
| Depth-3 `plain` / frozen checkpoint 4 at depth 4 | 2,009,283 | 5.16 s | 6,859,275 | |
| `order` | 40,830 | 0.10 s | 118,675 | 0.27 s |
| `table` | 38,091 | 0.09 s | 96,320 | 0.22 s |
| `pvs` | 29,684 | 0.07 s | 73,059 | 0.17 s |
| `aspiration` | 29,008 | 0.07 s | 71,938 | 0.17 s |

All seven scores and completed depths agreed across modes at both test depths. The depth-three `plain` output also matched the checkpoint 4 signature byte-for-byte. Ordering can change which tied move appears. Timing medians use three serial runs per measured mode on the Mac, alternating mode order. Kiwipete drove most of the savings and fell from 2,005,109 nodes to 27,173 at depth three. Kiwipete’s depth-one work fell from 15,776 to 4,691 nodes.

```sh
"$pandatran" bench 3 pvs legacy | diff -u benchmarks/transposition-depth3.txt -
"$pandatran" bench 3 plain legacy | diff -u benchmarks/tactical-depth3.txt -
"$pandatran" bench 4 aspiration legacy
```

### Timed comparison

The PVS build (SHA-256 `69b888188b52e33e67036a8d9c5f0378b7e1e8cd49247c33b2af39aeeb8622d2`) used the checkpoint 4 match settings. Each comparison played the same five color-swapped opening pairs on the Mac at `5+0.05`, with one concurrent game and the same runner options. Use `name=Pandatran-cp5` in the checkpoint 4 command and set the opponent to the frozen checkpoint 4 binary or Pandafish v1.0.

| Opponent | Pairs | Pandatran W/D/L | Score | Forfeits |
| --- | ---: | --- | ---: | ---: |
| Frozen checkpoint 4 Pandatran | 5 | 8/1/1 | 85% | 0 |
| Frozen Pandafish v1.0 | 5 | 0/1/9 | 5% | 0 |

Against Pandafish, the observed gain over checkpoint 4 on these openings was **5 percentage points**, from a single draw. Resampling the five matched opening pairs gives a descriptive 95% percentile interval of 0 to 15 percentage points. With fixed openings and one scoring pair, this remains a development signal.

Independent PGN replay verified every pair and outcome across 1,903 plies. Eighteen games ended by checkmate and two by the fifty-move rule. Debug, release and runtime-check tests passed, as did all 40 fastchess compliance checks. Move generation still matched Stockfish 19 on the 14 reference positions and python-chess on 432 sampled positions.

Runner logs, PGNs and three-run mode comparisons live in `.local/checkpoint-05/`.

| PGN | SHA-256 |
| --- | --- |
| `checkpoint-04.pgn` | `6bf90ce9160df474aac161e114db52e15003b86013fd32e6ca402016f86707fd` |
| `pandafish.pgn` | `0d3589db6270ffb037a06011dd5a7ea625a08bfe68cf06331465566f68ebd465` |

## Checkpoint 6 selective search

The trials each start from checkpoint 5’s PVS search. Both require a one-centipawn search window, a side that is out of check, non-pawn material on both sides, and at least four non-pawn pieces in total. Mate scores, repeated positions, and positions at or near a potential draw claim stay on the regular search path. The guard tests cover mate, check, pawn opposition, sparse material, and repetition. [Late move reductions](https://chessprogramming.org/Late_Move_Reductions) · [Null move pruning](https://chessprogramming.org/Null_Move_Pruning)

- **Late-move reductions.** At an eligible node with at least three plies remaining, a later non-pawn quiet move can start one ply shallower after three such moves have been searched. Hash moves, castles, and moves that give check get full depth. A reduced result that beats alpha or enters the mate range is searched again at full depth. The six-ply bench performed 3,627 reductions and 29 full-depth retries.
- **Guarded null move.** The independent trial required at least four plies remaining and a static evaluation at least 25 cp above beta. The pass cleared en passant and left the game clocks and real history untouched. Its artificial line bypassed the table and game-history draw claims. Seven of 44 probes cut off. The extra work increased the fixed-depth node total and gained no depth at the fixed-node cap. The trial ended at that gate. Its executable and source patch are retained under `.local/checkpoint-06/`.

| Six-ply bench mode | Nodes | Median wall time | Reductions / retries | Null probes / cutoffs |
| --- | ---: | ---: | ---: | ---: |
| PVS control | 1,104,150 | 2.48 s | 0 / 0 | 0 / 0 |
| PVS with LMR | 904,681 | 2.00 s | 3,627 / 29 | 0 / 0 |
| PVS with guarded null move | 1,126,018 | 2.56 s | 0 / 0 | 44 / 7 |

All three modes returned the same scores, moves and completed depths on the seven-position six-ply bench. Each mode reproduced across three serial runs. At 80,000 nodes per position the completed depths agreed. At 700,000 nodes, LMR completed depth six on Kiwipete while PVS completed depth five. Both returned `d5e6` and −23 cp.

### Equal-clock LMR screen

The LMR trial scored **4 wins, 3 draws, and 3 losses** against frozen checkpoint 5 at `10+0.1`. Both engines ran in one game at a time on the Apple M2 Mac, with five reversed-color opening pairs, strict runner checks, zero time margin, and fresh engine processes per game. Independent replay verified 1,294 plies and all ten endings, with zero forfeits. The trial used `args=uci lmr` and the control used its default search. It passed all 40 fastchess compliance checks.

The five pairs yielded a 55% score. A descriptive paired bootstrap spans 30–80%, so the match is weak strength evidence. Median reported search depth was six for both engines. The mean was 6.11 for LMR and 5.98 for the control, with median elapsed time of 0.194 s per move for each. Games reached different positions. The fixed-work results and positive timed screen support carrying LMR forward as the default, with PVS retained as the control mode.

The [six-ply baseline](selective-depth6.txt) records the LMR signature. Use the named control mode for comparisons without reductions.

```sh
"$pandatran" bench 6 lmr legacy | diff -u benchmarks/selective-depth6.txt -
"$pandatran" bench 7 700000 pvs legacy
"$pandatran" uci pvs legacy
```

The archived trial patch applies to the merged checkpoint 5 source. The trial binary SHA-256 is `1ce50244353d003cd83d5572d160446dca5928bc02b4a63999adcce55d2c6d05`. The LMR screen PGN SHA-256 is `85e5ac9f07ad32083fc43af5e8e1332f82bfde3f02a05a82f08a1437875079a5`. Bench captures, the source patch, runner configurations, raw PGNs, and independent replay reports are under `.local/checkpoint-06/`.

### Frozen Pandafish check

The cleaned checkpoint 6 build reproduced the LMR bench signature and passed debug, release, runtime-check, and all 40 fastchess compliance checks. With LMR as the default it scored **0 wins, 1 draw, and 9 losses** against frozen Pandafish v1.0 at `5+0.05`, using the same five color-swapped opening pairs and runner settings as checkpoint 5. Both checkpoints scored 5% against Pandafish, with the draw moving from opening five to opening two. Independent replay verified 1,036 plies, nine checkmates and one fifty-move draw, with zero forfeits.

The final checkpoint 6 binary SHA-256 is `449516c359a729255601ad4cdc294e59e4d879c423a75fb652bdf932bec2641b`. Its Pandafish PGN SHA-256 is `6360d56e05a248c09a6e91aeb972e489b971e124d52568504e5bf65b12b07515`.

## Checkpoint 7 classical evaluation

The reference evaluator interpolates material and piece-square scores between middlegame and endgame. Each side contributes one phase unit per knight or bishop, two per rook and four per queen, capped at 24 in total. Piece placement is computed from rank and distance from the center. The king favors shelter in the middlegame and activity in the endgame. The evaluator returns centipawns from the side to move. Material values used to order captures stay fixed across profiles. [Tapered evaluation](https://chessprogramming.org/Tapered_Eval)

Each feature group was tested against the same tapered reference.

- **Pawn structure** penalizes doubled and isolated pawns. It rewards passed pawns by advancement and halves that bonus if the next square is blocked. [Pawn structure](https://chessprogramming.org/Pawn_Structure)
- **Mobility** counts pseudo-legal destinations for knights, bishops, rooks and queens, excluding squares held by their own side or attacked by opposing pawns. It shares the attack geometry with move generation. [Mobility](https://chessprogramming.org/Mobility)
- **King safety** scores shields, enemy pawn storms and files with no friendly pawn around the king. It scales with the enemy’s remaining attacking pieces and contributes to the middlegame. [King safety](https://chessprogramming.org/King_Safety)

The [evaluation opening set](evaluation.epd) uses six families from the pinned Lichess Chess Openings dataset in the order below. Its SHA-256 is `f05e9ac378d1117ac09ed877c1d019a3046a9064554c5e2462779901ed227107`. These lines have distinct four-ply positions and share none with the five earlier development lines. [Pinned opening dataset](https://github.com/lichess-org/chess-openings/tree/48a8c0e733facfdc9a3723fe882e51ec28014074)

| Opening | Source moves |
| --- | --- |
| A29 English Opening, Fianchetto Line | 1. c4 e5 2. Nc3 Nf6 3. Nf3 Nc6 4. g3 |
| B12 Caro-Kann Defense, Short Variation | 1. e4 c6 2. d4 d5 3. e5 Bf5 4. Nf3 |
| C42 Petrov’s Defense, Classical Attack | 1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nf3 Nxe4 5. d4 |
| B08 Pirc Defense, Classical Variation | 1. e4 d6 2. d4 Nf6 3. Nc3 g6 4. Nf3 |
| A90 Dutch Defense, Classical Variation | 1. d4 f5 2. c4 Nf6 3. g3 e6 4. Bg2 |
| E32 Nimzo-Indian Defense, Classical Variation | 1. d4 Nf6 2. c4 e6 3. Nc3 Bb4 4. Qc2 |

To update the confirmation reserve, apply the original exclusions plus these six lines to the source PGN before deduplication. For each game, check whether any position is equal to one of the development EPDs or whether its four-ply EPD matches any development family. Preserve source order and only include positions already eligible in checkpoint 1. This left 21,098 positions in `.local/checkpoint-07/confirmation-reserve-filtered.epd`, with SHA-256 `04522db71abe09029c3117fdacdc242df10e3df160f06e8bbf8cf8f481472eea`. No games were played from that reserve.

### Evaluation cost

The table reports medians of three serial runs per profile with the release build on the M2 Mac. `evalbench` measures 700,000 static evaluations over seven fixed positions. The search bench allowed six plies and capped each position at 100,000 nodes. All profiles completed the same depth on each position, including depth four on Kiwipete. The full evaluator took 3.1 times as long per evaluation as legacy, with a 5% increase in search wall time on this workload. Mobility was the costliest individual group.

| Profile | ns per evaluation | Capped search nodes | Capped wall time |
| --- | ---: | ---: | ---: |
| Legacy | 37.9 | 290,414 | 0.476 s |
| Tapered | 31.2 | 278,142 | 0.459 s |
| Pawns | 47.8 | 272,418 | 0.461 s |
| Mobility | 88.3 | 303,663 | 0.530 s |
| King safety | 43.1 | 276,177 | 0.457 s |
| Full combination | 117.0 | 276,744 | 0.499 s |

### Timed screens

The frozen checkpoint 6 build was the control for the tapered reference. The remaining rows held tapered evaluation and LMR constant and added one feature group. Initial screens used six color-swapped opening pairs at `5+0.05` on the M2 Mac. Every match ran one game at a time with fresh processes, zero time margin and strict checks. Several comparisons ran side by side on the eight-core host. Independent replay verified opening order, color swaps, and all 5,445 plies and endings in the initial screens.

| Candidate | Control | W/D/L | Score | Forfeits |
| --- | --- | ---: | ---: | ---: |
| Tapered base | Frozen checkpoint 6 | 9/2/1 | 83.3% | 0 |
| Tapered plus pawn structure | Tapered base | 6/2/4 | 58.3% | 0 |
| Tapered plus mobility | Tapered base | 5/3/4 | 54.2% | 0 |
| Tapered plus king safety | Tapered base | 9/0/3 | 75.0% | 0 |

All three groups scored above 50%, so the second screen compared the full combination with the strongest single group, king safety. That match and the three cross-checks below used the five earlier development lines, covering different opening families from the initial screens. No coefficients were fitted.

| Candidate | Opponent | Clock | W/D/L | Score | Forfeits |
| --- | --- | --- | ---: | ---: | ---: |
| Tapered plus king safety | Frozen checkpoint 6 | `10+0.1` | 5/2/3 | 60% | 0 |
| Full combination | Tapered plus king safety | `10+0.1` | 8/0/2 | 80% | 0 |
| Tapered plus king safety | Frozen Pandafish v1.0 | `5+0.05` | 2/2/6 | 30% | 0 |
| Full combination | Frozen Pandafish v1.0 | `5+0.05` | 2/3/5 | 35% | 0 |

The full combination is the default. Its score against Pandafish increased from checkpoint 6’s 5% to 35% over the same openings and clock. Resampling those five opening pairs gives a descriptive 95% interval of +15 to +45 percentage points for the change. The sample supports carrying the evaluator forward. Pandafish still led this screen, with a median reported depth of six to Pandatran’s five. Independent replay verified all 4,573 follow-up plies and their rule endings.

The launch profile applies to the entire engine process. Use `legacy` for the checkpoint 6 evaluator, `tapered` for phase-interpolated material and placement, or `pawns`, `mobility`, and `safety` to add one group. The combinations are `pawns+mobility`, `pawns+safety`, `mobility+safety`, and `all`. A normal UCI launch with no arguments uses `all`.

```sh
"$pandatran" bench 6 100000 | diff -u benchmarks/evaluation-depth6-100k.txt -
"$pandatran" evalbench all
fastchess -engine cmd="$pandatran" 'args=uci lmr safety' name=safety \
  -engine cmd="$pandatran" 'args=uci lmr tapered' name=tapered \
  -each tc=5+0.05 timemargin=0 restart=on \
  -openings file="$PWD/benchmarks/evaluation.epd" format=epd order=sequential \
  -rounds 6 -repeat -concurrency 1 -strict -autosaveinterval 0 \
  -config outname="$results/safety-vs-tapered.json" \
  -pgnout file="$results/safety-vs-tapered.pgn" append=false
```

Debug, release, and Fortran runtime-check tests passed. The default UCI launch passed all 40 fastchess compliance checks and reproduced the trial’s fixed-depth search through UCI. The legacy profile reproduced the checkpoint 4, 5 and 6 signatures. Move generation matched Stockfish on 14 perft fixtures and python-chess on 432 sampled positions.

Match logs, runner configurations, and independent replay summaries are under `.local/checkpoint-07/`. The match trial binary SHA-256 was `f0f5448db27953f89a44fe98e6329bdf45fc0584e32ab95ad3163057f2d1fe32`. The final default build SHA-256 is `206756a90595ff64c373f3b076555859ce0286931632b4cf4eb48feaefa66eb1`. The frozen Pandafish opponent is the checkpoint 1 macOS ARM64 release. The checkpoint 6 opponent is the frozen default build listed above.

| PGN | SHA-256 |
| --- | --- |
| `tapered-vs-legacy.pgn` | `f3bd640bf7d12e3c0cfac07acb1d053f4cd01eb5bf437ddc14e0d1ff12a84888` |
| `pawns-vs-tapered.pgn` | `b5e1c0ff470735187eeda282cb028618f61e0c91171ae5157af1bcf4251d7f2e` |
| `mobility-vs-tapered.pgn` | `bfd4b4a3d7c426d81d4a6e070ef995fa507ec00cb0a11424f1bdc60fc87945b6` |
| `safety-vs-tapered.pgn` | `bd11357c4867d9985efceda5c787232e664de8b8ea4ef73dbd0846f85e3fc15f` |
| `safety-vs-checkpoint-06.pgn` | `1ce3f7a9553b37281d72e31bf749437df9a957ddae01914379a1f3ec1c0cb5e2` |
| `all-vs-safety.pgn` | `8bdce16260758d91b3ab44115295471b9e900607bba505dbd6202c945c5fd84c` |
| `safety-vs-Pandafish-v1.0.pgn` | `f73557d8425d5f60e2a1025b84c33e5df0cadda9628368b95c2c241ab1030c1a` |
| `all-vs-Pandafish-v1.0.pgn` | `a6d3849fc95032cd88b992853aa10151649d76ce7a047228e38afe10cd6d3483` |

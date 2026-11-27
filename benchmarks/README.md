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
"$pandatran" bench | diff -u benchmarks/tactical-depth3.txt -
"$pandatran" bench 3 4096
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

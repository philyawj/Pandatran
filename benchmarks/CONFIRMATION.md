# Step 10 Pandafish confirmation

## Protocol declared before selecting openings

The primary question is whether the staged-quiescence Pandatran scores above 50% against frozen Pandafish v1.0 on independently reserved starts at `5+0.05`. A secondary match tests the result at `10+0.1` on a disjoint sample. The confirmation uses the established Apple M2 Mac, with 8 cores, 16 GiB RAM, and macOS 26.6.2 (25G83). Raspberry Pi performance requires its own run.

| Artifact | Identity and SHA-256 |
| --- | --- |
| Pandatran | `be79ccd44fe89756647182ce1f85f72c1d5f5420`, default staged quiescence, `d43220c05a75e8ff7a9968446efc4bd41a5a4355801d0fbcc5cad09b721d219b` |
| Pandafish | v1.0 macOS ARM64 release, `085346c77e8d4e0040a9002e4182714a9ff3cab950b6ed4e88b654ffa01624e3` |
| fastchess | 1.8.3-alpha, `3088af5fd26bcf2c1e470351a4e5a39f38464662c50ab5d17af73a22d3caa9c9` |
| Eligible reserve | 21,098 rows, `04522db71abe09029c3117fdacdc242df10e3df160f06e8bbf8cf8f481472eea` |

Pandatran uses the GNU Fortran 14.1.0 fpm release build and macOS SDK 27.0 recorded for [step 9](README.md#step-9-iteration-2-quiescence-move-generation). The exact compilation commands and compiled-source hashes are archived with the executable. The released Pandafish binary was built with Go 1.25.0. [Pandafish v1.0 release](https://github.com/philyawj/Pandafish/releases/tag/v1.0)

### Match budget and decision

The separate step 9 development pilot supplied 11 short-clock pairs and six longer-clock pairs. Their between-pair score variances were 0.0409 and 0.1604 on the zero-to-one scale. A practically important score for planning is 65% primary and 70% secondary. Use conservative planning variances of 0.18 and 0.20, respectively. The normal planning approximation `n = ceil((1.96 + 0.84)^2 * variance / lead^2)` targets roughly 80% power at these effects and gives 63 and 40 pairs. Round the primary up to 64 pairs. The planning approximation sets the budget. The reported intervals use opening-pair resampling. [Paired match statistics](https://official-stockfish.github.io/docs/fishtest-wiki/Fishtest-Mathematics.html)

| Profile | Clock | Opening pairs | Games |
| --- | --- | ---: | ---: |
| Primary | `5+0.05` | 64 | 128 |
| Longer | `10+0.1` | 40 | 80 |

Play all scheduled games. Compute each opening pair’s score as Pandatran’s points divided by two. Report wins, draws, losses, five pair outcome counts, flags and other forfeits, and a two-sided 95% percentile interval for the mean obtained by resampling entire opening pairs. Use the empirical pair-score distribution convolved once for each sampled pair to compute the interval exactly. A clock confirms a lead when its lower endpoint exceeds 50%. Report the two clocks separately. The shorter clock is primary.

### Opening selection

Use the [filtered confirmation reserve](README.md#checkpoint-7-classical-evaluation) from the pinned CC0 Stockfish 8-move book. It excludes the earlier development EPDs and their four-ply opening families. Verify the reserve hash and disjointness from the eleven exact development starts before drawing. For every eligible EPD, hash the UTF-8 string `pandatran-cp10-20261127-v1` followed by one LF and the EPD without its final LF. Sort by ascending SHA-256, with EPD text breaking ties. Take the first 64 for primary and the next 40 for longer, in that order. Each selected EPD gets two games, one with each color assignment. Both samples are consumed for confirmation accounting.

### Runner and recovery

Both engines use a single search thread and equal clocks. Set `GOMAXPROCS=1` in the common runner environment. Keep fresh engine processes per game, no pondering, engine books or tablebases, and zero time margin. Run two games concurrently per clock, up to four on the Mac. The common operational limit is a 64 MiB resident-memory ceiling per engine, audited with two-second process samples. Treat a sampled breach as a run qualification failure. This is an audited ceiling on this host.

Use strict runner checks, disable score and move-count adjudication, and save tournament state every two games. Apply normal chess rules and count engine-caused time or other forfeits as losses. If a runner or host interruption leaves a pair incomplete or invalid, preserve completed valid pairs, archive the affected record, and replay both colors from exactly that opening with the same settings. Preserve any recorded engine-caused forfeits in the result. Log any recovery. Verify the openings, assignments, legal moves, and rule endings independently from the PGNs. [fastchess manual](https://github.com/Disservin/fastchess/blob/master/man.md)

## Frozen samples and invocation

The protocol snapshot was hashed before the reserve was ranked. The snapshot SHA-256 is `b910efb061759c362507052aae60b21e3aee8771402d48708526f7ece4f0ee40`. Every selected EPD passed python-chess validation. The samples share zero exact positions with one another or the eleven development starts. The remaining reserve is 20,994 rows in original order, with SHA-256 `70d24676718b13eee63d77991c12a334c6c7347d0f8c520726a6b44f01093319`.

| Sample | SHA-256 |
| --- | --- |
| [Primary opening EPDs](confirmation-01-primary.epd) | `dceb27361c7c560ce4aad6dca13ea348de08ee2a36a886715b2ebac18b7ee6f6` |
| [Longer opening EPDs](confirmation-01-longer.epd) | `b32d7eafd16b75b005711d0f62794c713f8b00a455dbbc22f14a9a872ac4e2f4` |

A preflight used two development pairs at each clock with the same runner setup. All eight games finished under the chess rules, and sampled RSS stayed below 16 MiB per process for each engine.

Use absolute paths for the pinned binaries, matching EPD, and a new output directory. Run once per profile at its declared clock and round count, overlapping both profiles if reproducing the four-game load. The confirmation supervisor records the exact arguments and samples the RSS of the runner’s engine children.

```sh
GOMAXPROCS=1 "$fastchess" \
  -engine cmd="$pandatran" name=Pandatran \
  -engine cmd="$pandafish" name=Pandafish-v1.0 \
  -each tc="$clock" timemargin=0 restart=on \
  -openings file="$epd" format=epd order=sequential \
  -rounds "$pairs" -repeat -concurrency 2 -strict -autosaveinterval 2 \
  -config outname="$results/$profile.json" \
  -pgnout file="$results/$profile.pgn" append=false
```

## Results

**Pandatran confirmed a lead over frozen Pandafish v1.0 at both clocks on the M2 Mac.** Both paired 95% interval lower bounds exceeded 50%. Each result applies to its sampled starts, clock, and host setup.

| Clock | Pairs | Pandatran W/D/L | Points | Score | Paired 95% interval | Time flags / other forfeits |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `5+0.05` (primary) | 64 | 89/19/20 | 98.5/128 | 77.0% | 70.7–83.2% | 0/0 |
| `10+0.1` | 40 | 61/14/5 | 68/80 | 85.0% | 79.4–90.6% | 0/0 |

| Clock | Pair scored 0 | 0.5 | 1 | 1.5 | 2 |
| --- | ---: | ---: | ---: | ---: | ---: |
| `5+0.05` | 0 | 5 | 16 | 12 | 31 |
| `10+0.1` | 0 | 0 | 6 | 12 | 22 |

python-chess 1.11.2 independently replayed all 25,633 plies and checked the opening EPD, color assignments, every move, and game result. The 208 endings were 175 checkmates, 11 threefold repetitions, 11 insufficient-material draws, and 11 fifty-move draws. Both runners exited successfully and no pairs needed recovery.

The overlapping matches took 14m 40s and 19m 43s. Peak sampled RSS for Pandatran was 5,552 KiB primary and 5,568 KiB longer. Pandafish peaked at 20,288 KiB and 21,216 KiB, respectively. All samples were within the common ceiling.

| PGN | SHA-256 |
| --- | --- |
| `primary.pgn` | `a0575d5f60569d4550dd23edddb543f87f58402799630d9396796a77be962919` |
| `longer.pgn` | `d1b6cff757a6e1f3cc487e033d1f01574310814ec98a4aefcfdc5c2c57be3eae` |

## Archive and UCI use

The local archive under `.local/checkpoint-10/` holds the tested executables, toolchain record, protocol snapshot, EPDs, runner arguments and state, PGNs, and replay summaries. SHA-256 manifests identify the exact artifacts and build inputs.

Launch the archived `engine/pandatran-cp10` executable with no arguments as a standard-chess UCI engine. It responds as `Pandatran`. For an interactive check, enter `uci`, `isready`, `position startpos`, and `go depth 3`. Wait for `bestmove`, then enter `quit`. Use the [local bot checklist](README.md#local-bot-dry-run) to configure the engine in lichess-bot.

## Next benchmark

Keep this frozen Pandafish result as the historical benchmark. The two confirmed leads support moving routine strength testing to a competitive Stockfish setting, starting with a development pilot at levels 7 and 10. [Pandafish to Stockfish plan](../IMPLEMENTATION_PLAN.MD#from-pandafish-to-stockfish)

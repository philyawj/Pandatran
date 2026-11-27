# Pandatran implementation plan

Build an original standard-chess engine in modern Fortran and measure its strength against frozen Pandafish v1.0. The [initial research](INITIAL_RESEARCH.MD) provides the history, engine references, and lessons from Pandafish’s development. Pandafish supplies the opponent and process lessons. Pandatran’s implementation follows independent engine research.

## Working together

Work through one numbered checkpoint at a time. The owner authorizes the checkpoint. Codex implements it, runs the agreed checks, fixes routine issues, and reports before beginning the next checkpoint. A checkpoint review records the code and behavior changes, test commands and results, meaningful failures, and any decision that affects the next checkpoint. For match results, include the opponent, clock, number of pairs, score, and forfeits. Flag any incomplete acceptance checks and give the reason.

Each accepted checkpoint is a natural GitHub PR and merge point. Use focused commits within a larger checkpoint when they make review easier. After review, merge the accepted work and start the next checkpoint from the resulting `main`. Optional experiments that fail can close with a short evidence note. The playing branch keeps the last accepted behavior.

Use GPT-6.2-sol high for design, implementation, and diagnosis. Use fpm, Fortran tests, and fastchess for repeatable work that can run unattended. Record the exact invocation and reuse the runner’s report. Add a small Fortran helper if a repeated task shows enough friction to justify it. OpenBench can handle distributed scheduling once one host becomes a real bottleneck.

Starting with Stockfish and continuing through later benchmarks, log every failed, rejected, or deferred experiment, unexpected regression, and setup failure that affects the evidence. Include the test settings, result, and lesson before closing each review. Update the entry if a later experiment resolves it. [Experiment log](EXPERIMENTS.MD)

## Experiment rules

- **Target.** Use Pandafish v1.0 at commit `27a34937c2aaee23d6e22bf60cee9b0075c16ad6`. Record the executable SHA-256, UCI identity, origin, and toolchain if built from source. Prefer the official Linux ARM64 asset on the Pi. [Pandafish v1.0 release](https://github.com/philyawj/Pandafish/releases/tag/v1.0)
- **Resources.** Start with one search thread per engine, equal clocks, books and tablebases disabled, and pondering off. Run both engines on the same host. Raspberry Pi is the target, and a confirmation on the Mac applies to that Mac. Budget about 3 MiB for Pandatran’s combined search caches to match Pandafish’s fixed tables. Set the common process-memory budget after measuring peak RSS on the match host. [Pandafish engine options and table sizes](https://github.com/philyawj/Pandafish/blob/v1.0/docs/ENGINE.md)
- **Openings.** Play each starting position twice, swapping colors. Keep development openings and final holdout families separate. Record source, license, file hash, selection rule, and seed where applicable. Keep the final holdout out of development matches and any tuning data.
- **Evidence.** For an exact optimization, check fixed-work equivalence before timing it. For a playing change, compare against the last accepted Pandatran and periodically against Pandafish. Use head-to-head score and uncertainty for strength. Record the candidate and opponent identities, tool versions, hardware, clock, concurrency, openings, results, and PGN location.
- **Scope.** Project-owned source and tests are Fortran. Use fpm with gfortran on macOS ARM64 and Linux ARM64. Install fastchess, external oracles, and lichess-bot separately. The first engine uses classical evaluation. More complex techniques qualify through evidence from the development matches.

## 1. Freeze the experiment and bootstrap Fortran

**Deliverable.** A minimal fpm package with a Fortran executable, a smoke test, and a reproducible fastchess control run. The executable can print its name and exit. Chess code begins at checkpoint 2.

1. Inventory the development machine and target Pi. Record the Pi board, OS, architecture, available cores, cooling, and versions of gfortran, fpm and fastchess. Pin the versions used for the run. If Pi access is pending, finish the local build and control run, and label Pi timing and capacity as pending.
2. Create `fpm.toml`, `app/main.f90`, and one smoke test under `test/`. Keep dependencies empty. Verify debug and release builds from a clean checkout. Ignore generated build products and local match artifacts.
3. Obtain the official target-platform Pandafish v1.0 asset and verify the published checksum. Record the extracted binary hash too. If an asset cannot be used, build once from the tagged tree with its vendored module and a pinned Go version meeting the repo’s requirement. Save the build inputs and hash. Use the same pinned executable throughout testing on that host.
4. Choose a small development opening set from a documented source and reserve a separate final holdout. Record their provenance and hashes. Keep the pilot small enough to audit the opening, colors, and ending of every game.
5. Run Pandafish against the same Pandafish binary under two engine names. Start at concurrency 1 and try a modest increase only after the first run is clean. Compare games per hour, end reasons, forfeits, observed memory, and Pi temperature and throttling. Try a longer-clock sample before adopting a provisional primary and secondary profile.

Suggested local acceptance commands once the package exists:

```sh
fpm test
fpm test --profile release
fpm build --profile release
fpm run --profile release
```

Example fastchess pilot using five opening pairs. Confirm the command against the pinned fastchess version, use an existing artifact directory, and give each run its own output path. [fastchess command reference](https://github.com/Disservin/fastchess/blob/master/man.md)

```sh
fastchess \
  -engine cmd=/absolute/path/to/pandafish name=Pandafish-A \
  -engine cmd=/absolute/path/to/pandafish name=Pandafish-B \
  -each tc=10+0.1 \
  -openings file=/absolute/path/to/development.epd format=epd order=sequential \
  -rounds 5 -repeat -concurrency 1 \
  -pgnout file=/absolute/path/to/pandafish-pilot.pgn
```

**Pass when** the package builds and tests in both profiles, the baseline identity is recorded, and every scheduled pair has the same opening with colors swapped, complete legal PGNs, and zero unexplained engine or runner failures. Record the Pi’s practical clock and concurrency proposal when the target run is available. A self-play score near 50% is a useful signal to inspect. The pair audit and failure record are the acceptance checks for this small sample.

## 2. Implement the legal chess core

**Deliverable.** A small engine-owned position model with legal moves, reversible updates, and a perft entry point for testing.

1. Define explicit integer kinds and a square convention. Use `int64` bitboards, a square-to-piece map, and a compact integer move representation. Store side to move, castling rights, en passant target, and the halfmove and fullmove counters. Keep a fixed-capacity caller-owned move buffer and an undo record. Compare derived state against recomputation in debug tests.
2. Implement six-field FEN parsing and serialization, then basic coordinate move conversion with promotion suffixes. Reject malformed input before committing a replacement position. Preserve FEN en passant information for serialization and define repetition equivalence using legal en passant availability when history handling is added.
3. Implement a straightforward attack generator with leaper tables and directional sliding rays. Generate candidate moves, then validate king safety with reversible move updates. Exercise legal and forbidden castles, rook-capture effects on castling rights, en passant that opens a line to the king, all four promotions, pins, double check, and no-legal-move positions.
4. Add a perft traversal and root divide, which reports counts by move. Compare every root move and count for selected positions against a pinned external engine. Perft counts legal move paths without pruning for draw claims or repetition. Add fixed-seed random legal walks and verify that unmaking returns every recorded state and recomputed bitboard to its starting value.

| Position | Debug acceptance | Release acceptance |
| --- | --- | --- |
| Standard start | Depth 4 gives 197,281 nodes | Depth 5 gives 4,865,609 |
| Kiwipete | Depth 3 gives 97,862 nodes | Depth 4 gives 4,085,603 |
| Chess Programming Wiki position 3 | Depth 4 gives 43,238 nodes | Depth 5 gives 674,624 |

**Pass when** the counts and targeted divides match, every special-move fixture passes, and deterministic round trips restore complete state. Test names or failure output identify the first differing move or field. Timing is recorded for future comparisons if useful. [Perft positions and expected counts](https://chessprogramming.org/Perft_Results)

## 3. Play the first timed UCI games

Add the UCI loop and a small material and piece-square search. Accept positions and move histories, game clocks, movetime and depth. Prove that readiness, stop, quit, infinite search and position replacement work over pipes while a search is active. Emit one legal best move for a completed or stopped search, using a legal fallback if no iteration finishes. Cleanly handle terminal positions and EOF. Use a portable Fortran input path on the two targets, with direct operating-system bindings if required.

**Pass when** the relevant fastchess compliance checks and the project’s pipe fixtures pass, and paired timed smoke games against a reference and Pandafish finish without protocol failures. Record the initial score and exact options. [UCI specification](https://www.shredderchess.com/chess-features/uci-universal-chess-interface.html)

## 4. Establish a tactical baseline

Complete iterative deepening, negamax alpha-beta, and quiescence with check evasions. Verify mate distance, terminal scores, legal repetition, move-count behavior, and dead-material cases. Specify how claimable draws are represented in search and how the match runner adjudicates them. Freeze a small position suite and a deterministic bench output with move, score and nodes. Exercise fixed-depth and fixed-node budgets.

**Pass when** repeated benches agree and the terminal, tactical, and cancellation fixtures give the expected results. Check mate and draw precedence against the rules, and confirm that incomplete iterations preserve the last valid result. Archive the first comparable timed baseline.

## 5. Add the transposition table and move ordering

Add an incrementally updated Zobrist key and verify it against recomputation. Add a bounded table and hash move ordering, then stage tactical and quiet choices. Test exact, lower and upper bounds, mate normalization, and safe reuse across draw contexts. Try principal variation search and aspiration windows as distinct changes once the table and ordering are stable.

**Pass when** the hash and score tests pass and fixed-depth comparisons or timed A/B games support each retained change. Keep the cache budget explicit. Run a direct Pandafish check and record the change in score with its uncertainty.

## 6. Test selective search

Start with independently testable late move reductions and guarded null move. Design small mate, check, zugzwang, and sparse-endgame controls before each candidate. Track re-search rates, useful completed depth, and elapsed time alongside nodes. Verify improving reduced lines at the needed depth.

**Pass when** retained changes pass tactical checks and have supporting equal-clock match evidence. Close rejected experiments with the failing case or result and preserve the accepted search.

## 7. Strengthen classical evaluation

Use phase-interpolated material and piece-square evaluation as the reference. Test related features in small groups, such as pawn structure, mobility, and king safety. Keep a public or generated validation set with independently identified position families. Consider fitted weights after the untuned evaluator and evaluation speed are measurable. Validate each fit on actual searches and timed games.

**Pass when** each retained evaluator has controlled match or timed-decision evidence and a clear account of regressions. Recheck the gap to Pandafish. Keep competing models and their data out of the final holdout.

## 8. Improve clock use and reliability

Measure soft and hard deadline behavior, node-polling overhead, and time spent when the best move changes across iterations. Profile the dominant bottleneck under representative Pi load and investigate one significant cost. Check low remaining time, increments, turns, and real runner overhead. Dry-run the external lichess-bot client with the pinned engine when a suitable environment is available.

**Pass when** short and longer match profiles run reliably, there are no unresolved legality or protocol faults, and any retained optimization demonstrates a reproducible benefit. Keep a small UCI compatibility checklist for eventual bot deployment.

## 9. Improve and select the confirmation candidate

Repeat this step on development openings. Each iteration starts with the latest Pandafish games and comparable A/B results, then tests one substantial change. Options include improved quiet ordering, a classical evaluation revision, or a compact NNUE feasibility test. Compare the trial with the strongest accepted Pandatran build and check it against frozen Pandafish. Review each iteration and carry forward the strongest supported build.

**Leave step 9 when** the owner is ready to measure a release. Typical reasons include diminishing gains from recent iterations, an agreed effort budget, or a build worth confirming now. The selected candidate must have reproducible development results and a documented rationale. Keep the confirmation openings reserved throughout this loop.

**End each iteration with a recommendation to the owner.** Say explicitly either **Repeat step 9** or **Move to step 10**. Explain how the latest results, remaining uncertainty, and the likely value of another experiment support the recommendation. If repeating, name the next change or test most likely to affect the decision. If moving to step 10, identify the build to freeze and why it is ready for confirmation. The owner decides when to start that match.

## 10. Confirm the result

Freeze the selected executable, compiler, flags, and any data artifacts. Run a predeclared, fixed-size match between frozen Pandatran and Pandafish v1.0 on the same host. Use the target Pi when available. Record a Mac confirmation under its own hardware and resource settings while Pi validation is pending. Set the sample size from a separate pilot and the smallest lead worth resolving. Pin clocks, resource limits, opening hash, runner configuration, and forfeiture, capping, and pair-recovery rules. Play a separate longer-clock check with its own recorded result.

**Pass when** the match is reproducible and the report gives the total score, W/D/L, paired outcome counts, flags, and paired 95% confidence interval. Claim superiority at a clock only when the interval’s lower score bound exceeds 50%. Report an inconclusive result or a deficit with the same evidence. Package the UCI usage notes with the result. [Paired engine-test statistics](https://official-stockfish.github.io/docs/fishtest-wiki/Fishtest-Mathematics.html)

## After checkpoint 10

Checkpoint 10 closes the first development cycle and gives future work a measured baseline. Archive the confirmed engine, frozen Pandafish opponent, match settings, openings, and results together so the original result stays reproducible.

Resume step 9 when there is a worthwhile new target or idea. Before restarting, agree on the smallest gain worth pursuing and the development and match time available. Run step 10 again for a later release decision, with a fresh sample from the remaining reserved openings drawn after the candidate and match budget are frozen.

### From Pandafish to Stockfish

1. **Record the Pandafish result in step 10.** Keep frozen Pandafish v1.0 and the original match record as the historical benchmark. If Pandatran keeps winning by a wide margin, or further gains against Pandafish become hard to measure after a confirmed lead, make Stockfish the next development target. During a plateau before confirmation, use Stockfish as a secondary opponent to look for weaknesses while continuing the Pandafish comparison.
2. **Find a competitive Stockfish setting on development openings.** Pin a Stockfish build and its network, thread count, hash, and clock. Pilot `Skill Level` 7 and 10 with `UCI_LimitStrength` disabled. Move down or up from those levels until a color-swapped pilot puts Pandatran near 50%. Record the exact settings with each result. Stockfish uses randomized weaker move choices at reduced skill levels, so compare match scores at the tested settings. [Initial Stockfish calibration](benchmarks/STOCKFISH.md) · [Stockfish strength controls](https://official-stockfish.github.io/docs/stockfish-wiki/Stockfish-FAQ.html#how-do-skill-level-and-uci_elo-work)
3. **Repeat step 9 at that level.** Test each change against the strongest accepted Pandatran and check it against the same Stockfish setting. When paired results show a sustained lead, test the strongest build at the next higher setting to find a new competitive match. Compare across both settings during the handoff and keep the old results for continuity.
4. **Use step 10 for a result worth confirming.** Freeze Pandatran and the exact Stockfish configuration, predeclare the match budget, and draw a fresh reserved sample. Advance while the gains justify the work. Pause when improvements stop paying off.

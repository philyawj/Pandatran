# Pandatran

Can a chess engine written in a language introduced in 1957 beat our chess engine written in a language introduced in 2009?

Pandatran is a from-scratch chess engine project in modern Fortran. The goal is to beat [Pandafish v1.0](https://github.com/philyawj/Pandafish/releases/tag/v1.0) in paired games on the same Raspberry Pi, with equal clocks and resource limits.

The engine speaks UCI and uses classical search with phase-interpolated evaluation. Project-owned engine code, tests, and tools are written in Fortran. Lichess-bot play is a later checkpoint.

## Try it

Build with gfortran and fpm 0.13 or later on macOS or Linux. Run `fpm run --profile release` and enter the commands below.

```text
uci
isready
position startpos moves e2e4
go depth 3
```

Wait for `bestmove`, then enter `quit`. Match runners can launch the built executable directly with no arguments.

The executable also counts legal move paths from the standard start or a six-field FEN. Use `divide` to see the count for each legal root move.

```sh
fpm test
fpm run --profile release -- perft 5
fpm run --profile release -- divide 3 "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"
fpm run --profile release -- bench
```

The deterministic bench reports each position’s move, score, completed depth, and node count. Pass `bench 3 4096` for a depth-three run capped at 4,096 nodes per position.

- [Initial research](INITIAL_RESEARCH.MD)
- [Implementation plan](IMPLEMENTATION_PLAN.MD)
- [Benchmark setup](benchmarks/README.md)

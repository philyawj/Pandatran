# Pandatran

Can a chess engine written in a language introduced in 1957 beat our chess engine written in a language introduced in 2009?

Pandatran is a from-scratch chess engine project in modern Fortran. The goal is to beat [Pandafish v1.0](https://github.com/philyawj/Pandafish/releases/tag/v1.0) in paired games on the same Raspberry Pi, with equal clocks and resource limits.

The engine will start with classical search and evaluation and speak UCI for match testing and eventual lichess-bot play. Project-owned engine code, tests, and tools will be written in Fortran.

The current executable can count legal move paths from the standard start or a six-field FEN. Use `divide` to see the count for each legal root move.

```sh
fpm test
fpm run --profile release -- perft 5
fpm run --profile release -- divide 3 "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"
```

- [Initial research](INITIAL_RESEARCH.MD)
- [Implementation plan](IMPLEMENTATION_PLAN.MD)
- [Benchmark setup](benchmarks/README.md)

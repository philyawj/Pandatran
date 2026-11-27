# Pandatran

Can a chess engine written in a language introduced in 1957 beat our chess engine written in a language introduced in 2009?

Pandatran is a from-scratch chess engine project in modern Fortran. The goal is to beat [Pandafish v1.0](https://github.com/philyawj/Pandafish/releases/tag/v1.0) in paired games on the same Raspberry Pi, with equal clocks and resource limits.

The engine will start with classical search and evaluation and speak UCI for match testing and eventual lichess-bot play. Project-owned engine code, tests, and tools will be written in Fortran.

The current executable is a build smoke test. To run it and its tests with gfortran and fpm installed:

```sh
fpm run
fpm test
```

- [Initial research](INITIAL_RESEARCH.MD)
- [Implementation plan](IMPLEMENTATION_PLAN.MD)
- [Benchmark setup](benchmarks/README.md)

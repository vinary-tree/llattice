# Foreign-provider performance and benchmarking

This document separates native lattice cost from foreign-function and resource
ownership cost. It is a methodology and diagnostic record, not a promise that
one workstation's nanoseconds will reproduce elsewhere.

## Paths under test

The Julia and Raku benchmark programs measure three paths over the same max/min
lattice:

1. **language direct** — call the language's ordinary `join` method;
2. **ABI pairwise** — enter the `vt.lattice.val.1` callback and create, then
   close, one owned result per operand; and
3. **ABI batch** — fold up to 256 operands in one callback and create one owned
   result for the entire page.

For $`n`$ operands and batch width $`b`$, pairwise evaluation performs $`n`$
foreign callbacks and creates $`n`$ resources. Batching performs approximately
$`\lceil n/b \rceil`$ callbacks and resource creations:

```math
C_{\mathrm{pair}}(n) = n(C_{\mathrm{ffi}} + C_{\mathrm{resource}})
  + nC_{\mathrm{join}},
```

```math
C_{\mathrm{batch}}(n,b) = \lceil n/b \rceil
  (C_{\mathrm{ffi}} + C_{\mathrm{resource}}) + nC_{\mathrm{join}}.
```

The batch contract does not make the algebra cheaper; it amortizes the fixed
boundary and ownership terms.

## Reproduce

Build the Raku shim first, then run repeated samples. Results are tab-separated
and include median, minimum, and maximum wall-clock nanoseconds:

```console
LLATTICE_BENCH_ITERATIONS=1000 LLATTICE_BENCH_SAMPLES=7 \
  julia --project=target/julia-env \
  bindings/julia/LLattice/benchmark/compare.jl

LLATTICE_BENCH_ITERATIONS=1000 LLATTICE_BENCH_SAMPLES=5 \
  raku -Ibindings/raku/lib bindings/raku/benchmark/compare.raku
```

The benchmark warms each sample once, reports the median, and retains the full
minimum/maximum envelope so garbage-collector or scheduler instability is
visible instead of averaged away. Release-quality comparisons should pin CPU
frequency policy, record system utilization, isolate a core where practical,
and collect enough samples for confidence intervals.

## Diagnostic run: 2026-08-30

The development host was an AMD Ryzen Threadripper PRO 5975WX with 32 physical
cores, Julia 1.12.7, Rakudo 2026.04 on MoarVM 2026.04, and GCC 16.2.1. Other
workloads consumed roughly 45–54% of aggregate CPU during a later utilization
sample, so these figures are deliberately classified as **busy-host smoke
evidence**, not release claims.

| Runtime and path | Median per operation | Samples | Interpretation |
|---|---:|---:|---|
| Julia direct | 22.3 ns | 7 | Type-stable built-in baseline. |
| Julia ABI pairwise | 374.8 ns | 7 | One callback and owned result per join. |
| Julia ABI batch | 21.0 ns | 7 | Fixed boundary amortized across 256 joins. |
| Raku direct | 3.29 µs | 3 | Language-local baseline from the post-fix smoke run. |
| Raku ABI pairwise | 9.52 ms | 3 | Nested NativeCall plus one host/native resource per join. |
| Raku ABI batch | 100.6 µs | 3 | Roughly 95-fold lower median cost per joined operand than pairwise in this run. |

The Raku investigation found that every result originally created eight fresh
callback closures. Repeated samples degraded as those closures accumulated
allocation and garbage-collector pressure. The implementation now configures
one module-wide callback table and reuses it for every immutable result. The
remaining pairwise cost is dominated by the synchronous Raku↔C callback and
owned state/resource construction, so bounded batching is the intended fast
path rather than a micro-optimized loop of pairwise calls.

## Operational guidance

- Use direct language values when no cross-project dynamic provider is needed.
- Use `join_many` or `meet_many` for pages of foreign values; 256 is the shared
  recommended width and an explicit memory bound.
- Keep canonical encoders compact and deterministic. Encoding is not part of
  join/meet unless a cross-provider decoder is required.
- Treat a widening min/max envelope as a signal to inspect garbage collection,
  CPU contention, frequency scaling, and resource teardown before accepting a
  regression conclusion.

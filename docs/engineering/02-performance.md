# Performance and resource behavior

Let $`n = |\text{left}|`$ and $`m = |\text{right}|`$.

## 1. Complexity

| Domain | `join` | `join_assign` | `leq` | `meet` | Native stack |
|---|---|---|---|---|---|
| integer / `bool` | $`\Theta(1)`$ | $`\Theta(1)`$ | $`\Theta(1)`$ | $`\Theta(1)`$ | constant |
| `Option<T>` | one inner join | one inner in-place join | one inner comparison | one inner meet | static type depth |
| `HashSet<T,S>` | expected $`\Theta(n+m)`$ | expected $`\Theta(m)`$ | expected $`\Theta(n)`$ | expected $`\Theta(\min(n,m))`$ | constant in input size |

Hash-set bounds assume expected constant-time hashing. Adversarial or unsuitable
hashers can degrade them.

## 2. Allocation strategy

Owned set join clones the larger hash table and extends it with the smaller
operand. This minimizes the table state rebuilt from individual insertions and
preserves the selected build-hasher type.

In-place join reuses the accumulator. Its change flag compares cardinality
before and after extension; union cannot change contents without changing
cardinality.

Meet creates a result using the smaller operand's cloned hasher, scans only the
smaller operand, and clones only elements retained by the intersection.

`Option<T>::join` delegates `Some/Some` to `T::join` instead of blindly cloning
the left inner value, preserving a specialized inner owned-join strategy.

## 3. Stack safety

All input-sized work is iterative over heap-backed containers. The formal
worklist model decreases pending length on every transition. A 64 KiB-stack
test exercises large joins, meets, and order comparisons.

This algebra has no nested-language control state, so a pushdown automaton would
not improve its asymptotic or stack behavior. Parser/tree consumers may use
specialized iterative PDAs while continuing to store abstract states in these
domains.

## 4. Pre-registered benchmark

The optimization experiment is pgmcp experiment 319,
`llattice-v2-layered-trait-hot-path-performance`. Its criterion was locked
before benchmark code or treatment implementation:

- primary metric: nanoseconds per owned join of two 16,384-element
  `HashSet<u64>` values with 50% overlap;
- 3 warm-ups and 51 measured samples per arm;
- one-sided Welch test at $`\alpha = 0.05`$ with minimum Cohen effect
  $`d = 0.5`$;
- hard secondary guard: no retained scalar, option, set-join, or set-meet mean
  may regress by more than 5%;
- an additional treatment-only stable `join_assign` metric measures the
  reusable-accumulator fast path.

The control implementation is revision `2ec21ca`; formal-only changes do not
alter its Rust source. The experiment was accepted on 2026-08-28:

| Retained metric | Samples/arm | Control ns/op | Treatment ns/op | Change |
|---|---:|---:|---:|---:|
| `HashSet` join | 51 | 531,306.355 | 212,411.576 | −60.021% |
| `HashSet` meet | 51 | 459,935.326 | 275,891.347 | −40.015% |
| `i64` join | 51 | 0.939151 | 0.940797 | +0.175% |
| `Option<i64>` join | 51 | 1.407156 | 1.406497 | −0.047% |

The primary one-sided Welch result is $`t=-232.821`$,
$`p=2.230\times10^{-97}`$, and $`d=-46.105`$. The 95% confidence interval for
the treatment-minus-control mean is
$`[-321{,}630.008,-316{,}159.551]`$ ns/op. Both arms depart from normality, so
pgmcp also reports the rank-based robustness evidence: Cliff's
$`\delta=-1.0`$ and a Mann–Whitney p-value numerically below the reporting
floor. Every retained mean passes the 1.05 ratio guard.

The treatment-only stable `HashSet::join_assign` mean is 203,069.203 ns/op,
4.398% below owned treatment join. A supplemental one-sided Welch comparison
gives $`p=2.735\times10^{-25}`$ and improvement-oriented $`d=3.555`$.

All 204 control samples and 255 treatment samples, host metadata, command
specifications, CSV SHA-256 digests, finalized run digests, and the decision are
recorded in pgmcp experiment 319. Local raw CSVs live under ignored
`target/benchmarks/` only while verification is in progress.

## 5. Reproducible execution

The recorded host is an AMD Ryzen Threadripper PRO 5975WX in performance mode.
Each arm is pinned to CPU 0, compiled with one Cargo job, capped to 4 GiB RSS,
forbidden from swapping, and limited to 32 tasks. `TMPDIR`, Cargo output, CSV,
and logs are all repository-local under `target/`.

```bash
systemd-run --user --scope \
  -p MemoryMax=4G -p MemorySwapMax=0 \
  -p CPUQuota=100% -p TasksMax=32 \
  --setenv=CARGO_BUILD_JOBS=1 \
  --setenv=CARGO_TARGET_DIR="$PWD/target/bench-cargo" \
  --setenv=TMPDIR="$PWD/target/verification/tmp" \
  -- taskset -c 0 cargo bench --bench hot_paths -- \
  --arm treatment --output target/benchmarks/treatment.csv \
  --samples 51 --warmups 3
```

Do not rerun an arm to select favorable samples. Do not use memory-backed
temporary storage for build or profiler output. If allocation profiling is
required, use headless `heaptrack` and keep its data under `target/`, with the
same systemd memory and task limits.

## 6. Optimization rules for downstream domains

- Override `join` only when it improves on clone-plus-`join_assign`.
- Keep exact change detection fused with mutation.
- Select the smaller side for intersections and sparse comparisons.
- Preserve custom hashers, allocators, canonical forms, and SIMD layouts.
- Avoid native recursion over runtime input.
- Compare unchanged semantic workloads, retain raw samples, and enforce
  preregistered regression thresholds.

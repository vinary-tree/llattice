# Fixpoints and monotone analysis

## 1. The pattern

A monotone analysis repeatedly applies transfer functions and accumulates
results with join until no value changes. If $`F`$ is monotone and the domain
has finite ascending chains, iteration from bottom reaches the least fixed
point.

![Ascending iteration to a fixed point](figures/fixpoint-ascent.svg)

`join_assign` exposes exactly the event a worklist needs: enqueue dependents
only when their input state changes.

## 2. A stack-safe worklist

```rust
use llattice::{Bottom, JoinSemilattice};
use std::collections::{HashSet, VecDeque};

fn reachable(edges: &[Vec<usize>], entry: usize) -> HashSet<usize> {
    let mut reached: HashSet<usize> = Bottom::bottom();
    let mut pending = VecDeque::from([entry]);

    while let Some(node) = pending.pop_front() {
        let singleton = [node].into_iter().collect();
        if !reached.join_assign(&singleton) {
            continue;
        }
        for &successor in &edges[node] {
            pending.push_back(successor);
        }
    }
    reached
}

let graph = vec![vec![1, 2], vec![3], vec![3], vec![]];
assert_eq!(reachable(&graph, 0), [0, 1, 2, 3].into_iter().collect());
```

The native stack depth is constant. Graph depth lives in the heap-backed
`VecDeque`, and facts live in the heap-backed `HashSet`. For maximum throughput,
a production reachability engine would insert a node directly rather than
construct a singleton; the example keeps the generic join pattern visible.

## 3. Generic chaotic iteration

```rust
use llattice::JoinSemilattice;
use std::collections::VecDeque;

fn propagate<T, F>(states: &mut [T], successors: &[Vec<usize>], mut transfer: F)
where
    T: JoinSemilattice,
    F: FnMut(usize, &T) -> T,
{
    let mut pending: VecDeque<usize> = (0..states.len()).collect();
    while let Some(source) = pending.pop_front() {
        let contribution = transfer(source, &states[source]);
        for &target in &successors[source] {
            if states[target].join_assign(&contribution) {
                pending.push_back(target);
            }
        }
    }
}

let mut states = vec![0_u32, 0, 0];
let successors = vec![vec![1], vec![2], vec![]];
propagate(&mut states, &successors, |node, state| *state + node as u32 + 1);
assert_eq!(states, vec![0, 1, 3]);
```

The example's acyclic graph terminates. In general, termination additionally
requires a finite-height domain, widening, or another explicit convergence
argument. Semilattice laws guarantee deterministic joins, not termination of an
arbitrary transfer function.

## 4. Parallel worklists

Partitioned propagation may process independent queue items concurrently when
the state type and scheduler support it:

```rust
use llattice::JoinSemilattice;

fn parallel_domain<T: JoinSemilattice + Send + Sync + 'static>(value: T) {
    # let _ = value;
}

parallel_domain(0_u64);
```

The engine must make concurrent writes race-free—through ownership partitions,
locks, atomics, or deterministic message passing. Algebraic commutativity makes
the final value independent of merge order; it does not make unsynchronized
memory access safe.

## 5. When a pushdown automaton is appropriate

Ordinary dataflow over a graph needs a queue, not a pushdown stack. A
specialized iterative pushdown automaton becomes appropriate when transfer
state includes unbounded nesting, such as balanced delimiters, call/return
matching, context-free reachability, or parser configurations.

For such a substitution:

1. define the source transition semantics;
2. define the PDA state, stack alphabet, and accepting condition;
3. prove language or reachability equivalence;
4. prove every transition's explicit-stack and auxiliary-space bound;
5. run depth-stress and RSS-capped performance tests.

PraTTaIL's future GrammarCore front-end and nested lling-llang analyses are
candidate PDA consumers. `llattice` remains the algebra of their abstract
states, not the parser machine itself.

## 6. Theory

For complete lattices, Tarski's theorem gives a complete lattice of fixed points
for a monotone endomap. Kleene iteration identifies the least fixed point under
continuity assumptions. Runtime domains frequently use finite height or
widening rather than representing a mathematically complete carrier.

- Tarski, A. “A Lattice-Theoretical Fixpoint Theorem and Its Applications.”
  [https://doi.org/10.2140/pjm.1955.5.285](https://doi.org/10.2140/pjm.1955.5.285)
- Cousot, P., and Cousot, R. “Abstract Interpretation.” POPL 1977.
  [https://doi.org/10.1145/512950.512973](https://doi.org/10.1145/512950.512973)

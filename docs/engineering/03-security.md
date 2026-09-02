# Security and robustness

## 1. Trust boundaries

The algebra accepts values and user-defined implementations; it does not
authenticate data, bound collection sizes, or choose a service's hasher.
Consumers must distinguish trusted compiler-internal domains from
attacker-influenced network or source inputs.

## 2. Type-level exclusion of unlawful carriers

Raw floats and raw vectors have no built-in implementation. This prevents two
correctness-poisoning paths:

- `NaN` can silently disappear through `max`/`min`, is unequal to itself, and
  has no intended partial comparison.
- left-biased sequence union can produce arrival-order-dependent structural
  values, invalidating CRDT convergence and cache-key determinism.

Use constructors that validate or canonicalize. Do not bypass them with public
fields or unchecked deserialization.

## 3. Hash collision and resource attacks

Expected hash-set complexity depends on the build hasher. The default randomized
hasher is suitable for many untrusted-key services. A deterministic fast hasher
may be appropriate inside a trusted compiler but can expose collision attacks
when keys are attacker-controlled.

Even with good hashing, union output can reach $`n+m`$ elements. Services must
bound input size, total domain growth, number of fixed-point iterations, and
concurrent tasks. OS-level RSS and no-swap limits are the final containment
layer, not a replacement for application quotas.

Crosby and Wallach analyze algorithmic-complexity denial of service,
[“Denial of Service via Algorithmic Complexity Attacks”](https://www.usenix.org/conference/12th-usenix-security-symposium/denial-service-algorithmic-complexity-attacks).
SipHash's keyed design is described by Aumasson and Bernstein,
[https://doi.org/10.1007/978-3-642-34931-7_28](https://doi.org/10.1007/978-3-642-34931-7_28).

## 4. Stack exhaustion

Built-ins never recurse over input depth. Set state and worklists live on the
heap, and scalar/optional dispatch has fixed type depth. The formal machine and
64 KiB-stack test guard this property.

Downstream recursive syntax/tree implementations must not inherit the native
call stack as an implicit worklist. Use an explicit heap stack or a specialized
iterative pushdown automaton when the language is context-free, and test depths
beyond ordinary production inputs under an RSS cap.

## 5. Concurrency

Removing `Send + Sync` from the algebra does not weaken Rust memory safety. A
parallel API must add those bounds before crossing workers, and Rust rejects an
`Rc`-backed domain there. Synchronization is still required for shared mutable
state; commutative algebra does not legalize data races.

The exact change flag can reduce scheduler traffic, but it is valid only when
an implementation satisfies the refinement contract. Reuse the public harness
for every custom concurrent domain.

## 6. Panic and unsafe policy

The crate forbids `unsafe`. Built-ins perform no indexing, unwrapping, or
overflowing arithmetic. Allocation failure and panics inside user-provided
`Clone`, equality, hashing, or build-hasher implementations remain outside the
leaf's control.

## 7. Operational checklist

- Validate/canonicalize domain values at construction and deserialization.
- Use a collision-resistant hasher for attacker-controlled keys.
- Bound set size, iterations, queue size, concurrency, RSS, and task count.
- Keep swap disabled for memory-sensitive validation to fail predictably.
- Keep temporary, benchmark, and profiler data on persistent repository-local
  storage rather than a memory-backed temporary filesystem.
- Use headless profilers only; never launch GUI heap analysis from automation.
- Require explicit `Send + Sync` at worker boundaries.
- Exercise maximum depth on a deliberately small native stack.
- Run formal, law, clippy, documentation, and packaging gates before release.

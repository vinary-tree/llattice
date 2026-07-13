# Security

> **Goal.** A concrete threat model for a tiny, pure library. `llattice` has no I/O, no `unsafe`, and no
> network surface, so the risks are **correctness-poisoning** and **algorithmic-complexity** attacks carried by
> the *values* you merge — plus the guarantees the crate makes in return.

---

## 1. Assets, adversary, and trust boundary

- **Asset.** The integrity and termination of a `join`/`meet`-based computation — a CRDT merge, a fixpoint, a
  dataflow result. A wrong or non-terminating merge can corrupt replicated state or hang a service.
- **Adversary.** Anyone who can influence the *values* fed into `join`/`meet` — a remote replica gossiping
  state, a user submitting data that becomes set elements, an upstream producing floats.
- **Trust boundary.** `llattice` trusts its inputs to be well-formed values of their type. It performs **no
  validation** (it is a vocabulary crate). Validation is the caller's responsibility at the system boundary.

The three attacks below all enter through that boundary.

---

## 2. Attack A — `NaN` correctness poisoning (`f32`/`f64`)

**Mechanism.** A single `NaN` in float data silently corrupts an order-based computation
([theory/03 §6](../theory/03-lawfulness-and-proofs.md)):

- `f64::max(NaN, x) = x`, so `NaN` is **silently dropped** by `join`/`meet` — data the operator expected to
  dominate simply vanishes.
- `NaN` is **$`\leq`$-incomparable**, so any invariant that assumes a total order (a sorted merge, a monotonicity
  check, "the clock only advances") **silently breaks** — `NaN.join(&NaN) != NaN` under `==`, so an idempotent
  re-merge appears to *change* state, which can desynchronise replicas that test for convergence by equality.

![NaN silently dropped by join; NaN breaking the order](figures/nan-poison.svg)

**Mitigation.**

- **Reject or normalise `NaN` at the boundary** before it reaches `join`/`meet`: `if x.is_nan() { return Err(..) }`.
- Use an **ordered-float newtype** (e.g. a `NotNan<f64>` wrapper) whose constructor excludes `NaN`, so the
  lattice operates only on the lawful subset.
- In tests, generate from the `NaN`-free subset ([engineering/01 §4](01-testing.md)).

---

## 3. Attack B — algorithmic-complexity DoS (`Vec`, `HashSet`)

**Mechanism (Vec).** `Vec::join`/`meet` are $`O(n^2)`$/$`O(n \cdot m)`$ ([engineering/02 §2](02-performance.md)) because
membership is a linear scan. An adversary who controls the size of merged vectors can force quadratic blow-up:
merging two attacker-supplied `Vec`s of length $`N`$ costs $`\Theta(N^2)`$ — a classic algorithmic-complexity
denial-of-service.

**Mechanism (HashSet).** `HashSet`'s expected $`O(1)`$ lookups degrade to $`O(n)`$ under **hash-flooding**
(Crosby & Wallach 2003): an adversary who knows (or can probe) the hasher crafts elements that all collide into
one bucket, turning a union into quadratic work. Rust's default `SipHash` (Aumasson & Bernstein 2012) is keyed
and resistant, but a downstream crate that swapped in a
fast non-keyed hasher (`FxHashMap`, `ahash` without a random seed) for speed reopens the hole.

**Mitigation.**

- **Bound input sizes** at the boundary — cap the cardinality of attacker-influenced sets/vectors before
  merging.
- For sets fed by untrusted input, **keep a keyed/DoS-resistant hasher** (the `std` default, or `ahash` *with* a
  random seed). Do not trade the keyed hasher for raw speed on untrusted data.
- Prefer **`HashSet` over `Vec`** for large untrusted collections — near-linear beats quadratic, and `HashSet`
  is a genuine value-lattice ([engineering/02 §4](02-performance.md)).

---

## 4. Attack C — logic corruption via an unlawful custom impl

**Mechanism.** A *user* `Lattice` impl whose `join` is not actually a least upper bound (e.g. uses `+` instead
of `max`, breaking idempotency — see [guides/02 §4](../guides/02-implementing-lattice.md)) destroys the
convergence guarantee: replicas may *never* converge, or converge to a wrong value, even though every built-in
impl is correct. This is not a flaw in `llattice` but a misuse it cannot prevent at compile time (the laws are
not encodable in Rust's type system).

**Mitigation.** Treat lawfulness as a tested invariant of every custom impl — run the property harness of
[engineering/01](01-testing.md) in CI. An unlawful `Lattice` should fail tests before it reaches production.

---

## 5. Guarantees the crate makes

Verified against `src/lib.rs` (and re-checkable by `grep`):

- **No `unsafe`.** The crate contains zero `unsafe` blocks — no memory-safety surface of its own.
- **No panics.** No `panic!`, `unwrap`, `expect`, `unreachable!`, `todo!`, array indexing, or overflow-prone
  arithmetic in any impl. `join`/`meet` are **total** on all inputs (including `NaN`, empty, and disjoint
  collections — they return a value rather than aborting). The `# Panics` section of every method is, truthfully,
  "none".
- **No I/O, no global state, no time/randomness.** Pure functions of their arguments; nothing to leak or
  exfiltrate.
- **No dependencies.** Zero third-party code in the build ([design/01](../design/01-architecture.md)), so no
  transitive supply-chain surface introduced by `llattice` itself.

These properties make `llattice` safe to place deep in a trusted computing base; the residual risk lives
entirely in the *values* callers choose to merge, which §2–§4 tell you how to constrain.

---

## 6. Summary checklist for integrators

- [ ] Reject/normalise `NaN` before using the `f32`/`f64` lattice.
- [ ] Bound the size of attacker-influenced `Vec`/`HashSet` inputs; prefer `HashSet` at scale.
- [ ] Keep a keyed/DoS-resistant hasher for untrusted `HashSet` elements.
- [ ] Property-test every custom `Lattice` impl for the four laws in CI.
- [ ] Rely on the no-`unsafe`/no-panic/no-dependency guarantees — and re-verify them on upgrade.

---

## References

1. Aumasson, J.-P., & Bernstein, D. J. (2012). SipHash: a fast short-input PRF. In *INDOCRYPT 2012* (Progress
   in Cryptology), LNCS 7668, 489–508. Springer. <https://doi.org/10.1007/978-3-642-34931-7_28> — the keyed
   PRF behind Rust's default `HashMap`/`HashSet` hasher.
2. Crosby, S. A., & Wallach, D. S. (2003). Denial of service via algorithmic complexity attacks. In
   *Proceedings of the 12th USENIX Security Symposium*.
   <https://www.usenix.org/conference/12th-usenix-security-symposium/denial-service-algorithmic-complexity-attacks>
   — hash-flooding and worst-case input attacks on hash tables and unindexed structures.

---

→ Back to the [engineering index](../README.md#engineering) or the [docs home](../README.md).

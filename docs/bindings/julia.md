# Julia guide

`LLattice.jl` provides type-stable built-in lattices and lets Julia code expose
custom immutable values through `VinaryTreeInterop.jl`.

## Install a checkout

```julia
using Pkg
Pkg.develop(path="../vinary-tree-interop/bindings/julia/VinaryTreeInterop")
Pkg.develop(path="bindings/julia/LLattice")
```

The registry release will use the natural package name `LLattice`; Vinary Tree
is the organization, not a redundant package-name prefix.

## Built-in values

```julia
using LLattice

join(MaxMin(3), MaxMin(8)) == MaxMin(8)
meet(BooleanLattice(false), BooleanLattice(true)) == BooleanLattice(false)

left = FiniteSetLattice([:read, :write])
right = FiniteSetLattice([:write, :admin])
Set(join(left, right)) == Set([:read, :write, :admin])

validate_laws(MaxMin.([1, 2, 3]))
```

`FiniteSetLattice` implements `iterate`, `length`, and `in`, so it participates
in ordinary Julia collection code. An `OptionalLattice` parameterized by `T`
and containing Julia's `nothing` value adjoins a new bottom element to lattice
`T`.

## Implement a custom lattice

Subtype `AbstractLattice`, then extend `Base.join`, `LLattice.meet`, equality,
and a canonical encoder. This monotone version counter uses maximum as join and
minimum as meet:

```julia
using LLattice

struct Version <: AbstractLattice
    value::UInt64
end

Base.join(a::Version, b::Version) = Version(max(a.value, b.value))
LLattice.meet(a::Version, b::Version) = Version(min(a.value, b.value))
Base.:(==)(a::Version, b::Version) = a.value == b.value

encode_version(v::Version) = collect(reinterpret(UInt8, [hton(v.value)]))
decode_version(bytes) = Version(ntoh(reinterpret(UInt64, bytes)[1]))

handle = provider(Version(7);
    domain_id="ll.version.u64.1",
    encode=encode_version,
    decode=decode_version)
try
    @assert host_value(handle) == Version(7)
finally
    close(handle)
end
```

The domain identifier is exactly 16 ASCII bytes. Change it whenever the stable
encoding or mathematical interpretation changes.

## Cross-boundary operations

The returned object is `VinaryTreeInterop.LatticeValue`. Use
`lattice_join`, `lattice_meet`, `equivalent`, `stable_bytes`, `diagnostic`,
`join_many`, and `meet_many` from `VinaryTreeInterop`. Close every result:

```julia
using VinaryTreeInterop

merged = join_many(base, updates)
try
    bytes = stable_bytes(merged)
finally
    close(merged)
end
```

## Performance and thread contract

Concrete built-ins use multiple dispatch and retain Julia's normal type
inference. The test suite pins representative `@inferred` calls. The dynamic
provider path necessarily allocates an owned result and dispatches through the
C ABI. Batch folds amortize that boundary.

Provider value reads and algebra run without a process-wide lock. A short
registry lock roots each newly returned value and updates retain/release
bookkeeping. Callbacks are synchronous and thread-bound; setting
`parallel=true` advertises reentrancy only on Julia-attached threads.

## API reference

The [Documenter source](../../bindings/julia/LLattice/docs/src/index.md) is
built with `julia --project=bindings/julia/LLattice/docs
bindings/julia/LLattice/docs/make.jl`. Exported API documentation is also
checked by the package tests.

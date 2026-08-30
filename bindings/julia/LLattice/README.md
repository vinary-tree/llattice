# LLattice.jl

`LLattice.jl` brings lawful join/meet lattices and customer-implementable
Vinary Tree lattice providers to Julia. It includes numeric max/min, Boolean,
finite-set, vector-content, and optional lattices; an exhaustive finite law
checker; and a versioned resource adapter for custom Julia values.

## Development installation

```julia
using Pkg
Pkg.develop(path="../../../../vinary-tree-interop/bindings/julia/VinaryTreeInterop")
Pkg.develop(path=".")
using LLattice
```

## Common use

```julia
values = MaxMin.([2, 7, 4])
maximum_value = foldl(join, values)
@assert maximum_value == MaxMin(7)
@assert validate_laws(values)

left = FiniteSetLattice([:read, :write])
right = FiniteSetLattice([:write, :admin])
@assert Set(join(left, right)) == Set([:read, :write, :admin])

ordered = VectorContentLattice([:parse, :analyze])
extended = VectorContentLattice([:analyze, :publish])
@assert collect(join(ordered, extended)) == [:parse, :analyze, :publish]
```

## Custom providers

Define an `AbstractLattice`, extend `Base.join` and `LLattice.meet`, then call
`provider` with an exact 16-byte domain identifier and canonical encoder. Add a
decoder when values must interoperate with independently implemented providers
of the same domain.

Provider handles and all join/meet results are owned. Close them in `finally`
blocks; garbage collection is only a fallback. Prefer `join_many` and
`meet_many` from `VinaryTreeInterop` for pages of values.

The [complete Julia guide](../../../docs/bindings/julia.md) covers ownership,
threading, stable encodings, performance, and the public API.

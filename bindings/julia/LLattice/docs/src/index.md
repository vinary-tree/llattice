# LLattice.jl

`LLattice.jl` defines common immutable lattice values and exposes custom Julia
values through Vinary Tree's versioned lattice-resource capability.

```@example quickstart
using LLattice

left = FiniteSetLattice([:read, :write])
right = FiniteSetLattice([:write, :admin])
Set(join(left, right))
```

The operations obey the lattice laws over their documented domains. Use
`validate_laws` to exhaustively check a finite witness set before exporting a
custom provider.

## API

```@docs
AbstractLattice
MaxMin
BooleanLattice
FiniteSetLattice
OptionalLattice
join
meet
validate_laws
provider
host_value
```

Provider results implement the owned `VinaryTreeInterop.LatticeValue`
lifecycle. Close providers and operation results deterministically, and use the
interop package's bounded `join_many` or `meet_many` for bulk work.

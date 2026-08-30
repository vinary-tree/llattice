# LLattice for Raku

`LLattice` supplies lawful lattice values and customer-implementable Vinary
Tree providers in idiomatic Raku. Numeric max/min, Boolean, finite-set, and
vector-content, and optional lattices are included, along with finite law
validation and bounded NativeCall batch operations.

## Install

```console
zef install Vinary-Tree-Interop
zef install LLattice
```

The installation build hook compiles a small C17 provider shim against the
authoritative header resource from `Vinary-Tree-Interop`. A C compiler is
therefore required when installing from source.

## Use values naturally

```raku
use LLattice;

my @values = (2, 7, 4).map({ MaxMin.new(value => $_) });
say @values.reduce(*.join(*));
validate-laws(@values);

my $permissions = FiniteSetLattice.new(value => set(<read write>));
say $permissions.elems;
say 'read' ~~ $permissions;

my $pipeline = VectorContentLattice.new(value => [<parse analyze>]);
my $extension = VectorContentLattice.new(value => [<analyze publish>]);
say $pipeline.join($extension).list; # parse analyze publish
say equivalent($pipeline, VectorContentLattice.new(value => [<analyze parse>]));
```

## Expose a custom value

Implement `Lattice`, select an exact 16-byte domain identifier, and provide a
canonical encoder to `provider`. The result is an owned `LatticeValue`; close
it and every algebra result deterministically. Add a decoder for cross-provider
operations and use `.join-many`/`.meet-many` for batches.

See the [complete Raku guide](../../docs/bindings/raku.md) and the installed
`LLattice` Pod reference for the lifecycle, thread, exception, and security
contracts.

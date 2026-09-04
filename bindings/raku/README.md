# LLattice for Raku

`LLattice` supplies lawful lattice values and customer-implementable Vinary
Tree providers in idiomatic Raku. Numeric max/min, Boolean, finite-set, and
optional lattices are included, along with finite law validation and bounded
NativeCall batch operations.

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
```

## Expose a custom value

Implement `Lattice`, select an exact 16-byte domain identifier, and provide a
canonical encoder to `provider`. The result is an owned `LatticeValue`; close
it and every algebra result deterministically. Add a decoder for cross-provider
operations and use `.join-many`/`.meet-many` for batches.

See the [complete Raku guide](../../docs/bindings/raku.md) and the installed
`LLattice` Pod reference for the lifecycle, thread, exception, and security
contracts.

## Maintain the provider ABI

[`provider-api.json`](provider-api.json) is the single reviewed contract for
the provider shim's C functions, callback signatures, calling convention,
capability bits, API-introduction revisions, ownership transfers, and
nullability rules. Regenerate both the public C header and the Raku NativeCall
module after changing that model:

```console
python3 scripts/generate-raku-provider-abi.py --write
python3 scripts/generate-raku-provider-abi.py --check
```

Do not edit `cbits/llattice_raku_provider.h` or
`lib/LLattice/GeneratedProviderAbi.rakumod` by hand. The check fails if either
output differs byte-for-byte. At runtime, the facade also rejects a provider
shim with an incompatible ABI version, an older API revision, missing required
capabilities, or mismatched `VtInterfaceId`/`VtResource` layouts before it
registers callbacks.

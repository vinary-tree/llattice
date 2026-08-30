# Raku guide

The `LLattice` distribution supplies natural Raku roles and values plus a safe
NativeCall provider for Vinary Tree consumers.

## Install a checkout

Install `Vinary-Tree-Interop` first, then `LLattice`:

```console
zef install ../vinary-tree-interop/bindings/raku
zef install bindings/raku
```

During the second installation, `Build.rakumod` compiles a small C17 shim. It
uses the exact ABI header resource published by `Vinary-Tree-Interop`, so the
NativeCall provider cannot silently drift from the shared C layouts.

## Built-in values and Raku idioms

```raku
use LLattice;

my $low = MaxMin.new(value => 3);
my $high = MaxMin.new(value => 8);
say $low.join($high).value; # 8

my $permissions = FiniteSetLattice.new(value => set(<read write>));
say $permissions.elems;
say 'read' ~~ $permissions;

my $pipeline = VectorContentLattice.new(value => [<parse analyze>]);
my $extension = VectorContentLattice.new(value => [<analyze publish>]);
say $pipeline.join($extension).list; # parse analyze publish

validate-laws([$low, $high]);
```

`FiniteSetLattice` does `Iterable` and supports smart matching as a set-like
container. `VectorContentLattice` does `Iterable` and `Positional`; operations
preserve left-hand presentation order, while `equivalent` compares content so
the same quotient as Rust's `Vec` lattice satisfies the laws. `OptionalLattice`
represents the lifted bottom with an undefined `.value`.

## Implement and expose a custom value

Implement the `Lattice` role and provide a canonical encoder. Supplying a
decoder permits operations with another implementation of the same domain.

```raku
use LLattice;

class Version does Lattice {
    has UInt:D $.value is required;
    method join(Version:D $other --> Version:D) {
        Version.new(value => $!value max $other.value)
    }
    method meet(Version:D $other --> Version:D) {
        Version.new(value => $!value min $other.value)
    }
}

sub encode-version(Version:D $v --> Blob:D) {
    Blob.new((^8).map({ ($v.value +> (56 - 8 * $_)) +& 0xff }))
}

my $handle = provider(
    Version.new(value => 7),
    domain-id => 'll.version.u64.1',
    encode => &encode-version,
);
LEAVE $handle.close;
say value($handle).value;
```

The identifier must be exactly 16 ASCII bytes. Add `:decode(&decoder)` when
cross-provider conversion is required.

## Ownership, callbacks, and batching

The provider returns an owned `LatticeValue`. Call `.close` deterministically;
its `DESTROY` method is a safety net, not a scheduling guarantee. `.join`,
`.meet`, `.join-many`, and `.meet-many` each return another owned value.

Rakudo cannot place a callback pointer in a NativeCall `CStruct`. The bundled
shim therefore owns the resource vtable and an atomic reference count, while
Raku owns and roots the actual callbacks. Algebra callbacks do not acquire a C
mutex. Raku registry locking is limited to lifetime registration and removal.
Providers advertise `THREAD-BOUND`, so consumers must invoke them on a
Rakudo-owned thread.

Set `LLATTICE_RAKU_PROVIDER_LIB` only when developing against a manually built
shim. Installed packages resolve the canonical `libraries/llattice_raku_provider`
resource automatically.

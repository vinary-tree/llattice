unit module LLattice;

use NativeCall;
use Vinary::Tree::Interop;

=begin pod

=NAME LLattice

=SUBTITLE Lawful lattice values and host-implementable Vinary Tree providers

=DESCRIPTION

C<LLattice> supplies idiomatic Raku value types for join and meet, a finite
law checker, and a resource provider that lets Raku implementations participate
in Vinary Tree algorithms through the versioned lattice-value ABI.

=end pod

role Lattice is export {
    method join(Lattice:D --> Lattice:D) { ... }
    method meet(Lattice:D --> Lattice:D) { ... }
}

class MaxMin does Lattice is export {
    has Real:D $.value is required;

    method join(MaxMin:D $other --> MaxMin:D) {
        MaxMin.new(value => $!value max $other.value)
    }

    method meet(MaxMin:D $other --> MaxMin:D) {
        MaxMin.new(value => $!value min $other.value)
    }
}

class BooleanLattice does Lattice is export {
    has Bool:D $.value is required;

    method join(BooleanLattice:D $other --> BooleanLattice:D) {
        BooleanLattice.new(value => $!value || $other.value)
    }

    method meet(BooleanLattice:D $other --> BooleanLattice:D) {
        BooleanLattice.new(value => $!value && $other.value)
    }
}

class FiniteSetLattice does Lattice does Iterable is export {
    has Set:D $.value is required;

    method join(FiniteSetLattice:D $other --> FiniteSetLattice:D) {
        FiniteSetLattice.new(value => $!value (|) $other.value)
    }

    method meet(FiniteSetLattice:D $other --> FiniteSetLattice:D) {
        FiniteSetLattice.new(value => $!value (&) $other.value)
    }

    method iterator(--> Iterator:D) { $!value.iterator }
    method elems(--> Int:D) { $!value.elems }
    method ACCEPTS(Mu $candidate --> Bool:D) { $candidate (elem) $!value }
}

class OptionalLattice does Lattice is export {
    has Lattice $.value;

    method join(OptionalLattice:D $other --> OptionalLattice:D) {
        return $other unless $!value.defined;
        return self unless $other.value.defined;
        OptionalLattice.new(value => $!value.join($other.value))
    }

    method meet(OptionalLattice:D $other --> OptionalLattice:D) {
        return OptionalLattice.new unless $!value.defined && $other.value.defined;
        OptionalLattice.new(value => $!value.meet($other.value))
    }
}

multi sub equivalent(MaxMin:D $left, MaxMin:D $right --> Bool:D) {
    $left.value == $right.value
}

multi sub equivalent(BooleanLattice:D $left, BooleanLattice:D $right --> Bool:D) {
    $left.value == $right.value
}

multi sub equivalent(
    FiniteSetLattice:D $left,
    FiniteSetLattice:D $right,
    --> Bool:D
) {
    $left.value eqv $right.value
}

multi sub equivalent(OptionalLattice:D $left, OptionalLattice:D $right --> Bool:D) {
    return True unless $left.value.defined || $right.value.defined;
    return False unless $left.value.defined && $right.value.defined;
    equivalent($left.value, $right.value)
}

multi sub equivalent(Mu $left, Mu $right --> Bool:D) { $left eqv $right }

sub validate-laws(@samples where *.elems > 0 --> Bool:D) is export {
    for @samples X @samples -> ($left, $right) {
        die 'join is not commutative' unless equivalent(
            $left.join($right), $right.join($left));
        die 'meet is not commutative' unless equivalent(
            $left.meet($right), $right.meet($left));
        die 'join absorption failed' unless equivalent(
            $left.join($left.meet($right)), $left);
        die 'meet absorption failed' unless equivalent(
            $left.meet($left.join($right)), $left);
    }
    for @samples -> $item {
        die 'join is not idempotent' unless equivalent($item.join($item), $item);
        die 'meet is not idempotent' unless equivalent($item.meet($item), $item);
    }
    for @samples X @samples X @samples -> ($first, $second, $third) {
        die 'join is not associative' unless equivalent(
            $first.join($second).join($third),
            $first.join($second.join($third)));
        die 'meet is not associative' unless equivalent(
            $first.meet($second).meet($third),
            $first.meet($second.meet($third)));
    }
    True
}

class ProviderState {
    has Lattice:D $.value is required;
    has InterfaceId:D $.domain-id is required;
    has Callable:D $.encode is required;
    has Callable $.decode;
    has UInt:D $.flags is required;
    has Str:D $.diagnostic is rw = '';
    has CArray[uint64] $.context is required;
}

my Lock $LIFETIME-LOCK .= new;
my UInt $NEXT-ID = 1;
my %STATES;

sub provider-library(--> Str:D) {
    state $library = %*ENV<LLATTICE_RAKU_PROVIDER_LIB>
        // %?RESOURCES<libraries/llattice_raku_provider>.IO.Str;
    $library
}

sub configure-provider(
    &drop (Pointer),
    &join (Pointer, Pointer, Pointer, Pointer --> int32),
    &meet (Pointer, Pointer, Pointer, Pointer --> int32),
    &equal (Pointer, Pointer, Pointer, Pointer --> int32),
    &stable-bytes (Pointer, Pointer, size_t, Pointer, Pointer --> int32),
    &diagnostic (Pointer, Pointer, size_t, Pointer, Pointer --> int32),
    &join-many (Pointer, Pointer, size_t, Pointer --> int32),
    &meet-many (Pointer, Pointer, size_t, Pointer --> int32),
    --> int32
) is native(&provider-library)
    is symbol('llattice_raku_provider_configure') { * }

sub create-provider(
    InterfaceId,
    uint64,
    Pointer,
    RawResource,
    --> int32
) is native(&provider-library) is symbol('llattice_raku_provider_create') { * }

sub provider-host-context(RawResource, Pointer is rw --> int32)
    is native(&provider-library)
    is symbol('llattice_raku_provider_host_context') { * }

sub provider-host-context-at(Pointer, size_t, Pointer is rw --> int32)
    is native(&provider-library)
    is symbol('llattice_raku_provider_host_context_at') { * }

sub memcpy(Pointer, Pointer, size_t --> Pointer) is native { * }

sub state-id(Pointer:D $context --> UInt:D) {
    nativecast(CArray[uint64], $context)[0]
}

sub state(Pointer:D $context --> ProviderState:D) {
    %STATES{state-id($context)} // die 'closed lattice provider context'
}

sub host-context(RawResource:D $raw --> Pointer) {
    my Pointer $context .= new;
    my $status = provider-host-context($raw, $context);
    return Pointer unless Status($status) == OK;
    $context
}

sub provider-drop(Pointer:D $context --> Nil) {
    try {
        $LIFETIME-LOCK.protect: { %STATES{state-id($context)}:delete }
    }
}

sub operand-value(
    ProviderState:D $owner,
    Pointer $known-context,
    RawResource:D $raw,
    --> Lattice:D
) {
    my $context = $known-context ?? $known-context !! host-context($raw);
    if $context.defined {
        my $other = state($context);
        die 'lattice operands have different domains'
            unless $other.domain-id.bytes eqv $owner.domain-id.bytes;
        return $other.value;
    }
    die 'foreign lattice values require a stable-byte decoder'
        unless $owner.decode.defined;
    my $wrapped;
    LEAVE $wrapped.close if $wrapped.defined;
    $wrapped = lattice-value(borrow-resource($raw), :take);
    die 'lattice operands have different domains'
        unless $wrapped.domain-id.bytes eqv $owner.domain-id.bytes;
    $owner.decode.($wrapped.stable-bytes)
}

sub raw-from-pointer(Pointer:D $source --> RawResource:D) {
    my $raw = RawResource.new;
    memcpy(nativecast(Pointer, $raw), $source, nativesizeof(RawResource));
    $raw
}

sub write-raw(Pointer:D $target, RawResource:D $source --> Nil) {
    memcpy($target, nativecast(Pointer, $source), nativesizeof(RawResource));
}

sub copy-bytes(
    Blob:D $bytes,
    Pointer $output,
    size_t $capacity,
    Pointer:D $written,
    Pointer:D $required,
    --> int32
) {
    return NULL-POINTER if $capacity && !$output;
    my $required-count = $bytes.bytes;
    my $written-count = $capacity min $required-count;
    nativecast(CArray[size_t], $required)[0] = $required-count;
    nativecast(CArray[size_t], $written)[0] = $written-count;
    if $written-count {
        my $storage = CArray[uint8].allocate($written-count);
        $storage[$_] = $bytes[$_] for ^$written-count;
        memcpy($output, nativecast(Pointer, $storage), $written-count);
    }
    OK
}

sub provider-binary(
    Bool:D $is-join,
    Pointer:D $raw-context,
    Pointer $other-context,
    Pointer:D $other,
    Pointer:D $output,
    --> int32
) {
    my int32 $status = PROVIDER-ERROR;
    try {
        my $current = state($raw-context);
        my $rhs = operand-value($current, $other-context,
            raw-from-pointer($other));
        my $result = $is-join
            ?? $current.value.join($rhs)
            !! $current.value.meet($rhs);
        write-raw($output, make-provider-raw(
            $result, $current.domain-id, $current.encode,
            $current.decode, $current.flags,
        ));
        $status = OK;
        CATCH {
            default {
                try state($raw-context).diagnostic = .message;
                $status = PROVIDER-ERROR;
            }
        }
    }
    $status
}

sub provider-join(
    Pointer:D $raw-context,
    Pointer $other-context,
    Pointer:D $other,
    Pointer:D $output,
    --> int32
) {
    provider-binary(True, $raw-context, $other-context, $other, $output)
}

sub provider-meet(
    Pointer:D $raw-context,
    Pointer $other-context,
    Pointer:D $other,
    Pointer:D $output,
    --> int32
) {
    provider-binary(False, $raw-context, $other-context, $other, $output)
}

sub provider-equal(
    Pointer:D $raw-context,
    Pointer $other-context,
    Pointer:D $other,
    Pointer:D $output,
    --> int32
) {
    my int32 $status = PROVIDER-ERROR;
    try {
        my $current = state($raw-context);
        nativecast(CArray[uint8], $output)[0] = equivalent($current.value,
            operand-value($current, $other-context,
                raw-from-pointer($other))) ?? 1 !! 0;
        $status = OK;
        CATCH {
            default {
                try state($raw-context).diagnostic = .message;
                $status = PROVIDER-ERROR;
            }
        }
    }
    $status
}

sub provider-stable-bytes(
    Pointer:D $raw-context,
    Pointer $output,
    size_t $capacity,
    Pointer:D $written,
    Pointer:D $required,
    --> int32
) {
    my int32 $status = PROVIDER-ERROR;
    try {
        my $current = state($raw-context);
        $status = copy-bytes(Blob.new($current.encode.($current.value).list),
            $output, $capacity, $written, $required);
        CATCH {
            default {
                try state($raw-context).diagnostic = .message;
                $status = PROVIDER-ERROR;
            }
        }
    }
    $status
}

sub provider-diagnostic(
    Pointer:D $raw-context,
    Pointer $output,
    size_t $capacity,
    Pointer:D $written,
    Pointer:D $required,
    --> int32
) {
    my int32 $status = PROVIDER-ERROR;
    try {
        $status = copy-bytes(state($raw-context).diagnostic.encode('utf8'),
            $output, $capacity, $written, $required);
        CATCH { default { $status = PROVIDER-ERROR } }
    }
    $status
}

sub provider-many(
    Bool:D $is-join,
    Pointer:D $raw-context,
    Pointer $others,
    size_t $count,
    Pointer:D $output,
    --> int32
) {
    my int32 $status = PROVIDER-ERROR;
    try {
        my $current = state($raw-context);
        my $result = $current.value;
        for ^$count -> $index {
            my $raw = RawResource.new;
            memcpy(nativecast(Pointer, $raw),
                Pointer.new($others + $index * nativesizeof(RawResource)),
                nativesizeof(RawResource));
            my Pointer $other-context .= new;
            my $context-status = provider-host-context-at(
                $others, $index, $other-context);
            $other-context = Pointer unless Status($context-status) == OK;
            my $rhs = operand-value($current, $other-context, $raw);
            $result = $is-join ?? $result.join($rhs) !! $result.meet($rhs);
        }
        write-raw($output, make-provider-raw(
            $result, $current.domain-id, $current.encode,
            $current.decode, $current.flags,
        ));
        $status = OK;
        CATCH {
            default {
                try state($raw-context).diagnostic = .message;
                $status = PROVIDER-ERROR;
            }
        }
    }
    $status
}

sub provider-join-many(
    Pointer:D $raw-context,
    Pointer $others,
    size_t $count,
    Pointer:D $output,
    --> int32
) {
    provider-many(True, $raw-context, $others, $count, $output)
}

sub provider-meet-many(
    Pointer:D $raw-context,
    Pointer $others,
    size_t $count,
    Pointer:D $output,
    --> int32
) {
    provider-many(False, $raw-context, $others, $count, $output)
}

sub ensure-provider-configured(--> Nil) {
    state $status = configure-provider(
        &provider-drop,
        &provider-join,
        &provider-meet,
        &provider-equal,
        &provider-stable-bytes,
        &provider-diagnostic,
        &provider-join-many,
        &provider-meet-many,
    );
    check-status($status, 'raku-lattice-provider-configure');
}

sub make-provider-raw(
    Lattice:D $value,
    InterfaceId:D $domain-id,
    Callable:D $encode,
    Callable $decode,
    UInt:D $flags,
    --> RawResource:D
) {
    ensure-provider-configured;
    my UInt $id;
    my $context = CArray[uint64].allocate(1);
    $LIFETIME-LOCK.protect: {
        $id = $NEXT-ID++;
        $context[0] = $id;
    }
    my $state = ProviderState.new(
        :$value, :$domain-id, :$encode, :$decode, :$flags, :$context,
    );
    $LIFETIME-LOCK.protect: { %STATES{$id} = $state }
    my $raw = RawResource.new;
    my $status = create-provider(
        $domain-id,
        $flags,
        nativecast(Pointer, $context),
        $raw,
    );
    unless Status($status) == OK {
        $LIFETIME-LOCK.protect: { %STATES{$id}:delete }
        check-status($status, 'raku-lattice-provider-create');
    }
    $raw
}

sub provider(
    Lattice:D $value,
    Str:D :$domain-id! where *.encode('ascii').bytes == 16,
    :&encode!,
    :&decode,
    Bool:D :$parallel = False,
    --> LatticeValue:D
) is export {
    my $flags = LATTICE-FLAG-THREAD-BOUND +|
        LATTICE-FLAG-STABLE-BYTES +| LATTICE-FLAG-BATCH;
    $flags +|= LATTICE-FLAG-PARALLEL-REENTRANT if $parallel;
    lattice-value(adopt-resource(make-provider-raw(
        $value, interface-id($domain-id), &encode, &decode, $flags,
    )), :take)
}

sub value(LatticeValue:D $provider --> Lattice:D) is export {
    my $context = host-context($provider.resource.raw);
    die 'lattice value is not hosted by LLattice for Raku'
        unless $context.defined;
    state($context).value
}

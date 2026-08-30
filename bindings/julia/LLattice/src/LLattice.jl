module LLattice

using VinaryTreeInterop
const VTI = VinaryTreeInterop
import Base: join

export AbstractLattice,
    MaxMin,
    BooleanLattice,
    FiniteSetLattice,
    VectorContentLattice,
    OptionalLattice,
    join,
    meet,
    validate_laws,
    provider,
    host_value

"""Common abstract supertype for idiomatic Julia lattice values."""
abstract type AbstractLattice end

@doc """
    join(left, right)

Return the least upper bound of two values in the same lattice.
""" join
"""
    meet(left, right)

Return the greatest lower bound of two values in the same lattice.
"""
function meet end

"""Numeric lattice ordered by the ordinary total order: join is `max` and meet is `min`."""
struct MaxMin{T<:Real} <: AbstractLattice
    value::T
end

join(left::MaxMin{T}, right::MaxMin{T}) where {T} = MaxMin(max(left.value, right.value))
meet(left::MaxMin{T}, right::MaxMin{T}) where {T} = MaxMin(min(left.value, right.value))
Base.:(==)(left::MaxMin, right::MaxMin) = left.value == right.value
Base.hash(value::MaxMin, seed::UInt) = hash(value.value, seed)

"""Boolean lattice ordered by implication: join is disjunction and meet is conjunction."""
struct BooleanLattice <: AbstractLattice
    value::Bool
end

join(left::BooleanLattice, right::BooleanLattice) =
    BooleanLattice(left.value | right.value)
meet(left::BooleanLattice, right::BooleanLattice) =
    BooleanLattice(left.value & right.value)
Base.:(==)(left::BooleanLattice, right::BooleanLattice) = left.value == right.value
Base.hash(value::BooleanLattice, seed::UInt) = hash(value.value, seed)

"""Finite powerset lattice: join is union and meet is intersection."""
struct FiniteSetLattice{T} <: AbstractLattice
    value::Set{T}
end

FiniteSetLattice(values) = FiniteSetLattice(Set(values))
join(left::FiniteSetLattice{T}, right::FiniteSetLattice{T}) where {T} =
    FiniteSetLattice(union(left.value, right.value))
meet(left::FiniteSetLattice{T}, right::FiniteSetLattice{T}) where {T} =
    FiniteSetLattice(intersect(left.value, right.value))
Base.:(==)(left::FiniteSetLattice, right::FiniteSetLattice) =
    left.value == right.value
Base.length(value::FiniteSetLattice) = length(value.value)
Base.in(item, value::FiniteSetLattice) = in(item, value.value)
Base.iterate(value::FiniteSetLattice, state...) = iterate(value.value, state...)

"""
    VectorContentLattice(values)

Order-preserving finite-content lattice corresponding to llattice's native
`Vec` implementation. `join` appends previously unseen right-hand values and
`meet` retains common values in left-hand order. Equality intentionally
compares content rather than presentation order: the native vector operations
form a lattice on that quotient, while the stored order remains deterministic.
Repeated constructor values are collapsed at their first occurrence.
"""
struct VectorContentLattice{T} <: AbstractLattice
    value::Vector{T}

    function VectorContentLattice{T}(values) where {T}
        normalized = T[]
        for item in values
            item in normalized || push!(normalized, item)
        end
        new{T}(normalized)
    end
end

VectorContentLattice(values) = begin
    collected = collect(values)
    VectorContentLattice{eltype(collected)}(collected)
end

function join(left::VectorContentLattice{T}, right::VectorContentLattice{T}) where {T}
    result = copy(left.value)
    for item in right.value
        item in result || push!(result, item)
    end
    VectorContentLattice{T}(result)
end

meet(left::VectorContentLattice{T}, right::VectorContentLattice{T}) where {T} =
    VectorContentLattice{T}(item for item in left.value if item in right.value)

Base.:(==)(left::VectorContentLattice, right::VectorContentLattice) =
    length(left) == length(right) && all(item in right for item in left)
Base.length(value::VectorContentLattice) = length(value.value)
Base.in(item, value::VectorContentLattice) = in(item, value.value)
Base.iterate(value::VectorContentLattice, state...) = iterate(value.value, state...)
Base.getindex(value::VectorContentLattice, index::Integer) = value.value[index]
Base.eltype(::Type{VectorContentLattice{T}}) where {T} = T

"""
    OptionalLattice(value)

Lift a lattice with a new bottom element represented by `nothing`.
"""
struct OptionalLattice{T<:AbstractLattice} <: AbstractLattice
    value::Union{Nothing,T}
end

OptionalLattice(value::T) where {T<:AbstractLattice} = OptionalLattice{T}(value)

function join(left::OptionalLattice{T}, right::OptionalLattice{T}) where {T}
    left.value === nothing && return right
    right.value === nothing && return left
    OptionalLattice(join(left.value, right.value))
end

function meet(left::OptionalLattice{T}, right::OptionalLattice{T}) where {T}
    (left.value === nothing || right.value === nothing) &&
        return OptionalLattice{T}(nothing)
    OptionalLattice(meet(left.value, right.value))
end

Base.:(==)(left::OptionalLattice, right::OptionalLattice) = left.value == right.value

"""
    validate_laws(samples; equal=(==))

Exhaustively validate associativity, commutativity, idempotence, and absorption
over a finite sample. The function throws `ArgumentError` with the first
counterexample and returns `true` only when every lattice law holds.
"""
function validate_laws(samples; equal=(==))
    values = collect(samples)
    isempty(values) && throw(ArgumentError("law validation requires at least one sample"))
    for left in values, right in values
        equal(join(left, right), join(right, left)) ||
            throw(ArgumentError("join is not commutative for the supplied samples"))
        equal(meet(left, right), meet(right, left)) ||
            throw(ArgumentError("meet is not commutative for the supplied samples"))
        equal(join(left, meet(left, right)), left) ||
            throw(ArgumentError("join absorption failed for the supplied samples"))
        equal(meet(left, join(left, right)), left) ||
            throw(ArgumentError("meet absorption failed for the supplied samples"))
    end
    for item in values
        equal(join(item, item), item) ||
            throw(ArgumentError("join is not idempotent for the supplied samples"))
        equal(meet(item, item), item) ||
            throw(ArgumentError("meet is not idempotent for the supplied samples"))
    end
    for first in values, second in values, third in values
        equal(join(join(first, second), third), join(first, join(second, third))) ||
            throw(ArgumentError("join is not associative for the supplied samples"))
        equal(meet(meet(first, second), third), meet(first, meet(second, third))) ||
            throw(ArgumentError("meet is not associative for the supplied samples"))
    end
    true
end

mutable struct ProviderState
    references::Int
    value::Any
    domain_id::VTI.VtInterfaceId
    encode::Any
    decode::Any
    flags::UInt64
    diagnostic_lock::ReentrantLock
    last_diagnostic::String
    table::Base.RefValue{VTI.VtLatticeVTable}
end

const PROVIDER_REGISTRY = Dict{Ptr{Cvoid},ProviderState}()
const PROVIDER_REGISTRY_LOCK = ReentrantLock()

function provider_state(context::Ptr{Cvoid})
    context == C_NULL && throw(ArgumentError("null lattice provider context"))
    unsafe_pointer_to_objref(context)::ProviderState
end

function record_failure!(state::ProviderState, error)
    message = sprint(showerror, error)
    lock(state.diagnostic_lock) do
        state.last_diagnostic = message
    end
    nothing
end

function provider_retain(context::Ptr{Cvoid})::Cvoid
    try
        lock(PROVIDER_REGISTRY_LOCK) do
            state = PROVIDER_REGISTRY[context]
            state.references += 1
        end
    catch
        # Base retain callbacks are infallible by contract. A missing context
        # means the provider has already been corrupted; unwinding across C is
        # less safe than leaving the retain ledger unchanged.
    end
    nothing
end

function provider_release(context::Ptr{Cvoid})::Cvoid
    try
        lock(PROVIDER_REGISTRY_LOCK) do
            state = PROVIDER_REGISTRY[context]
            state.references -= 1
            state.references == 0 && delete!(PROVIDER_REGISTRY, context)
        end
    catch
        # Release is likewise an infallible ABI callback.
    end
    nothing
end

function provider_query(context::Ptr{Cvoid}, id_pointer::Ptr{VTI.VtInterfaceId},
    minimum_version::UInt32, output::Ptr{Ptr{Cvoid}})::Cint
    (context == C_NULL || id_pointer == C_NULL || output == C_NULL) &&
        return Cint(VTI.STATUS_NULL_POINTER)
    try
        state = provider_state(context)
        id = unsafe_load(id_pointer)
        if id != VTI.LATTICE_INTERFACE_ID ||
            minimum_version > VTI.LATTICE_INTERFACE_VERSION
            return Cint(VTI.STATUS_UNSUPPORTED)
        end
        unsafe_store!(output, Ptr{Cvoid}(Base.unsafe_convert(
            Ptr{VTI.VtLatticeVTable}, state.table)))
        Cint(VTI.STATUS_OK)
    catch error
        try record_failure!(provider_state(context), error) catch end
        Cint(VTI.STATUS_PROVIDER_ERROR)
    end
end

function foreign_value(state::ProviderState, raw::VTI.VtResourceRaw)
    raw.context == C_NULL && throw(ArgumentError("null lattice operand"))
    if raw.vtable == Base.unsafe_convert(Ptr{VTI.VtResourceVTable}, RESOURCE_TABLE)
        other = provider_state(raw.context)
        other.domain_id == state.domain_id ||
            throw(ArgumentError("lattice operands have different domains"))
        return other.value
    end
    state.decode === nothing && throw(ArgumentError(
        "foreign lattice values require a stable-byte decoder"))
    resource = VTI.borrow_resource(raw)
    wrapped = VTI.lattice_value(resource; take=true)
    try
        VTI.domain_id(wrapped) == state.domain_id ||
            throw(ArgumentError("lattice operands have different domains"))
        state.decode(VTI.stable_bytes(wrapped))
    finally
        close(wrapped)
    end
end

function new_provider_raw(template::ProviderState, value)
    register_provider_raw(value, template.domain_id, template.encode,
        template.decode, template.flags)
end

function provider_binary(context::Ptr{Cvoid}, other_pointer::Ptr{VTI.VtResourceRaw},
    output::Ptr{VTI.VtResourceRaw}, operation::Symbol)::Cint
    (context == C_NULL || other_pointer == C_NULL || output == C_NULL) &&
        return Cint(VTI.STATUS_NULL_POINTER)
    state = provider_state(context)
    try
        other = foreign_value(state, unsafe_load(other_pointer))
        result = operation == :join ? join(state.value, other) :
            meet(state.value, other)
        unsafe_store!(output, new_provider_raw(state, result))
        Cint(VTI.STATUS_OK)
    catch error
        record_failure!(state, error)
        Cint(VTI.STATUS_PROVIDER_ERROR)
    end
end

provider_join(context, other, output)::Cint =
    provider_binary(context, other, output, :join)
provider_meet(context, other, output)::Cint =
    provider_binary(context, other, output, :meet)

function provider_equal(context::Ptr{Cvoid}, other_pointer::Ptr{VTI.VtResourceRaw},
    output::Ptr{UInt8})::Cint
    (context == C_NULL || other_pointer == C_NULL || output == C_NULL) &&
        return Cint(VTI.STATUS_NULL_POINTER)
    state = provider_state(context)
    try
        other = foreign_value(state, unsafe_load(other_pointer))
        unsafe_store!(output, UInt8(state.value == other))
        Cint(VTI.STATUS_OK)
    catch error
        record_failure!(state, error)
        Cint(VTI.STATUS_PROVIDER_ERROR)
    end
end

function copy_provider_bytes(source::Vector{UInt8}, output::Ptr{UInt8},
    capacity::Csize_t, written::Ptr{Csize_t}, required::Ptr{Csize_t})::Cint
    (written == C_NULL || required == C_NULL ||
        (capacity != 0 && output == C_NULL)) &&
        return Cint(VTI.STATUS_NULL_POINTER)
    count = min(Int(capacity), length(source))
    if count != 0
        GC.@preserve source unsafe_copyto!(output, pointer(source), count)
    end
    unsafe_store!(written, Csize_t(count))
    unsafe_store!(required, Csize_t(length(source)))
    Cint(VTI.STATUS_OK)
end

function provider_stable_bytes(context::Ptr{Cvoid}, output::Ptr{UInt8},
    capacity::Csize_t, written::Ptr{Csize_t}, required::Ptr{Csize_t})::Cint
    context == C_NULL && return Cint(VTI.STATUS_NULL_POINTER)
    state = provider_state(context)
    try
        bytes = Vector{UInt8}(state.encode(state.value))
        copy_provider_bytes(bytes, output, capacity, written, required)
    catch error
        record_failure!(state, error)
        Cint(VTI.STATUS_PROVIDER_ERROR)
    end
end

function provider_diagnostic(context::Ptr{Cvoid}, output::Ptr{UInt8},
    capacity::Csize_t, written::Ptr{Csize_t}, required::Ptr{Csize_t})::Cint
    context == C_NULL && return Cint(VTI.STATUS_NULL_POINTER)
    state = provider_state(context)
    bytes = lock(state.diagnostic_lock) do
        Vector{UInt8}(codeunits(state.last_diagnostic))
    end
    copy_provider_bytes(bytes, output, capacity, written, required)
end

function provider_many(context::Ptr{Cvoid}, others::Ptr{VTI.VtResourceRaw},
    count::Csize_t, output::Ptr{VTI.VtResourceRaw}, operation::Symbol)::Cint
    (context == C_NULL || output == C_NULL || (count != 0 && others == C_NULL)) &&
        return Cint(VTI.STATUS_NULL_POINTER)
    state = provider_state(context)
    try
        result = state.value
        for index in 1:Int(count)
            other = foreign_value(state, unsafe_load(others, index))
            result = operation == :join ? join(result, other) : meet(result, other)
        end
        unsafe_store!(output, new_provider_raw(state, result))
        Cint(VTI.STATUS_OK)
    catch error
        record_failure!(state, error)
        Cint(VTI.STATUS_PROVIDER_ERROR)
    end
end

provider_join_many(context, others, count, output)::Cint =
    provider_many(context, others, count, output, :join)
provider_meet_many(context, others, count, output)::Cint =
    provider_many(context, others, count, output, :meet)

const PROVIDER_RETAIN = Ref{Ptr{Cvoid}}(C_NULL)
const PROVIDER_RELEASE = Ref{Ptr{Cvoid}}(C_NULL)
const PROVIDER_QUERY = Ref{Ptr{Cvoid}}(C_NULL)
const PROVIDER_JOIN = Ref{Ptr{Cvoid}}(C_NULL)
const PROVIDER_MEET = Ref{Ptr{Cvoid}}(C_NULL)
const PROVIDER_EQUAL = Ref{Ptr{Cvoid}}(C_NULL)
const PROVIDER_STABLE_BYTES = Ref{Ptr{Cvoid}}(C_NULL)
const PROVIDER_DIAGNOSTIC = Ref{Ptr{Cvoid}}(C_NULL)
const PROVIDER_JOIN_MANY = Ref{Ptr{Cvoid}}(C_NULL)
const PROVIDER_MEET_MANY = Ref{Ptr{Cvoid}}(C_NULL)
const RESOURCE_TABLE = Ref{VTI.VtResourceVTable}()

function __init__()
    PROVIDER_RETAIN[] = @cfunction(provider_retain, Cvoid, (Ptr{Cvoid},))
    PROVIDER_RELEASE[] = @cfunction(provider_release, Cvoid, (Ptr{Cvoid},))
    PROVIDER_QUERY[] = @cfunction(provider_query, Cint,
        (Ptr{Cvoid}, Ptr{VTI.VtInterfaceId}, UInt32, Ptr{Ptr{Cvoid}}))
    PROVIDER_JOIN[] = @cfunction(provider_join, Cint,
        (Ptr{Cvoid}, Ptr{VTI.VtResourceRaw}, Ptr{VTI.VtResourceRaw}))
    PROVIDER_MEET[] = @cfunction(provider_meet, Cint,
        (Ptr{Cvoid}, Ptr{VTI.VtResourceRaw}, Ptr{VTI.VtResourceRaw}))
    PROVIDER_EQUAL[] = @cfunction(provider_equal, Cint,
        (Ptr{Cvoid}, Ptr{VTI.VtResourceRaw}, Ptr{UInt8}))
    PROVIDER_STABLE_BYTES[] = @cfunction(provider_stable_bytes, Cint,
        (Ptr{Cvoid}, Ptr{UInt8}, Csize_t, Ptr{Csize_t}, Ptr{Csize_t}))
    PROVIDER_DIAGNOSTIC[] = @cfunction(provider_diagnostic, Cint,
        (Ptr{Cvoid}, Ptr{UInt8}, Csize_t, Ptr{Csize_t}, Ptr{Csize_t}))
    PROVIDER_JOIN_MANY[] = @cfunction(provider_join_many, Cint,
        (Ptr{Cvoid}, Ptr{VTI.VtResourceRaw}, Csize_t, Ptr{VTI.VtResourceRaw}))
    PROVIDER_MEET_MANY[] = @cfunction(provider_meet_many, Cint,
        (Ptr{Cvoid}, Ptr{VTI.VtResourceRaw}, Csize_t, Ptr{VTI.VtResourceRaw}))
    RESOURCE_TABLE[] = VTI.VtResourceVTable(
        sizeof(VTI.VtResourceVTable), VTI.ABI_VERSION, 0,
        PROVIDER_RETAIN[], PROVIDER_RELEASE[], PROVIDER_QUERY[])
    nothing
end

function register_provider_raw(value, domain_id::VTI.VtInterfaceId, encode,
    decode, flags::UInt64)
    table = Ref{VTI.VtLatticeVTable}()
    state = ProviderState(1, value, domain_id, encode, decode, flags,
        ReentrantLock(), "", table)
    table[] = VTI.VtLatticeVTable(sizeof(VTI.VtLatticeVTable),
        VTI.LATTICE_INTERFACE_VERSION, 0, flags, domain_id,
        PROVIDER_JOIN[], PROVIDER_MEET[], PROVIDER_EQUAL[],
        PROVIDER_STABLE_BYTES[], PROVIDER_DIAGNOSTIC[], PROVIDER_JOIN_MANY[],
        PROVIDER_MEET_MANY[])
    context = pointer_from_objref(state)
    lock(PROVIDER_REGISTRY_LOCK) do
        PROVIDER_REGISTRY[context] = state
    end
    VTI.VtResourceRaw(context,
        Base.unsafe_convert(Ptr{VTI.VtResourceVTable}, RESOURCE_TABLE))
end

"""
    provider(value; domain_id, encode, decode=nothing, parallel=false)

Expose an immutable Julia lattice value as a versioned `VtResource`. The
16-byte `domain_id` names both its encoding and laws. `encode` must return the
canonical byte representation; `decode` enables cross-provider operations.

Callbacks are synchronous and thread-bound because Julia cannot safely accept
callbacks from unattached native threads. The hot join/meet paths are lock-free;
one short registry lock is used only for retain/release lifetime bookkeeping.
"""
function provider(value::AbstractLattice; domain_id::AbstractString, encode,
    decode=nothing, parallel::Bool=false)
    id = VTI.interface_id(domain_id)
    flags = VTI.LATTICE_FLAG_THREAD_BOUND | VTI.LATTICE_FLAG_STABLE_BYTES |
        VTI.LATTICE_FLAG_BATCH
    parallel && (flags |= VTI.LATTICE_FLAG_PARALLEL_REENTRANT)
    raw = register_provider_raw(value, id, encode, decode, flags)
    VTI.lattice_value(VTI.adopt_resource(raw); take=true)
end

"""Return the Julia value behind an open Julia-hosted lattice provider."""
function host_value(provider::VTI.LatticeValue)
    raw = VTI.raw_resource(provider.resource)
    raw.vtable == Base.unsafe_convert(Ptr{VTI.VtResourceVTable}, RESOURCE_TABLE) ||
        throw(ArgumentError("lattice value is not hosted by LLattice.jl"))
    provider_state(raw.context).value
end

end # module LLattice

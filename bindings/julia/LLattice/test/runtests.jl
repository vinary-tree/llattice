using Test
using LLattice
using VinaryTreeInterop

const VTI = VinaryTreeInterop

@testset "built-in lattice values" begin
    values = MaxMin.(Int64[1, 2, 3])
    @test @inferred(join(values[1], values[3])) == MaxMin(Int64(3))
    @test @inferred(meet(values[1], values[3])) == MaxMin(Int64(1))
    join(values[1], values[3])
    @test @allocated(join(values[1], values[3])) == 0
    @test validate_laws(values)

    @test join(BooleanLattice(false), BooleanLattice(true)) ==
        BooleanLattice(true)
    @test meet(BooleanLattice(false), BooleanLattice(true)) ==
        BooleanLattice(false)
    @test validate_laws((BooleanLattice(false), BooleanLattice(true)))

    left = FiniteSetLattice([1, 2])
    right = FiniteSetLattice([2, 3])
    @test Set(join(left, right)) == Set([1, 2, 3])
    @test Set(meet(left, right)) == Set([2])

    ordered = VectorContentLattice([1, 2, 2])
    reversed = VectorContentLattice([2, 1])
    extended = VectorContentLattice([2, 3])
    @test collect(ordered) == [1, 2]
    @test collect(join(ordered, extended)) == [1, 2, 3]
    @test collect(join(extended, ordered)) == [2, 3, 1]
    @test collect(meet(ordered, extended)) == [2]
    @test ordered == reversed
    @test validate_laws((ordered, reversed, extended))

    bottom = OptionalLattice{MaxMin{Int64}}(nothing)
    present = OptionalLattice(MaxMin(Int64(2)))
    @test join(bottom, present) == present
    @test meet(bottom, present) == bottom
end

encode_i64(value::MaxMin{Int64}) = collect(reinterpret(UInt8, [hton(value.value)]))
decode_i64(bytes) = MaxMin(ntoh(reinterpret(Int64, bytes)[1]))

@testset "host-implementable resource provider" begin
    small = provider(MaxMin(Int64(3)); domain_id="ll.maxmin.i64.v1",
        encode=encode_i64, decode=decode_i64)
    large = provider(MaxMin(Int64(8)); domain_id="ll.maxmin.i64.v1",
        encode=encode_i64, decode=decode_i64)

    @test VTI.flags(small) & VTI.LATTICE_FLAG_THREAD_BOUND != 0
    @test host_value(small) == MaxMin(Int64(3))
    joined = VTI.lattice_join(small, large)
    met = VTI.lattice_meet(small, large)
    @test host_value(joined) == MaxMin(Int64(8))
    @test host_value(met) == MaxMin(Int64(3))
    @test VTI.equivalent(joined, large)
    @test length(VTI.stable_bytes(joined)) == 8

    middle = provider(MaxMin(Int64(5)); domain_id="ll.maxmin.i64.v1",
        encode=encode_i64, decode=decode_i64)
    joined_many = VTI.join_many(small, (middle, large))
    met_many = VTI.meet_many(large, (middle, small))
    @test host_value(joined_many) == MaxMin(Int64(8))
    @test host_value(met_many) == MaxMin(Int64(3))

    foreach(close, (met_many, joined_many, middle, met, joined, large, small))
end

@testset "provider exceptions are contained" begin
    broken = provider(MaxMin(Int64(1)); domain_id="ll.maxmin.i64.v1",
        encode=_ -> error("encoding failed"))
    @test_throws VTI.InteropError VTI.stable_bytes(broken)
    @test occursin("encoding failed", VTI.diagnostic(broken))
    close(broken)
end

@testset "exported API documentation" begin
    exported = filter(name -> Base.isexported(LLattice, name) &&
        name != nameof(LLattice), names(LLattice; all=true))
    documented = Set(keys(Base.Docs.meta(LLattice)))
    @test isempty(filter(exported) do name
        !(Base.Docs.Binding(LLattice, name) in documented)
    end)
end

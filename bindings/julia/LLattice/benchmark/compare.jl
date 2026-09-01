using LLattice
using VinaryTreeInterop

const VTI = VinaryTreeInterop
const ITERATIONS = parse(Int, get(ENV, "LLATTICE_BENCH_ITERATIONS", "10000"))
const SAMPLES = parse(Int, get(ENV, "LLATTICE_BENCH_SAMPLES", "7"))

encode_i64(value::MaxMin{Int64}) = collect(reinterpret(UInt8, [hton(value.value)]))
decode_i64(bytes) = MaxMin(ntoh(reinterpret(Int64, bytes)[1]))

function timed_ns(operation)
    operation()
    started = time_ns()
    operation()
    time_ns() - started
end

function samples(operation)
    measurements = sort!([timed_ns(operation) for _ in 1:SAMPLES])
    measurements[(length(measurements) + 1) ÷ 2], first(measurements),
        last(measurements)
end

function report(name, operations, measurement)
    median_ns, minimum_ns, maximum_ns = measurement
    println("$name\t$operations\t$SAMPLES\t$median_ns\t",
        median_ns / operations, "\t$minimum_ns\t$maximum_ns")
end

left = MaxMin(Int64(3))
right = MaxMin(Int64(8))
direct = samples() do
    value = left
    for _ in 1:ITERATIONS
        value = join(value, right)
    end
    value
end

small = provider(left; domain_id="ll.maxmin.i64.v1", encode=encode_i64,
    decode=decode_i64)
large = provider(right; domain_id="ll.maxmin.i64.v1", encode=encode_i64,
    decode=decode_i64)
pairwise = samples() do
    for _ in 1:ITERATIONS
        result = VTI.lattice_join(small, large)
        close(result)
    end
end
batch_width = min(256, ITERATIONS)
operands = fill(large, batch_width)
batches = cld(ITERATIONS, batch_width)
batched = samples() do
    for _ in 1:batches
        result = VTI.join_many(small, operands)
        close(result)
    end
end

println("path\toperations\tsamples\tmedian_ns\tmedian_ns_per_operation\tminimum_ns\tmaximum_ns")
report("julia_direct", ITERATIONS, direct)
report("c_abi_pairwise", ITERATIONS, pairwise)
report("c_abi_batch", batches * batch_width, batched)

close(large)
close(small)

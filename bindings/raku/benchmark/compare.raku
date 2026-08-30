use v6.d;

use LLattice;

my UInt $iterations = (%*ENV<LLATTICE_BENCH_ITERATIONS> // 10_000).UInt;
my UInt $samples = (%*ENV<LLATTICE_BENCH_SAMPLES> // 7).UInt;
my $left = MaxMin.new(value => 3);
my $right = MaxMin.new(value => 8);

sub timed-ns(&operation --> UInt:D) {
    operation();
    my $started = now;
    operation();
    ((now - $started) * 1_000_000_000).UInt
}

sub measurements(&operation --> List:D) {
    my @values = (^$samples).map({ timed-ns(&operation) }).sort;
    @values[(@values.elems - 1) div 2], @values[0], @values[*-1]
}

sub report(Str:D $name, UInt:D $operations, @measurement --> Nil) {
    my ($median, $minimum, $maximum) = @measurement;
    say "$name\t$operations\t$samples\t$median\t",
        $median / $operations, "\t$minimum\t$maximum";
}

my @direct = measurements({
    my $value = $left;
    $value = $value.join($right) for ^$iterations;
});

sub encode-int(MaxMin:D $item --> Blob:D) {
    Blob.new((^8).map({ ($item.value.Int +> (56 - 8 * $_)) +& 0xff }))
}

my $small = provider($left, domain-id => 'll.maxmin.i64.v1',
    encode => &encode-int);
my $large = provider($right, domain-id => 'll.maxmin.i64.v1',
    encode => &encode-int);
my @pairwise = measurements({
    for ^$iterations {
        my $result = $small.join($large);
        $result.close;
    }
});
my UInt $width = $iterations min 256;
my UInt $batches = ($iterations / $width).ceiling;
my @operands = $large xx $width;
my @batched = measurements({
    for ^$batches {
        my $result = $small.join-many(|@operands);
        $result.close;
    }
});

say "path\toperations\tsamples\tmedian_ns\tmedian_ns_per_operation\tminimum_ns\tmaximum_ns";
report('raku_direct', $iterations, @direct);
report('c_abi_pairwise', $iterations, @pairwise);
report('c_abi_batch', $batches * $width, @batched);

$large.close;
$small.close;

#!/usr/bin/env raku

use v6.d;

my $root = $?FILE.IO.absolute.IO.parent.parent;
my $matrix = $root.add('docs/bindings/completeness-matrix.tsv');
die "missing binding matrix: $matrix" unless $matrix.f;

my @lines = $matrix.lines;
my @header = @lines.shift.split("\t");
my @expected-header = <project language package capability host_idiom lifecycle
    conformance benchmark documentation status>;
die 'binding matrix header has drifted' unless @header eqv @expected-header;

my %rows;
for @lines -> $line {
    my @fields = $line.split("\t", :skip-empty(False));
    die "binding matrix row has {@fields.elems} fields, expected {@header.elems}"
        unless @fields.elems == @header.elems;
    my %row = @header Z=> @fields;
    my $key = "%row<language>\0%row<capability>";
    die "duplicate binding matrix cell: %row<language> / %row<capability>"
        if %rows{$key}:exists;
    die "non-implemented binding matrix cell: $line"
        unless %row<status> eq 'implemented';
    die "binding matrix row has empty evidence: $line"
        if @expected-header.grep({ !%row{$_}.chars });
    %rows{$key} = %row;
}

my @required =
    ['Rust', 'Lattice trait and built-ins'],
    ['Julia', 'built-in lattice values'],
    ['Julia', 'host lattice provider'],
    ['Raku', 'built-in lattice values'],
    ['Raku', 'host lattice provider'];
for @required -> ($language, $capability) {
    die "missing required binding cell: $language / $capability"
        unless %rows{"$language\0$capability"}:exists;
}

my @required-files =
    'bindings/julia/LLattice/Project.toml',
    'bindings/julia/LLattice/src/LLattice.jl',
    'bindings/julia/LLattice/docs/src/index.md',
    'bindings/raku/META6.json',
    'bindings/raku/Build.rakumod',
    'bindings/raku/lib/LLattice.rakumod',
    'bindings/raku/doc/LLattice.rakudoc';
for @required-files -> $relative {
    die "binding package is incomplete: $relative" unless $root.add($relative).f;
}

say "binding matrix is complete ({@lines.elems} cells)";

#!/usr/bin/env perl
# Print column N (1-based) of a CSV file (psql --csv or cypher-shell plain), quotes removed, header skipped.
# Usage: perl scripts/csvcol.pl <N> <file>
use strict; use warnings; use Text::ParseWords;
my ($n, $f) = @ARGV; open my $fh, '<', $f or die "$f: $!"; <$fh>;
while (<$fh>) { s/\r?\n$//; my @c = parse_line(',\s*', 0, $_); print "$c[$n-1]\n"; }

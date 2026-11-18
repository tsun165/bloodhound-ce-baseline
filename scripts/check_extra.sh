#!/usr/bin/env bash
# Checks for follow-up questions Q3, Q4 on one dataset (reads results/<ds>/ and results/<ds>/extra/).
# Usage: scripts/check_extra.sh <ds>
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
ds=$1; R=results/$ds; X=$R/extra
K22='"(MemberOf|Contains|AdminTo|HasSession|GenericAll|GenericWrite|WriteDacl|WriteOwner|Owns|ForceChangePassword|AddMember|AllowedToDelegate|DCSync|GPLink|AllExtendedRights|ReadLAPSPassword|AddSelf|AllowedToAct|CanRDP|CanPSRemote|ExecuteDCOM|SQLAdmin)"'
T=$(mktemp -d)

echo "== Q3: edges_all rows with kind in 22 vs edges_22.csv"
echo "edges_all rows (excl header): $(($(wc -l < $X/edges_all.csv)-1))"
head -1 $X/edges_all.csv > $T/e22_from_all.csv
tail -n +2 $X/edges_all.csv | perl -ne "print if /^(?:\"[^\"]*\"|[^,]*), $K22, /" >> $T/e22_from_all.csv
echo "rows with kind in 22: $(($(wc -l < $T/e22_from_all.csv)-1)); edges_22.csv rows: $(($(wc -l < $R/edges_22.csv)-1))"
cmp -s $T/e22_from_all.csv $R/edges_22.csv && echo "Q3 check: identical to edges_22.csv (same lines, same order)" || { echo "Q3 check: DIFFERENT"; diff $T/e22_from_all.csv $R/edges_22.csv | head -20; }
echo "kinds in edges_all (count):"; perl scripts/csvcol.pl 2 $X/edges_all.csv | sort | uniq -c | sort -rn

echo "== Q4: distinct (src, dist) of ce_paths_22 vs reach_22 rows with dist not NULL"
perl -MText::ParseWords -ne 'next if $.==1; s/\r?\n$//; my @c=parse_line(q{,\s*},0,$_); print "$c[0],$c[1]\n"' $X/ce_paths_22.csv | sort -u > $T/q4.txt
perl -MText::ParseWords -ne 'next if $.==1; s/\r?\n$//; my @c=parse_line(q{,\s*},0,$_); print "$c[0],$c[2]\n" if $c[2] ne "NULL"' $R/reach_22.csv | sort -u > $T/reach.txt
echo "ce_paths_22: rows=$(($(wc -l < $X/ce_paths_22.csv)-1)) distinct src=$(cut -d, -f1 $T/q4.txt | sort -u | wc -l) distinct (src,dist)=$(wc -l < $T/q4.txt)"
echo "reach_22: rows with dist=$(wc -l < $T/reach.txt)"
diff $T/q4.txt $T/reach.txt > $T/q4diff.txt && echo "Q4 check: (src, dist) set identical" || { echo "Q4 check: DIFFERENT"; head -20 $T/q4diff.txt; }
echo "dist histogram (src count):"; cut -d, -f2 $T/q4.txt | sort -n | uniq -c
echo "paths per src: min/max = $(perl scripts/csvcol.pl 1 $X/ce_paths_22.csv | sort | uniq -c | awk 'NR==1{mn=$1;mx=$1} {if($1<mn)mn=$1; if($1>mx)mx=$1} END{print mn"/"mx}')"

echo "== Q4 stability: diff ce_paths_22.csv ce_paths_22_run2.csv"
if diff -q $X/ce_paths_22.csv $X/ce_paths_22_run2.csv >/dev/null; then echo "Q4 stability: identical (byte-for-byte)"; else
  diff $X/ce_paths_22.csv $X/ce_paths_22_run2.csv | head -20
  perl -e 'my %a; for my $i (0,1){ open my $f,"<",$ARGV[$i] or die; <$f>; while(<$f>){ my ($s)=/^("[^"]*"|[^,]*)/; $a{$s}[$i].=$_; } } my $n=grep { ($a{$_}[0]//"") ne ($a{$_}[1]//"") } keys %a; print "Q4 stability: $n src with different path rows (of ".scalar(keys %a)." src)\n";' $X/ce_paths_22.csv $X/ce_paths_22_run2.csv
fi
rm -rf $T

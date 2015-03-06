use strict;
while(<>){
    chomp;
    my @fields = split("\t");
    my @toks = split(" ",$fields[8]);
    my $start1 = $fields[4];
    my $end1 = $fields[5];

    my $start2 = $fields[6];
    my $end2 = $fields[7];
    
    my $gap_start = $end1;
    my $gap_end = $start2 - 1;
#    my $leftArgStr = "ARG1";
#    my $rightArgStr = "ARG2";
    my $lr = 1;
    if($start1 > $start2){
	$gap_start = $end2;
	$gap_end = $start1 - 1;
#	$leftArgStr = "ARG2";
#	$rightArgStr = "ARG1";
	$lr = 0;
    }
    
    my $rel = $fields[1];
 #   my $arg1 = $fields[0];
 #   my $arg2 = $fields[2];
#    print("$rel $arg1 $arg2 ".join(' ',@toks[$gap_start..$gap_end])."\n");
    my @mappedToks = map{normalize($_)} @toks[$gap_start..$gap_end];
    my $str = join(' ',@mappedToks);
    print("$rel\t$lr\t$str\n");

}


sub normalize{
    my $in = shift;
    $in =~ s/\d/<num>/g;
    return $in;
}

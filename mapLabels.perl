use strict;
my $labelMapFile = $ARGV[0]; open(I,$labelMapFile)||die;
my %labelMap = {};
while(<I>){
    chomp;
    my @x = split(" ");
    $labelMap{$x[0]} = $x[1];
}
close(I);

open(I,$ARGV[1])||die;
while(<I>){
    s/(\S+)\s(.*)/$labelMap{$1}\t$2/;
    print;

}



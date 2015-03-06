use strict;
open(I,$ARGV[0])||die;
my $outbase = $ARGV[1];
my %handles;
foreach $i ((1 .. 25)){
    my $h = open(">$outbase/$i");
    $handles{$i} = $h;
}

while(<I>){
    my $o = $_;
    chomp;
    my @fields = split("\t");
    my $len = split(" ",$fields[2]);
    my $of = $handles{$len};
    print $of $o;
}

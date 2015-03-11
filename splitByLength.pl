use strict;
open(I,$ARGV[0])||die;
open(IS,$ARGV[1])||die;

my $outbase = $ARGV[2];
my %handles;
my $i;
my $max = 15;
foreach $i ((1 .. $max)){
    local *FILE;
    open(*FILE,">$outbase-$i.int.txt") || die;
    $handles{$i} = *FILE;
}

my %handles2;
foreach $i ((1 .. $max)){
    local *FILE;
    open(*FILE,">$outbase-$i.string.txt") || die;
    $handles2{$i} = *FILE;
}

while(<I>){
    my $o = $_;
    chomp;
    my $sline = <IS>;
    my @fields = split("\t");
    my $len = split(" ",$fields[1]);
    if($len <= $max){
	my $of = $handles{$len};
	my $of2 = $handles2{$len};
	print $of $o;
	print $of2 $sline;
    }
}

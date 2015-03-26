use strict;
open(I,$ARGV[0])||die;
open(IS,$ARGV[1])||die;

my $outbase = $ARGV[2];
my %handles;
my $i;
my $max = 18;
foreach $i ((1 .. $max)){
    local *FILE;
    open(*FILE,">$outbase-$i.int.txt") || die;
    $handles{$i} = *FILE;
}
local *FILE;
open(*FILE,">$outbase"."int.txt.long") || die;
$handles{-1} = *FILE;



my %handles2;
foreach $i ((1 .. $max)){
    local *FILE;
    open(*FILE,">$outbase-$i.string.txt") || die;
    $handles2{$i} = *FILE;
}
local *FILE;
open(*FILE,">$outbase"."string.txt.long") || die;
$handles2{-1} = *FILE;



while(<I>){
    my $o = $_;
    chomp;
    my $sline = <IS>;
    my @fields = split("\t");
    my $len = split(" ",$fields[1]);
    unless($len <= $max){
	$len = -1;
    }
	die "$len $max" unless(exists $handles{$len});
	my $of = $handles{$len};
	my $of2 = $handles2{$len};
	print $of $o;
	print $of2 $sline;
    
}

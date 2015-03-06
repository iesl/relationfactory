use strict;
my $ff;
my $f1 = $ARGV[0];
my $f2 = $ARGV[1];

my $o1 = $ARGV[2];
my $o2 = $ARGV[3];

open(I,$f1)||die;
open(I2,$f2)||die;

open(O,">$o1")||die;
open(O2,">$o2")||die;

while(<I>){
    chomp;
    my @fields = split("\t");
    my $label = $fields[0];
    my @feats = split("&&&",$fields[1]);

    my %h;
    my $f;
    foreach $ff (@feats){
	my $f = $ff;
	$f=~s/:.*/$1/;

	unless(exists $h{$f}){
	    $h{$f} = 0;
	}
	$h{$f}++;
    }
    my $epLine = <I2>;
    if(scalar(keys %h) > 0){
	my $k;
	print O "$label\t";
	foreach  $k (keys %h){
	    my $count = $h{$k};
	    print O "$k:$count&&&";
	}
	print O "\n";
	print O2 $epLine;
    }#else{
#	print "$label\t&&&\n";
 #   }
}

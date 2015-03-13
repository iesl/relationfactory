use strict;
open(I,$ARGV[0])||die;
open(V,$ARGV[1])||die;
open(L,$ARGV[2])||die;
my $flipLabel = $ARGV[3] == "0";

my %vocab;
my %vocab2;
my $ctr = 1;
while(<V>){
    chomp;
    $vocab{$_} = $ctr;
    $vocab2{$ctr} = $_;
    $ctr++;
}
my $unk_idx = $vocab{"<unk>"};

my %label;
$ctr = 1;
while(<L>){
    chomp;
    $label{$_} = $ctr;
    $ctr++;
}


close V;
close L;

while(<I>){
    my $o = $_;
    chomp;
    my @fields = split("\t");
    my $queryLab = $fields[0];
    if($fields[1] == 0 && $flipLabel){
	$queryLab = $queryLab."-reverse";
    }
    die unless(exists $label{$queryLab});
    my $lab = $label{$queryLab};
    my @strs = split(" ",$fields[2]);
    my @ints = map { 
	$vocab{$_} // $unk_idx
    } @strs;

    if(scalar(@ints) == 0){
	warn $o;
    }

    my $intStr = join(" ",@ints);
    print "$lab\t$intStr\n";

#    my $dbStr = join(" ",map {
#        $vocab2{$_} // "xx"
#    } @ints);
#    print "XX$lab\t$lr\t$dbStr\n";
}

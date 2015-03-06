use strict;
open(I,$ARGV[0])||die;
open(V,$ARGV[1])||die;
open(L,$ARGV[2])||die;

my %vocab;
my $ctr = 1;
while(<V>){
    chomp;
    $vocab{$_} = $ctr;
    $ctr++;
}

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
    chomp;
    my @fields = split("\t");
    my $lab = $label{$fields[0]};
    my $lr = $fields[1];
    my @strs = split(" ",$fields[2]);
    my @ints = map {$vocab{$_}} @strs;
    my $intStr = join(" ",@ints);
    print "$lab\t$lr\t$intStr";
}

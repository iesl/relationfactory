use strict;
open(T,$ARGV[1])||die;
open(I,$ARGV[0])||die;

my %thresh;
while(<T>){
    chomp;
    my @fields = split(" ");
    my $rel = $fields[0];
    my $t = $fields[1];
    $t =~ s/^.t-//;
    $thresh{$rel} = $t;
}

close T;

while(<I>){
    my $o = $_;
    chomp;
    my @fields = split("\t");
    my $rel = $fields[1];
    die unless(exists $thresh{$rel});
    my $t = $thresh{$rel};
    print $o if(($fields[8] + 0.0) > $t);
}

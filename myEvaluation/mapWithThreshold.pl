use strict;
open(I,$ARGV[0])||die;
my $thresh = $ARGV[1]+0;

while(<I>){
    chomp;
    my @fields = split("\t");
    $fields[8] = $fields[8] - $thresh;
    print(join("\t",@fields)."\n");
}

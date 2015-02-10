use strict;
open(I,$ARGV[0])||die;
my $thresh = $ARGV[1];
while(<I>){
    my $o = $_;
    chomp;
    my @fields = split("\t");
    my $score = @fields[scalar(@fields)-1];
    if($score > $thresh){
	print $o;
    } 

}

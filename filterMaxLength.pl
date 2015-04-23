open(I,$ARGV[0])||die;
my $maxLen = $ARGV[1] + 0;

while(<I>){
    my $o = $_;
    chomp;
    my @fields = split("\t");
    my $len = scalar(split(" ",$fields[8]));
    if($len < $maxLen){
	print $o;
    }
}

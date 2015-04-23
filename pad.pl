open(I,$ARGV[0])||die;
my $psize = $ARGV[1] + 0;

my $p = "<PAD>";

while(<I>){
    chomp;
    my @fields = split("\t");
    my @sent = split(" ",$fields[2]);
    my $bit = 1;
    while(scalar(@sent) < $psize){
	if($bit){
	    push(@sent,$p);
	}else{
	    unshift(@sent,$p);
	}
	$bit = 1- $bit;
    }
    my $ss = join(" ",@sent);
    print $fields[0]."\t".$fields[1]."\t".$ss."\n";
}

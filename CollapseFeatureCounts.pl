use strict;
my $ff;
while(<>){
    chomp;
    my @fields = split("\t");
    my $label = $fields[0];
    my @feats = split("&&&",$fields[1]);
#    pop @feats;
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


    if(scalar(keys %h) > 0){

    my $k;
    print "$label\t";
    foreach  $k (keys %h){
	my $count = $h{$k};
	print "$k:$count&&&";
    }
    print "\n";
    }else{
	print "$label\t&&&\n";
    }
}

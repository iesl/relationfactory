while(<>){
    chomp;
    my @fields = split("\t");
    my $label = $fields[0];
    my @feats = split("&&&",$fields[1]);
    pop @feats;
    my %h;
    my $f;
    foreach $ff (@feats){
	my $f = $ff;
	my $f =~ s/:.*//;
	print "f = $f\n";
	unless(exits $h[$f]){
	    $h[$f] = 0
	}
	$h[$f]++;
	print $f."\n";
    }
    print %h;


    if(scalar(keys %h) > 0){
    print $label."\t";
    my $k;
    foreach  $k (keys %h){
	my $count = $h[$k];
	print "$k:$count&&&";
    }
    print "\n";
    }
}

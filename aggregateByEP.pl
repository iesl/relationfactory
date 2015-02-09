use strict;

open(I,$ARGV[0])||die;

my $pE = "";
my @curFeats = ();
my $prototype = "";
my $lc = 0;
while(<I>){
    chomp;
    my @fields = split("\t");
    my $name = join("::",@fields[(0,1,2)]);
    my $feats = $fields[8];
    $feats=~s/^\+1 //;

    unless($name eq $pE){
	if($lc == 0){
	    $prototype = join(@fields[(0 .. 8)]);
	}else{
	    print $prototype." ".join("&&&",@curFeats)."&&&\n";
	}

	@curFeats = ();


	$pE = $name;
	$prototype = join("\t",@fields[(0 .. 8)]); #this takes the provenance information for the first mention
    }
    push(@curFeats,$feats);
    $lc++;
}
print $prototype." ".join("&&&",@curFeats)."&&&\n";

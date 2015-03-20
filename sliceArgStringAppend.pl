use strict;
open(I,$ARGV[0])||die;
open(M,$ARGV[1])||die;
my $flip = $ARGV[2];
my $useTypes = ($ARGV[3] == 1);
my $outsideWidth = $ARGV[4];
my $min_width = 2 + 2*$outsideWidth+2;


my %entT = {};
my %slotT = {};
while(<M>){
    chomp;
    my @fields = split(" ");
    my $name = $fields[0];
    my $t = $fields[1];
    my $type = $fields[2];
    if($t eq "argtag"){
	$slotT{$name} = $type;
    }elsif($t eq "enttype"){
	$entT{$name} =$type;
    }else{
	#die;
    }
}

while(<I>){
    my $o = $_;
    chomp;
    my @fields = split("\t");
    my @toks = split(" ",$fields[8]);
    my $start1 = $fields[4];
    my $end1 = $fields[5];

    my $start2 = $fields[6];
    my $end2 = $fields[7];
    
    my $gap_start = $end1;
    my $gap_end = $start2 - 1;
    my $rel = $fields[1];
    die unless(exists $entT{$rel});
    my $entType = $entT{$rel};
    my $slotType = $slotT{$rel};

    my $left_arg_start = $start1;
    my $right_arg_end = $end2;

    my $leftArgStr = $entType;
    my $rightArgStr = $slotType;
    my $lr = 1;
    my $flipIt = 0;
    if($start1 > $start2){
	$gap_start = $end2;
	$gap_end = $start1 - 1;

	$left_arg_start = $start2;
	$right_arg_end = $end1;
	$lr = 0;
	if($flip){
	    $flipIt = 1;
	}else{
	    $leftArgStr = $slotType;
	    $rightArgStr = $entType;
	}
    }

    unless($useTypes){
	$leftArgStr = "<ARG_START>";
	$rightArgStr = "<ARG_END>";
    }
    

    

    my @mappedToks = map{normalize($_,$flipIt)} @toks[$gap_start..$gap_end];
    
    unshift(@mappedToks,$leftArgStr);
    push(@mappedToks,$rightArgStr);

    if($outsideWidth > 0){
	foreach my $offset ((1..$outsideWidth)){
	    my $idx = $left_arg_start - $offset;
	    if($idx >=0){
		unshift(@mappedToks,$toks[$idx]);
	    }else{
		unshift(@mappedToks,'<PAD>');
	    }

	}
	my $len = scalar(@toks);
	foreach my $offset ((1..$outsideWidth)){
	    my $idx = $right_arg_end + $offset-1;
	    if($idx <=$len){
		push(@mappedToks,$toks[$idx]);
	    }else{
		push(@mappedToks,'<PAD>');
	    }

	}

    }

    
    while(scalar(@mappedToks) < $min_width){
	push(@mappedToks,'<PAD>');
	unshift(@mappedToks,'<PAD>');
    }

    die unless(scalar(@mappedToks) >= $min_width);

    my $str = join(' ',@mappedToks);
    #unless($gap_start > $gap_end){
    print("$rel\t$lr\t$str\n");
    #}#else... is it safe to assume that all the ones with 0 intervening text are 'alternate names'


}


sub normalize{
    my $in = shift;
    my $flipIt = shift;
    $in =~ s/\d/<num>/g;
    if($flipIt){
	$in = $in."-reverse";
    }
    return $in;
}

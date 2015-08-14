
open(I,$ARGV[0])||die; #input file
my $typeFile = $ARGV[1];
my $useTypes = ($ARGV[2] == 1);
my $outsideWidth = $ARGV[3];
my $out = $ARGV[4];

open(O,">$out")||die "can't write to $out\n";

my %entT = {};
my %slotT = {};
if($useTypes){
    open(M,$typeFile)||die; 
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
}

while(<I>){
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
    my $entType = "#Query";
    my $slotType = "#Slot";
    if($useTypes){
	die "relation $rel not found\n" unless(exists $entT{$rel});
	$entType = $entT{$rel};
	$slotType = $slotT{$rel};
    }

    my $left_arg_start = $start1;
    my $right_arg_end = $end2;

    my $leftArgStr = $entType;
    my $rightArgStr = $slotType;
    my $lr = 1;
    if($start1 > $start2){
	$gap_start = $end2;
	$gap_end = $start1 - 1;

	$left_arg_start = $start2;
	$right_arg_end = $end1;
	$lr = 0;
	$leftArgStr = $slotType;
	$rightArgStr = $entType;

    }

    my @mappedToks = @toks[$gap_start..$gap_end];
    if(scalar(@mappedToks) == 0){
	push(@mappedToks,'<EMPTY>');
    }
    
    unshift(@mappedToks,$leftArgStr);
    push(@mappedToks,$rightArgStr);

    if($outsideWidth > 0){
	foreach my $offset ((1..$outsideWidth)){
	    my $idx = $left_arg_start - $offset;
	    if($idx >=0){
		unshift(@mappedToks,$toks[$idx]);
	    }else{
		unshift(@mappedToks,'#PadLeft');
	    }

	}
	my $len = scalar(@toks);
	foreach my $offset ((1..$outsideWidth)){
	    my $idx = $right_arg_end + $offset-1;
	    if($idx <$len){
		push(@mappedToks,$toks[$idx]);
	    }else{
		push(@mappedToks,'#PadRight');
	    }

	}

    }

    my $str = join(' ',@mappedToks);
    if($lr == 0){
	$rel .= "-reverse";
    }
    print O "$rel\t$str\n";

}


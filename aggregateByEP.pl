use strict;

open(I,$ARGV[0])||die;

my $pE = "";
my @curFeats = ();

my $lc = 0;
my %prototypes;
my %examples;
while(<I>){
    chomp;
    my @fields = split("\t");
    my $name = join("::",@fields[(0,1,2)]);
    my $feats = $fields[8];
    $feats=~s/^\+1\s?//;
    $feats=~s/^\s+//;
    
    unless(exists $prototypes{$name}){
	my $prototype = join("\t",@fields[(0 .. 7)]);
	$prototypes{$name} = $prototype;
    }

    unless(exists $examples{$name}){
	$examples{$name} = [];
    }

    unless($feats == ""){
	push(@{$examples{$name}},$feats);
    }
}
close(I);

my $name;
my @names = keys %prototypes;
foreach $name (@names){
    die unless(exists $prototypes{$name});
    if(exists $examples{$name}){
	my $prototype = $prototypes{$name};
	my @curFeats = @{$examples{$name}};
	print $prototype."\t".join("&&&",@curFeats)."&&&\n";
    }else{
	die "failed: $name\n";
    }

}


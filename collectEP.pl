use strict;

open(I,$ARGV[0])||die;
open(L,$ARGV[1])||die;
open(OS,">$ARGV[2]")||die;
open(OL,">$ARGV[3]")||die;

my $prototype_lhs = "";
my @cur_labels = ();
my @cur_sentences = ();
my $cur_EP = "";

my $cnt = 0;
while(<I>){
    chomp;
    my $lhs = <L>;
    my @fields = split("\t");
    my $ep = $fields[0];
    my $label = $fields[1];
    my $sent = $fields[2];

    if($ep eq $cur_EP){
	push(@cur_sentences, $sent);
	push(@cur_labels,$label);
    }else{
	if($cnt > 0){
	    my @cur_labels_mod = uniq(@cur_labels);
	    print OS join(",",@cur_labels_mod)."\t".join(",",@cur_sentences)."\n";
	    print OL $prototype_lhs;
	}
	#reset
	@cur_labels = ();
	@cur_sentences = ();
	$cur_EP = $ep;
	$prototype_lhs = $lhs;

	push(@cur_sentences, $sent);
	push(@cur_labels,$label);
    }
    $cnt++;
}
close(I);
close(L);

sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

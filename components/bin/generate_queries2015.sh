#!/bin/bash
set -e

export PERL5LIB="$TAC_ROOT/components/tac2015/lib"

/opt/perl/bin/perl5.14.2 $TAC_ROOT/components/tac2015/CS-GenerateQueries.pl $@



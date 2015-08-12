#!/bin/sh

#patterns=`$TAC_ROOT/bin/get_expand_config.sh context_patterns /iesl/canvas/beroth/tac/context_patterns2012_coldstart.txt`
patterns=/iesl/canvas/beroth/tac/context_patterns2012_coldstart.txt

candidates=$1
predictions=$2

# PatternResponse <sentences.pb> <patterns>
$TAC_ROOT/components/bin/run.sh run.PatternPrediction $candidates $patterns > $predictions

#!/bin/bash

export rundir=$TAC_ROOT/runs/tune_nn
params="0.5 0.6 0.7 0.8 0.9 0.95 1.0"

#mkdir -p $rundir
#cp /iesl/canvas/beroth/tac/data/candidates2009-2012 $rundir/candidates
#cp /iesl/canvas/beroth/tac/data/query_expanded_2009-2012.xml $rundir/query_expanded.xml


for param in $params
do
 export threshold=$param
 $TAC_ROOT/bin/run.sh $TAC_ROOT/config/tune_nn.config
 mv $rundir/response_nn_pp12 $rundir/response_nn_pp12.$param
 rm $rundir/predictions_nn
done

key=/iesl/canvas/beroth/tac/data/key_2009-2012

/iesl/canvas/belanger/relationfactory/myEvaluation/bin/tunej.sh $key $rundir/response_nn_pp12. $params


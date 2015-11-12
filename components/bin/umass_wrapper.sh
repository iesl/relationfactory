#!/bin/bash
set -e

subdir=$1
query="$(cd "$(dirname "$2")"; pwd)/$(basename "$2")"
response=$3

umass_system=`$TAC_ROOT/bin/get_config.sh umass_system /iesl/canvas/beroth/workspace/tackbp2015`

contexts=`$TAC_ROOT/bin/get_config.sh contexts`
# /iesl/canvas/nmonath/tac/cold-start/codes/tackbp2015_august_20/runs/run_coldstart2015/docs_contexts/`

corpus=`$TAC_ROOT/bin/get_expand_config.sh corpusdatapath`
# /iesl/canvas/proj/tackbp2014/data/LDC2013E45_TAC_2013_KBP_Source_Corpus_disc_2/data/English/`

offsets=`$TAC_ROOT/bin/get_expand_config.sh offsets`

cd $subdir

OFFSETS=$offsets CORPUS=$corpus MAKEFILE=$umass_system/bin/coldstart_single_hop.mk RUNDIR=`pwd` QUERY=$query CONTEXTS=$contexts TAC_ROOT=$umass_system $umass_system/bin/run.sh $umass_system/config/coldstart_single_hop.config response

cd ..
cp $subdir/response $response


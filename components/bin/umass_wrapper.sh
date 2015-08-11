#!/bin/bash
set -e

subdir=$1
query="$(cd "$(dirname "$2")"; pwd)/$(basename "$2")"
response=$3

umass_system=`$TAC_ROOT/bin/get_config.sh umass_system /iesl/canvas/beroth/workspace/tackbp2015`
contexts=`$TAC_ROOT/bin/get_config.sh contexts /iesl/canvas/beroth/workspace/tackbp2015/runs/run_coldstart2014/docs_contexts/`

cd $subdir

MAKEFILE=$umass_system/bin/coldstart_single_hop.mk RUNDIR=`pwd` QUERY=$query CONTEXTS=$contexts TAC_ROOT=$umass_system $umass_system/bin/run.sh $umass_system/config/coldstart_single_hop.config response

cd ..
cp $subdir/response $response


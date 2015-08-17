#!/bin/sh
# Response <query_expanded_xml> <prediction> <team_id>
# a response is written to stdout

runid=`$TAC_ROOT/bin/get_config.sh runid lsv`

$TAC_ROOT/components/bin/run.sh run.PredictionToResponse $1 $2 $runid > $3

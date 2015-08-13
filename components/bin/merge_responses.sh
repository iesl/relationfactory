#!/bin/sh
# merge_responses <query_expanded_xml> <response>*
# a response is written to stdout

runid=`$TAC_ROOT/bin/get_config.sh runid lsv`

# MergeResponses <query_expanded_xml> <teamid> <response>*
$TAC_ROOT/components/bin/run.sh run.MergeResponses $1 $runid ${@:2}

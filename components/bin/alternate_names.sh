#!/bin/sh
# <expanded_query> <dtag> <dscore> <response>
set -e
expanded_query=$1
dtag=$2
dscore=$3
response=$4

RELCONFIG=`$TAC_ROOT/bin/get_expand_config.sh relations.config $TAC_ROOT/config/relations.config`
runid=`$TAC_ROOT/bin/get_config.sh runid lsv`

$TAC_ROOT/components/bin/run.sh run.AlternateNamesCandidates $expanded_query $dtag \
| $TAC_ROOT/components/bin/run.sh run.MatchRealOffsets $dscore \
| $TAC_ROOT/components/bin/run.sh run.AllCandidatesResponse $expanded_query 0.5 $runid \
> $response


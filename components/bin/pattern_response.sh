#!/bin/sh

PATTERNS=`$TAC_ROOT/bin/get_expand_config.sh context_patterns $TAC_ROOT/resources/manual_annotation/context_patterns2012.txt`

query_expanded=$1
candidates=$2
response=$3
fast_match=`$TAC_ROOT/bin/get_config.sh fast_match`

runid=`$TAC_ROOT/bin/get_config.sh runid lsv`

#PatternResponse <query_expanded_xml> <sentences> <patterns> <team_id> [<fast=true|false>]
$TAC_ROOT/components/bin/run.sh run.PatternResponse $query_expanded $candidates $PATTERNS $runid $fast_match > $response

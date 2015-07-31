#!/bin/bash
index=$1

corpusdatapath=`$TAC_ROOT/bin/get_expand_config.sh corpusdatapath`
docidlist=`$TAC_ROOT/bin/get_expand_config.sh docidlist`

$TAC_ROOT/components/bin/run.sh indexir.Indexing $corpusdatapath COLDSTART2014 false $index $docidlist

echo "$TAC_ROOT/components/bin/run.sh indexir.IdFileMapping $index ${index}.idfile_mapping"

$TAC_ROOT/components/bin/run.sh indexir.IdFileMapping $index ${index}.idfile_mapping


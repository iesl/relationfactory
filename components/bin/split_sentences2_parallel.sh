#!/bin/bash

set -e

QUERY_EXPANDED=$1
DSCORE=$2
DRANK=$3

files_per_thread=10000

split -l $files_per_thread -a 4 $DSCORE $DRANK.list

ls $DRANK.list* \
| parallel -j 10 --eta $TAC_ROOT/components/bin/split_sentences2.sh $QUERY_EXPANDED {} {}.out

cat $DRANK.list*.out > $DRANK

rm $DRANK.list*


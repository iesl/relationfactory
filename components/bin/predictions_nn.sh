#!/bin/bash
candidates=$1
prediction=$2
threshold=`$TAC_ROOT/bin/get_config.sh nn_threshold 0.7`

sh /home/belanger/NLPConv/predCmd $candidates $prediction.tmp

cat $prediction.tmp \
| awk -v th="$threshold" 'BEGIN {FS="\t"} {if ($9 > th) print $0}' \
> $prediction

rm $prediction.tmp


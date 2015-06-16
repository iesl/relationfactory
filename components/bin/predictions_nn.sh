#!/bin/bash
candidates=$1
prediction=$2
#Uses a threshold of 0.5

sh /home/belanger/NLPConv/predCmd $candidates $prediction.tmp

cat $prediction.tmp \
awk 'BEGIN {FS="\t"} {if ($9 > 0.5) print $0}' \
> $prediction

rm $prediction.tmp


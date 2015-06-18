#!/bin/bash
threshold_suffix=$1
input=$2
filtered=$3
threshold=`$TAC_ROOT/bin/get_expand_config.sh filter_threshold$threshold_suffix 0.7`

echo "Using threshold: $threshold"

cat $input \
| awk -v th="$threshold" 'BEGIN {FS="\t"} {if ($9 > th) print $0}' \
> $filtered


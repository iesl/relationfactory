#!/bin/bash
input=$1
filtered=$2
threshold=`$TAC_ROOT/bin/get_config.sh nn_threshold 0.7`

echo "Using threshold: $threshold"

cat $input \
| awk -v th="$threshold" 'BEGIN {FS="\t"} {if ($9 > th) print $0}' \
> $filtered


#!/bin/bash
threshold_suffix=$1
input=$2
filtered=$3
thresholds=`$TAC_ROOT/bin/get_expand_config.sh filter_threshold_file$threshold_suffix`

echo "Using threshold file: $thresholds"

$TAC_ROOT/components/bin/run.sh run.FilterPredictionsByThreshold $input $thresholds > $filtered


#!/bin/bash
predictions_inv=$1
predictions=$2

grep $'_inv\t' $predictions_inv \
| sed $'s#_inv\t#\t#g' \
> $predictions.tmp

# flip arguments for inverse predictions
paste <(cut -f3 $predictions.tmp) \
<(cut -f2 $predictions.tmp) \
<(cut -f1 $predictions.tmp) \
<(cut -f4 $predictions.tmp) \
<(cut -f7,8 $predictions.tmp) \
<(cut -f5,6 $predictions.tmp) \
<(cut -f9- $predictions.tmp) \
> $predictions

# append non-inverse predictions
grep -v $'_inv\t' $predictions_inv \
>> $predictions

rm $predictions.tmp


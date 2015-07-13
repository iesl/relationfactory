#!/bin/sh
predictions_inv=$1
predictions=$2

grep $'_inv\t' $predictions_inv \
sed $'s#_inv\t#\t#g' > predictions.tmp

# flip arguments for inverse predictions
paste <(cut -f3 /tmp/beroth/predictions.tmp) \
<(cut -f2 /tmp/beroth/predictions.tmp | sed 's#\(.*\)#\1_inv#g') \
<(cut -f1 /tmp/beroth/predictions.tmp) \
<(cut -f4- /tmp/beroth/predictions.tmp) \
> $predictions

# append non-inverse predictions
grep -v $'_inv\t' $predictions_inv \
>> predictions.tmp


#!/bin/bash 
# Tags sentences in drank format.

ORIGDIR=`pwd`

#/iesl/canvas/beroth/synced/tackbp2015/
cd /iesl/canvas/beroth/workspace/tackbp2015

TAC_ROOT=`pwd` ./bin/wrappers/rf-chunker-wrapper.sh $ORIGDIR/$1 $ORIGDIR/$2.tmp false

cd -

cat $2.tmp | sed 's# L-# I-#g' | sed 's# U-# B-#g' > $2

rm $2.tmp



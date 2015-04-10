#!/bin/bash
# tunej.sh <key_file> <response_prefix> <params>*
# This script takes files of the form <response_prefix><param> and optimizes
# f-score on the TAC collection.
# Two files are written out:
# <response_prefix>tuned -- the response being the result of tuning
# <response_prefix>params -- the optimal parameter value for each relation

key=$1
RESPONSE_PREFIX=$2
PARAMS=${@:3}

export TAC_ROOT=/iesl/canvas/beroth/tac/relationfactory/
RELLIST=`$TAC_ROOT/bin/get_expand_config.sh rellist $TAC_ROOT/config/rellist`
RESPONSE=${RESPONSE_PREFIX}tuned
BEST_PARAMS_FILE=${RESPONSE_PREFIX}params
cp ${RESPONSE_PREFIX}$3 $RESPONSE

slotlist=`mktemp`
cut -f1,2 $RESPONSE \
| tr '\t' ':' \
| sort -u \
> $slotlist

for i in 1 2
do
echo iteration $i
> ${BEST_PARAMS_FILE}

while read REL; do
  echo $REL
  OLD_FSCORE=0.0
  USED_JPARAM=$3
  TMP_RESPONSE=`mktemp`
  for JPARAM in ${PARAMS}
  do
    echo 'j = '${JPARAM}
    grep -v $REL $RESPONSE > $TMP_RESPONSE
    grep $REL ${RESPONSE_PREFIX}${JPARAM} >> $TMP_RESPONSE
#    echo "java -cp $TAC_ROOT/evaluation/bin/ SFScore $TMP_RESPONSE $key slots=$slotlist nocase anydoc"
#    FSCORE=`java -cp $TAC_ROOT/evaluation/bin/ SFScore $TMP_RESPONSE $key slots=$slotlist nocase anydoc | grep 'F1: ' | sed 's#.*F1:\(.*\)#\1#'`
    FSCORE=`/iesl/canvas/belanger/relationfactory/myEvaluation/bin/score2012.sh  $TMP_RESPONSE $key | grep 'F1: ' | sed 's#.*F1:\(.*\)#\1#'`

    echo $FSCORE
    if [ `echo "$FSCORE > $OLD_FSCORE" | bc` == 1 ] 
    then
     OLD_FSCORE=$FSCORE
     USED_JPARAM=$JPARAM
    fi
  done
  grep -v $REL $RESPONSE > $TMP_RESPONSE
  grep $REL ${RESPONSE_PREFIX}${USED_JPARAM} >> $TMP_RESPONSE
  mv $TMP_RESPONSE $RESPONSE

  #echo java -cp $TAC_ROOT/evaluation/bin/ SFScore $RESPONSE $key slots=$slotlist nocase anydoc
  java -cp /iesl/canvas/belanger/relationfactory/myEvaluation/bin/ SFScore $RESPONSE $key slots=$slotlist nocase anydoc | grep -P 'F1: |Precision: |Recall: '

  echo $REL $USED_JPARAM >> ${BEST_PARAMS_FILE}
done < $RELLIST
done

rm $slotlist

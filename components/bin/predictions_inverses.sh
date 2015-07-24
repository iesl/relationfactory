#!/bin/bash
FEATFILE=$1
PREDFILE=$2
RELFILE=`$TAC_ROOT/bin/get_expand_config.sh rellist $TAC_ROOT/config/rellist`
MODELPATH=`$TAC_ROOT/bin/get_expand_config.sh model`

echo
echo "Using relation models from:"
echo $MODELPATH

>$PREDFILE

RELCONFIG=`$TAC_ROOT/bin/get_expand_config.sh relations.config $TAC_ROOT/config/relations_coldstart2015.config`

while read RELATION
do
  echo $RELATION
  MAPPED_RELATION=`cat $RELCONFIG | awk -v rel=$RELATION '$1 == rel && $2 =="inverse" { print $3 }'`

  if [[ -z "$MAPPED_RELATION" ]]
  then
   MAPPED_RELATION=$RELATION
  else
   RELATION=${RELATION}_inv 
   echo "mapped to: $MAPPED_RELATION"
  fi

  MODEL=$MODELPATH/$MAPPED_RELATION.mdl
  
  if [ ! -f $MODEL ]
  then
    echo "==="
    echo "WARNING"
    echo "no model found for relation: $MAPPED_RELATION ($RELATION)"
    echo "... SKIPPING ..."
    echo "==="
    continue      # Skip rest of this particular loop iteration.
  fi

  TMPFILE=`mktemp`
  TMPFEATS=`mktemp`
  TMPBODY=`mktemp`

  cat $FEATFILE \
  | awk -v RELATION=$RELATION -F $'\t' '$2 == RELATION { print $0 }' \
  > $TMPFILE

  cat $TMPFILE | cut -f1-8 > $TMPBODY
  cat $TMPFILE | cut -f9 > $TMPFEATS

  # TODO: enter normal form in config file
  # Not necessary, from 2012 on, relation names can all be valid filenames.
  # NORMREL=`echo $RELATION | tr ':' '_' | tr '/' '_'`
  # MODEL=$MODELPATH/$NORMREL.mdl

  #/home/beroth/libs/svm_light/svm_classify $TMPFEATS $MODEL $TMPFILE
  $TAC_ROOT/lib/svm_light/svm_classify $TMPFEATS $MODEL $TMPFILE
  paste $TMPBODY $TMPFILE >> $PREDFILE

  rm $TMPFILE
  rm $TMPFEATS
  rm $TMPBODY
done < $RELFILE

#!/bin/bash
# provenance invariant scorer for 2012 data
response=$1
key=$2
#optargs="${@:3}"

if [ $# -lt 3 ]
then
   echo 'generating slotlist from response'
   slotlist=`mktemp`
   cut -f1,2 $response \
   | tr '\t' ':' \
   | sort -u \
   > $slotlist
else
   slotlist=$3
fi


echo java -cp /iesl/canvas/belanger/relationfactory/myEvaluation/bin/  SFScore $response $key slots=$slotlist  anydoc nocase 
java -cp /iesl/canvas/belanger/relationfactory/myEvaluation/bin/  SFScore $response $key anydoc nocase | grep -P '\tRecall:|\tPrecision:|\tF1:'

# Delete generated slotlist.
if [ $# -lt 3 ]
then
   rm $slotlist
fi


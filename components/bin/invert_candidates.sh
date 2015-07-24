#!/bin/bash
candidates=$1
candidates_inv=$2

#RELCONFIG=`$TAC_ROOT/bin/get_expand_config.sh relations.config $TAC_ROOT/config/relations.config`
RELCONFIG=/iesl/canvas/beroth/workspace/relationfactory_iesl/config/relations_coldstart2015.config

grep inverse $RELCONFIG \
| cut -d' ' -f1 \
| sed $'s#\(.*\)#\t\\1\t#g' \
> inverses_with_tabs.tmp

grep -f inverses_with_tabs.tmp $candidates > $candidates_inv.tmp

paste <(cut -f3 $candidates_inv.tmp) \
<(cut -f2 $candidates_inv.tmp | sed 's#\(.*\)#\1_inv#g') \
<(cut -f1 $candidates_inv.tmp) \
<(cut -f4 $candidates_inv.tmp) \
<(cut -f7,8 $candidates_inv.tmp) \
<(cut -f5,6 $candidates_inv.tmp) \
<(cut -f9- $candidates_inv.tmp) \
> $candidates_inv

grep -v -f inverses_with_tabs.tmp $candidates >> $candidates_inv

rm inverses_with_tabs.tmp $candidates_inv.tmp

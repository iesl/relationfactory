#!/bin/sh
candidates=$1
candidates_inv=$2

RELCONFIG=`$TAC_ROOT/bin/get_expand_config.sh relations.config $TAC_ROOT/config/relations.config`

grep inverse $RELCONFIG \
| cut -d' ' -f1 \
| sed $'s#\(.*\)#\t\\1\t#g' \
> inverses_with_tabs.tmp

grep -f /tmp/inverses_with_tabs.tmp $candidates > $candidates_inv.tmp

paste <(cut -f3 /tmp/beroth/candidates_inv.tmp) \
<(cut -f2 /tmp/beroth/candidates_inv.tmp | sed 's#\(.*\)#\1_inv#g') \
<(cut -f1 /tmp/beroth/candidates_inv.tmp) \
<(cut -f4- /tmp/beroth/candidates_inv.tmp) \
> $candidates_inv

grep -v -f /tmp/inverses_with_tabs.tmp $candidates >> $candidates_inv

rm inverses_with_tabs.tmp $candidates_inv.tmp

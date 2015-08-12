#!/bin/bash
candidates=$1
candidates_standard_rels=$2

RELS=/iesl/canvas/beroth/workspace/relationfactory_iesl/config/rellist2013

cat $RELS \
| sed $'s#\(.*\)#\t\\1\t#g' \
> standard_rels_with_tabs.tmp

grep -f standard_rels_with_tabs.tmp $candidates > $candidates_standard_rels


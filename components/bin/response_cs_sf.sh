#!/bin/bash
set -e

cat $1 \
 | grep -v NIL \
 | sed '/\&amp;/! s/\&/\&amp;/g' \
 | iconv -c -f UTF-8 -t ASCII > $2

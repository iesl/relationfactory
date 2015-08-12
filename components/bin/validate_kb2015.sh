#!/bin/bash
set -e

input_kb=$1
query=$2
output_kb=$3

docs=`$TAC_ROOT/bin/get_expand_config.sh doclengths`
error_file=${output_kb}.errors

rm -f $output_kb $error_file

$TAC_ROOT/components/tac2015/CS-ValidateSF.pl \
 -docs $docs \
 -error_file $error_file \
 -output_file $output_kb \
 $query \
 $input_kb

cat $error_file


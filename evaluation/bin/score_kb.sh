#!/bin/bash
set -e

submission=$1
queries=$2
scores=$3
error_file=${scores}.error
assessments=`$TAC_ROOT/bin/get_expand_config.sh key`

perl=/opt/perl/bin/perl5.14.2

rm -f $scores $error_file

$perl $TAC_ROOT/evaluation/bin/CS-Score.pl \
 -discipline STRING_CASE \
 -error_file $error_file \
 -output_file $scores \
 $queries \
 $submission \
 $assessments


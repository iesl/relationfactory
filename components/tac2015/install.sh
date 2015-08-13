#!/bin/bash
set -e
cd $TAC_ROOT/components/tac2015
tar xzvf JSON-2.90.tar.gz
basedir=`pwd`
mkdir -p lib
cd JSON-2.90/
perl Makefile.PL PREFIX=$basedir/lib LIB=$basedir/lib
make
make test
make install


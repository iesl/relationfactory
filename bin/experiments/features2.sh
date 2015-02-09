#!/bin/sh

rundir=$TAC_ROOT/runs/run020815
train_sentences=/iesl/canvas/beroth/tac/data/merge_2013.pb
dev_sentences=/iesl/canvas/beroth/tac/data/candidates2009-2012.pb
test_sentences=/iesl/canvas/beroth/tac/data/candidates_2013submission.pb

ln -s $train_sentences ./sentences.train
ln -s $dev_sentences ./sentences.dev
ln -s $test_sentences ./sentences.test


mkdir -p $rundir

brown_classes=false
normalize=false
merge=false
for ext in ngram_directed,skip_exact intertext intertext_short relation
do
for set in train dev test
do
    sentences=./sentences.$set

    $TAC_ROOT/components/bin/run.sh run.Features $rundir/fmap /dev/null $merge true $sentences $rundir/$set.$ext.feats $ext $normalize
done
done


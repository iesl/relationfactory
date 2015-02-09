#!/bin/sh

rundir=$TAC_ROOT/runs/run020815
train_sentences=/iesl/canvas/beroth/tac/data/merge_2013.pb
dev_sentences=/iesl/canvas/beroth/tac/data/candidates_2013submission.pb
test_sentences=$dev_sentences

ln -s $train_sentences ./sentences.train
ln -s $dev_sentences ./sentences.dev
ln -s $test_sentences ./sentences.test


mkdir -p $rundir

brown_classes=false
normalize=false
single_sentence_mode=false
for ext in ngram_directed,skip_exact intertext intertext_short relation
do
for set in train dev
do
    sentences=./sentences.$set

    $TAC_ROOT/components/bin/run.sh run.Features $rundir/fmap /dev/null $single_sentence_mode true $sentences $rundir/$set.$ext.ss-$single_sentence_mode.feats $ext $normalize
done
done


# Makefile to generate TAC-response. 
# Pipeline starts with query.xml and generates response.
#
# This produces a 2013 run merging the output from old and new modules.
#
# Author: Benjamin Roth


candidates:
	cp $(shell $(TAC_ROOT)/bin/get_expand_config.sh candidates) $@


query_expanded.xml:
	cp $(shell $(TAC_ROOT)/bin/get_expand_config.sh query_expanded) $@


# Neural network predictions & response.
predictions_nn_raw: candidates
	$(TAC_ROOT)/components/bin/predictions_nn.sh $+ $@


predictions_nn: predictions_nn_raw
	$(TAC_ROOT)/components/bin/filter_predictions.sh _nn $+ $@

response_nn: query_expanded.xml predictions_nn
	$(TAC_ROOT)/components/bin/response.sh $+ $@

# Postprocess response for 2012 format
%_pp12: % query_expanded.xml
	$(TAC_ROOT)/components/bin/postprocess.sh $+ $@



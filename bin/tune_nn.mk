# Makefile to generate TAC-response. 
# Pipeline starts with query.xml and generates response.
#
# This produces a 2013 run merging the output from old and new modules.
#
# Author: Benjamin Roth

# Neural network predictions & response.
predictions_nn: candidates
	$(TAC_ROOT)/components/bin/predictions_nn.sh $+ $@

response_nn: query_expanded.xml predictions_nn
	$(TAC_ROOT)/components/bin/response.sh $+ $@

# Postprocess response for 2012 format
%_pp12: % query_expanded.xml
	$(TAC_ROOT)/components/bin/postprocess.sh $+ $@



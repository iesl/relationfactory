# Makefile to generate TAC-response. 
# Pipeline starts with query.xml and generates response.
#
# This produces a 2013 run merging the output from old and new modules.
#
# Author: Benjamin Roth

# copies query.xml from location specified in config file
#query.xml:
	cp $(shell $(TAC_ROOT)/bin/get_expand_config.sh query.xml) $@

# Adds expansiond to original queries and explicitly lists relations.
#query_expanded.xml: query.xml
	$(TAC_ROOT)/components/bin/expand_query.sh $+ $@

# Candidates from sentences where Query string and tags match.
candidates: query_expanded.xml dtag dscore
	$(TAC_ROOT)/components/bin/candidates2013.sh $+ $@

# Neural network predictions & response.
predictions_nn: candidates
	$(TAC_ROOT)/components/bin/predictions_nn.sh $+ $@

response_nn: query_expanded.xml predictions_nn
	$(TAC_ROOT)/components/bin/response.sh $+ $@

# Postprocess response for 2014 format.
%_pp14: % query_expanded.xml /dev/null
	$(TAC_ROOT)/components/bin/postprocess2014.sh $+ $@

# Template for postprocessing responses for 2013 format
#%_pp13: % query_expanded.xml title_org.tabs
%_pp13: % query_expanded.xml /dev/null
	$(TAC_ROOT)/components/bin/postprocess2013.sh $+ $@


# Postprocess response for 2012 format
%_pp12: % query_expanded.xml
	$(TAC_ROOT)/components/bin/postprocess2012.sh $+ $@



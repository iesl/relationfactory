# Makefile to generate TAC-response. 
# Pipeline starts with query.xml and generates response.
#
# This produces a 2013 run merging the output from old and new modules.
#
# Author: Benjamin Roth

.SECONDARY:

# copies query.xml from location specified in config file
hop1_query.xml:
	touch $@

# Adds expansiond to original queries and explicitly lists relations.
%_query_expanded.xml: %_query.xml
	touch $@

index:
	touch $@

hop2_query.xml: hop1_query.xml hop1_response_fast_pp14_noNIL
	touch $@

# Retrieves ranked list document ids/files.
%_dscore: %_query_expanded.xml index
	touch $@

# Tokenizes/splits sentences from retrieved docs.
%_drank: %_query_expanded.xml %_dscore
	touch $@

# Tags sentences.
%_dtag: %_drank
	touch $@

# Candidates from sentences where Query string and tags match.
%_candidates: %_query_expanded.xml %_dtag %_dscore
	touch $@

%_candidates_inv: %_candidates
	touch $@
%_candidates_inv.pb: %_candidates_inv
	touch $@
%_sfeatures_inv: %_candidates_inv.pb
	touch $@
%_predictions_classifier_inv: %_sfeatures_inv
	touch $@
%_predictions_classifier: %_predictions_classifier_inv
	touch $@

# Converts candidates into protocol-buffer format.
%_candidates.pb: %_candidates
	touch $@

# Extracts features on a per-sentence level.
%_sfeatures: %_candidates.pb
	touch $@

# Generates TAC-response with 'lsv' team id.
%_response_classifier: %_query_expanded.xml %_predictions_classifier
	touch $@

# Response from pattern matches.
%_response_patterns: %_query_expanded.xml %_candidates.pb
	touch $@

# Response from induced patterns.
%_response_induced_patterns: %_query_expanded.xml %_candidates
	touch $@

# Response from shortened induced patterns.
%_response_shortened_patterns: %_query_expanded.xml %_candidates
	touch $@

# Response from matching query name expansions.
%_response_alternate_names: %_query_expanded.xml %_dtag %_dscore
	touch $@

# modules that run fast (1)
%_response_fast: %_query_expanded.xml %_response_alternate_names %_response_classifier %_response_induced_patterns %_response_patterns
	touch $@

%_response_shortened_patterns_plus: %_query_expanded.xml %_response_alternate_names %_response_classifier %_response_shortened_patterns %_response_induced_patterns %_response_patterns
	touch $@

#response_nosvm: query_expanded.xml response_alternate_names response_induced_patterns response_patterns
#	$(TAC_ROOT)/components/bin/merge_responses.sh $+ > $@

# Modules that have precision >~40% (2)
#response_prec: query_expanded.xml response_alternate_names response_dependency_patterns response_induced_patterns response_patterns
#	$(TAC_ROOT)/components/bin/merge_responses.sh $+ > $@

# Modules that do not include manual patterns. Wiki response is also excluded, as it uses manual patterns, too.
#response_nomanual: query_expanded.xml response_alternate_names response_classifier response_induced_patterns
#	$(TAC_ROOT)/components/bin/merge_responses.sh $+ > $@


#response: response_all_pp13
#	cp -v $< $@

#response2012: response_all_pp12
#	cp -v $< $@

# Postprocess response for 2014 format.
%_pp14: % query_expanded.xml /dev/null
	touch $@


%_noNIL: %
	touch $@

# Template for postprocessing responses for 2013 format
%_pp13: % query_expanded.xml /dev/null
	touch $@


# Postprocess response for 2012 format
%_pp12: % query_expanded.xml
	touch $@

### 2013 submission runs ###

VALIDATION2013_ROOT=$(TAC_ROOT)/evaluation/eval2013/validation

define validate2013
	$(VALIDATION2013_ROOT)/check_kbp_slot-filling.pl $(VALIDATION2013_ROOT)/doc_ids_english.txt query.xml $@
endef

define createRun2013
	$(TAC_ROOT)/bin/addRunId.sh $(1) $(2) > $@
	$(validate2013)
endef

run2013_fast:	response_fast_pp13
	$(call createRun2013,$<,lsv1)

run2013_prec:	response_prec_pp13
	$(call createRun2013,$<,lsv2)

run2013_all:	response_all_pp13
	$(call createRun2013,$<,lsv3)
	
run2013_recall:	response_all_orgs_from_titles_pp13
	$(call createRun2013,$<,lsv4)

#run2013_nomanual:	response_nomanual_pp13
#	$(call createRun2013,$<,lsv5)

run2013_nosyntax:	response_nosyntax_pp13
	$(call createRun2013,$<,lsv5)

2013: run2013_fast run2013_prec run2013_all run2013_recall run2013_nosyntax


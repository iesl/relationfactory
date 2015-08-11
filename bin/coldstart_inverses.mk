# Makefile to generate TAC-response. 
# Pipeline starts with query.xml and generates response.
#
# This produces a 2013 run merging the output from old and new modules.
#
# Author: Benjamin Roth

.SECONDARY:

modules=$(shell $(TAC_ROOT)/bin/get_config.sh modules default)

# copies query.xml from location specified in config file
hop1_query.xml:
	cp $(shell $(TAC_ROOT)/bin/get_expand_config.sh query.xml) $@

# Adds expansiond to original queries and explicitly lists relations.
%_query_expanded.xml: %_query.xml
	$(TAC_ROOT)/components/bin/expand_query.sh $+ $@

index:
	$(TAC_ROOT)/components/bin/create_index.sh $@

hop2_query.xml: hop1_query.xml hop1_response_$(modules)_pp14_noNIL
	/home/beroth/canvas/workspace/tackbp2014/bin/CS-GenerateQueries.pl hop1_query.xml hop2_query.xml hop1_response_$(modules)_pp14_noNIL

# Retrieves ranked list document ids/files.
%_dscore: %_query_expanded.xml index
	$(TAC_ROOT)/components/bin/retrieve_using_index.sh $+ $@

# Tokenizes/splits sentences from retrieved docs.
%_drank: %_query_expanded.xml %_dscore
	$(TAC_ROOT)/components/bin/split_sentences2.sh $+ $@

# Tags sentences.
%_dtag: %_drank
	$(TAC_ROOT)/components/bin/tagging.sh $+ $@

# Candidates from sentences where Query string and tags match.
%_candidates: %_query_expanded.xml %_dtag %_dscore
	$(TAC_ROOT)/components/bin/candidates2013.sh $+ $@

%_candidates_inv: %_candidates
	$(TAC_ROOT)/components/bin/invert_candidates.sh $+ $@
%_candidates_inv.pb: %_candidates_inv
	$(TAC_ROOT)/components/bin/cands_to_proto.sh $+ $@
%_sfeatures_inv: %_candidates_inv.pb
	$(TAC_ROOT)/components/bin/sfeatures.sh $+ $@
%_predictions_classifier_inv: %_sfeatures_inv
	$(TAC_ROOT)/components/bin/predictions_inverses.sh $+ $@
%_predictions_classifier: %_predictions_classifier_inv
	$(TAC_ROOT)/components/bin/undo_invert_predictions.sh $+ $@

%_candidates_standard: %_candidates
	$(TAC_ROOT)/components/bin/filter_standard_rels.sh $+ $@

# Neural network predictions & response.
%_predictions_nn_raw: %_candidates_standard
	$(TAC_ROOT)/components/bin/predictions_nn.sh $+ $@

%_predictions_nn: %_predictions_nn_raw
	$(TAC_ROOT)/components/bin/filter_predictions_tuned.sh _nn  $+ $@

%_response_nn: %_query_expanded.xml %_predictions_nn
	$(TAC_ROOT)/components/bin/response.sh $+ $@

# Converts candidates into protocol-buffer format.
%_candidates.pb: %_candidates
	$(TAC_ROOT)/components/bin/cands_to_proto.sh $+ $@

# Extracts features on a per-sentence level.
%_sfeatures: %_candidates.pb
	$(TAC_ROOT)/components/bin/sfeatures.sh $+ $@

# Generates TAC-response with 'lsv' team id.
%_response_classifier: %_query_expanded.xml %_predictions_classifier
	$(TAC_ROOT)/components/bin/response.sh $+ $@

# Response from pattern matches.
%_response_patterns: %_query_expanded.xml %_candidates.pb
	$(TAC_ROOT)/components/bin/pattern_response.sh $+ $@

# Response from induced patterns.
%_response_induced_patterns: %_query_expanded.xml %_candidates
	$(TAC_ROOT)/components/bin/induced_pattern_response.sh $+ $@

# Response from shortened induced patterns.
%_response_shortened_patterns: %_query_expanded.xml %_candidates
	$(TAC_ROOT)/components/bin/shortened_pattern_response.sh $+ $@

# Response from matching query name expansions.
%_response_alternate_names: %_query_expanded.xml %_dtag %_dscore
	$(TAC_ROOT)/components/bin/alternate_names.sh $+ $@

hop1:
	mkdir -p $@

hop2:
	mkdir -p $@

%_response_umass: % %_query.xml
	$(TAC_ROOT)/components/bin/umass_wrapper.sh $+ $@

# modules that run fast (1)
%_response_fast: %_query_expanded.xml %_response_alternate_names %_response_classifier %_response_induced_patterns %_response_patterns
	$(TAC_ROOT)/components/bin/merge_responses.sh $+ > $@

%_response_default: %_query_expanded.xml %_response_alternate_names %_response_classifier %_response_shortened_patterns %_response_patterns
	$(TAC_ROOT)/components/bin/merge_responses.sh $+ > $@

%_response_all: %_query_expanded.xml %_response_alternate_names %_response_classifier %_response_shortened_patterns %_response_patterns %_response_nn %_response_umass
	$(TAC_ROOT)/components/bin/merge_responses.sh $+ > $@

%_response_stacking: %_query_expanded.xml %_response_classifier %_response_shortened_patterns %_response_patterns %_response_umass
	$(TAC_ROOT)/components/bin/merge_responses.sh $+ > $@

#%_response_shortened_patterns_plus: %_query_expanded.xml %_response_alternate_names %_response_classifier %_response_shortened_patterns %_response_induced_patterns %_response_patterns
#	$(TAC_ROOT)/components/bin/merge_responses.sh $+ > $@
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
hop1_%_pp14: hop1_% hop1_query_expanded.xml /dev/null
	$(TAC_ROOT)/components/bin/postprocess2014.sh $+ $@

hop2_%_pp14: hop2_% hop2_query_expanded.xml /dev/null
	$(TAC_ROOT)/components/bin/postprocess2014.sh $+ $@

%_noNIL: %
	$(TAC_ROOT)/components/bin/response_cs_sf.sh $+ $@
#	grep -v NIL $+ | sed '/\&amp;/! s/\&/\&amp;/g' | iconv -c -f UTF-8 -t ASCII > $@

# Template for postprocessing responses for 2013 format
%_pp13: % query_expanded.xml /dev/null
	$(TAC_ROOT)/components/bin/postprocess2013.sh $+ $@


# Postprocess response for 2012 format
%_pp12: % query_expanded.xml
	$(TAC_ROOT)/components/bin/postprocess.sh $+ $@

response_packaged: hop1_query.xml hop1_response_$(modules)_pp14_noNIL hop2_response_$(modules)_pp14_noNIL
	$(TAC_ROOT)/components/bin/package_kb.sh $+ $@

response_validated: response_packaged hop1_query.xml
	$(TAC_ROOT)/components/bin/validate_kb.sh $+ $@

scores: response_validated hop1_query.xml
	$(TAC_ROOT)/evaluation/bin/score_kb.sh $+ $@

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


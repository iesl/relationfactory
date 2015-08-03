#!/usr/bin/perl

use warnings;
use strict;


binmode(STDOUT, ":utf8");

##################################################################################### 
# This program checks the validity of TAC Cold Start knowledge base variant input
# files. It will also output an updated version of a KB with warnings corrected.
#
# You are receiving this program because you signed up for a partner newsletter
#
# Author: James Mayfield
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "4.2";

##################################################################################### 
# Priority for the selection of problem locations
##################################################################################### 

my %use_priority = (
  MENTION => 1,
  TYPEDEF => 2,
  SUBJECT => 3,
  OBJECT  => 4,
);  

##################################################################################### 
# Mapping from output type to export routine
##################################################################################### 

my %type2export = (
  tac => \&export_tac,
  edl => \&export_edl,
);

my $output_formats = "[" . join(", ", sort keys %type2export) . ", none]";

##################################################################################### 
# Default values
##################################################################################### 

# Can the same assertion be made more than once?
my %multiple_attestations = (
  ONE =>       "only one allowed - no duplicates",
  ONEPERDOC => "at most one allowed per document",
  MANY =>      "any number of duplicate assertions allowed",
);
my $multiple_attestations = 'ONE';

# Which triple labels should be output?
my %output_labels = ();

# Filehandles for program and error output
my $program_output;
my $error_output = *STDERR{IO};

##################################################################################### 
# Library inclusions
##################################################################################### 


#####################################################################################
# Reporting Problems
#####################################################################################

# The following is the default list of problems that can be checked
# for. A different list of problems can be specified as an argument to
# Logger->new(). WARNINGs can be corrected and do not prevent further
# processing. ERRORs permit further error checking, but processing
# does not proceed after that. FATAL_ERRORs cause immediate program
# termination when the error is reported.

my $problem_formats = <<'END_PROBLEM_FORMATS';

# Error Name                   Type     Error Message
# ----------                   ----     -------------

########## Provenance Errors
  ILLEGAL_DOCID                 ERROR    DOCID %s is not a valid DOCID for this task
  ILLEGAL_OFFSET                ERROR    %s is not a valid offset
  ILLEGAL_OFFSET_IN_DOC         ERROR    %s is not a valid offset for DOCID %s
  ILLEGAL_OFFSET_PAIR           ERROR    (%s, %s) is not a valid offset pair
  ILLEGAL_OFFSET_PAIR_STRING    ERROR    %s is not a valid offset pair string
  ILLEGAL_OFFSET_TRIPLE_STRING  ERROR    %s is not a valid docid/offset pair string
  TOO_MANY_PROVENANCE_TRIPLES   WARNING  Too many provenance triples (%d) provided; only the first %d will be used
  TOO_MANY_CHARS                WARNING  Provenance contains too many characters; only the first %d will be used
  TOO_MANY_TOTAL_CHARS          ERROR    All provenance strings contain a total of more than %d characters

########## Knowledge Base Errors
  AMBIGUOUS_PREDICATE           ERROR    %s: ambiguous predicate
  COLON_OMITTED                 WARNING  Initial colon omitted from name of entity %s
  DUPLICATE_ASSERTION           WARNING  The same assertion is made more than once (%s)
  ILLEGAL_CONFIDENCE_VALUE      ERROR    Illegal confidence value: %s
  ILLEGAL_ENTITY_NAME           ERROR    Illegal entity name: %s
  ILLEGAL_ENTITY_TYPE           ERROR    Illegal entity type: %s
  ILLEGAL_PREDICATE             ERROR    Illegal predicate: %s
  ILLEGAL_PREDICATE_TYPE        ERROR    Illegal predicate type: %s
  MISSING_CANONICAL             WARNING  Entity %s has no canonical mention in document %s
  MISSING_INVERSE               WARNING  No inverse relation asserted for %s(%s, %s)
  MISSING_RUNID                 ERROR    The first line of the file does not contain a legal runid
  MISSING_TYPEDEF               WARNING  No type asserted for Entity %s
  MULTIPLE_CANONICAL            ERROR    More than one canonical mention for Entity %s in document %s
  MULTIPLE_FILLS_ENTITY         WARNING  Entity %s has multiple %s fills, but should be single-valued
  MULTIPLE_LINKS                WARNING  More than one link from entity %s to KB %s
  MULTITYPED_ENTITY             ERROR    Entity %s has more than one type: %s
  NO_MENTIONS                   WARNING  Entity %s has no mentions
  PREDICATE_ALIAS               WARNING  Use of %s predicate; %s replaced with %s
  STRING_USED_FOR_ENTITY        ERROR    Expecting an entity, but got string %s
  SUBJECT_PREDICATE_MISMATCH    ERROR    Type of subject (%s) does not match type of predicate (%s)
  UNASSERTED_MENTION            WARNING  Failed to assert that %s in document %s is also a mention
  UNATTESTED_RELATION_ENTITY    ERROR    Relation %s uses entity %s, but that entity id has no mentions in provenance %s
  UNQUOTED_STRING               WARNING  String %s not surrounded by double quotes
  UNKNOWN_TYPE                  ERROR    Cannot infer type for Entity %s

########## Query File Errors
  DUPLICATE_QUERY               WARNING  Duplicate query ID %s
  DUPLICATE_QUERY_FIELD         WARNING  Duplicate <%s> tag
  MALFORMED_QUERY               ERROR    Malformed query %s
  MISMATCHED_TAGS               WARNING  <%s> tag closed with </%s>
  MISSING_QUERY_FIELD           ERROR    Missing <%s> tag in query %s
  NO_QUERIES_LOADED             WARNING  No queries found
  QUERY_WITHOUT_LOADED_PARENT   ERROR    Query %s has parent %s that was not loaded
  UNKNOWN_QUERY_FIELD           WARNING  <%s> is not a recognized query field
  UNLOADED_QUERY                WARNING  Query %s is not present in the query files; skipping it

########## Submission File/Assessment File Errors
  MISMATCHED_RUNID              WARNING  Round 1 uses runid %s but Round 2 uses runid %s; selecting the former
  MULTIPLE_CORRECT_GROUND_TRUTH WARNING  More than one correct choice for ground truth for query %s
  MULTIPLE_FILLS_SLOT           WARNING  Multiple responses given to single-valued slot %s
  MULTIPLE_RUNIDS               WARNING  File contains multiple run IDs (%s, %s)
  UNKNOWN_QUERY_ID              ERROR    Unknown query: %s
  UNKNOWN_RESPONSE_FILE_TYPE    FATAL_ERROR  %s is not a known response file type
  UNKNOWN_SLOT_NAME             ERROR    Unknown slot name: %s
  WRONG_SLOT_NAME               WARNING  Slot %s is not the requested slot for query %s (expected %s)

########## Multi-Use Errors
  WRONG_NUM_ENTRIES             ERROR    Wrong number of entries on line (expected %d, got %d)

END_PROBLEM_FORMATS


#####################################################################################
# Logger
#####################################################################################

package Logger;

# Create a new Logger object
sub new {
  my ($class, $formats, $error_output) = @_;
  $formats = $problem_formats unless $formats;
  my $self = {FORMATS => {}, PROBLEMS => {}, PROBLEM_COUNTS => {}};
  bless($self, $class);
  $self->set_error_output($error_output);
  $self->add_formats($formats);
  $self;
}

# Add additional error formats to an existing Logger
sub add_formats {
  my ($self, $formats) = @_;
  # Convert the problem formats list to an appropriate hash
  chomp $formats;
  foreach (grep {/\S/} grep {!/^\S*#/} split(/\n/, $formats)) {
    s/^\s+//;
    my ($problem, $type, $format) = split(/\s+/, $_, 3);
    $self->{FORMATS}{$problem} = {TYPE => $type, FORMAT => $format};
  }
}

# Get a list of warnings that can be ignored through the -ignore switch
sub get_warning_names {
  my ($self) = @_;
  join(", ", grep {$self->{FORMATS}{$_}{TYPE} eq 'WARNING'} sort keys %{$self->{FORMATS}});
}

# Do not report warnings of the specified type
sub ignore_warning {
  my ($self, $warning) = @_;
  $self->NIST_die("Unknown warning: $warning") unless $self->{FORMATS}{$warning};
  $self->NIST_die("$warning is a fatal error; cannot ignore it") unless $self->{FORMATS}{$warning}{TYPE} eq 'WARNING';
  $self->{IGNORE_WARNINGS}{$warning}++;
}

# Just use the ignore_warning mechanism to delete errors, but don't enforce the warnings-only edict
sub delete_error {
  my ($self, $error) = @_;
  $self->NIST_die("Unknown error: $error") unless $self->{FORMATS}{$error};
  $self->{IGNORE_WARNINGS}{$error}++;
}

# Is a particular error being ignored?
sub is_ignored {
  my ($self, $warning) = @_;
  $self->NIST_die("Unknown error: $warning") unless $self->{FORMATS}{$warning};
  $self->{IGNORE_WARNINGS}{$warning};
}

# Remember that a particular problem was encountered, for later reporting
sub record_problem {
  my ($self, $problem, @args) = @_;
  my $source = pop(@args);
  # Warnings can be suppressed here; errors cannot
  return if $self->{IGNORE_WARNINGS}{$problem};
  my $format = $self->{FORMATS}{$problem} ||
               {TYPE => 'INTERNAL_ERROR',
		FORMAT => "Unknown problem $problem: %s"};
  $self->{PROBLEM_COUNTS}{$format->{TYPE}}++;
  my $type = $format->{TYPE};
  my $message = "$type: " . sprintf($format->{FORMAT}, @args);
  my $where = (ref $source ? "$source->{FILENAME} line $source->{LINENUM}" : 'NO_SOURCE');
  $self->NIST_die($message . (ref $source ? ": $where" : "")) if $type eq 'FATAL_ERROR' || $type eq 'INTERNAL_ERROR';
  $self->{PROBLEMS}{$problem}{$message}{$where}++;
}

# Send error output to a particular file or file handle
sub set_error_output {
  my ($self, $output) = @_;
  if (!$output) {
    $output = *STDERR{IO};
  }
  elsif (!ref $output) {
    if (lc $output eq 'stdout') {
      $output = *STDOUT{IO};
    }
    elsif (lc $output eq 'stderr') {
      $output = *STDERR{IO};
    }
    else {
      $self->NIST_die("File $output already exists") if -e $output;
      open(my $outfile, ">:utf8", $output) or $self->NIST_die("Could not open $output: $!");
      $output = $outfile;
      $self->{OPENED_ERROR_OUTPUT} = 'true';
    }
  }
  $self->{ERROR_OUTPUT} = $output
}

# Retrieve the file handle for error output
sub get_error_output {
  my ($self) = @_;
  $self->{ERROR_OUTPUT};
}

# Close the error output if it was opened here
sub close_error_output {
  my ($self) = @_;
  close $self->{ERROR_OUTPUT} if $self->{OPENED_ERROR_OUTPUT};
}

# Report all of the problems that have been aggregated to the selected error output
sub report_all_problems {
  my ($self) = @_;
  my $error_output = $self->{ERROR_OUTPUT};
  foreach my $problem (sort keys %{$self->{PROBLEMS}}) {
    foreach my $message (sort keys %{$self->{PROBLEMS}{$problem}}) {
      my $num_instances = scalar keys %{$self->{PROBLEMS}{$problem}{$message}};
      print $error_output "$message";
      my $example = (keys %{$self->{PROBLEMS}{$problem}{$message}})[0];
      if ($example ne 'NO_SOURCE') {
	print $error_output " ($example";
	print $error_output " and ", $num_instances - 1, " other place" if $num_instances > 1;
	print $error_output "s" if $num_instances > 2;
	print $error_output ")";
      }
      print $error_output "\n";
    }
  }
  # Return the number of errors and the number of warnings encountered
  ($self->{PROBLEM_COUNTS}{ERROR} || 0, $self->{PROBLEM_COUNTS}{WARNING} || 0);
}

sub get_num_errors {
  my ($self) = @_;
  $self->{PROBLEM_COUNTS}{ERROR} || 0;
}

sub get_num_warnings {
  my ($self) = @_;
  $self->{PROBLEM_COUNTS}{WARNING} || 0;
}

sub get_error_type {
  my ($self, $error_name) = @_;
  $self->{FORMATS}{$error_name}{TYPE};
}

# NIST submission scripts demand an error code of 255 on failure
my $NIST_error_code = 255;

sub NIST_die {
  my ($self, @messages) = @_;
  my $outfile = $self->{ERROR_OUTPUT};
  print $outfile "================================================================\n";
  print $outfile Carp::longmess();
  print $outfile "================================================================\n";
  print $outfile join("", @messages), " at (", join(":", caller), ")\n";
  exit $NIST_error_code;
}

package main;

#####################################################################################
# Patterns
#####################################################################################

package main;

# Eliminate comments, ensuring that pound signs in the middle of
# strings are not treated as comment characters
# Here is the original slightly clearer syntax that unfortunately doesn't work with Perl 5.8
# s/^(
# 	(?:[^#"]*+		      # Any number of chars that aren't double quote or pound sign
# 	  (?:"(?:[^"\\]++|\\.)*+")?   # Any number of double quoted strings
# 	)*+			      # The pair of them repeated any number of times
#   )				      # Everything up to here is captured in $1
#   (\s*\#.*)$/x;		      # Pound sign through the end of the line is not included in the replacement
our $comment_pattern = qr/
      ^(
	(?>
	  (?:
	    (?>[^#"]*)		      # Any number of chars that aren't double quote or pound sign
	    (?:"		      # Beginning of double quoted string
	      (?>		      # Start a possessive match of the string body
		(?:(?>[^"\\]+)|\\.)*  # Possessively match any number of non-double quotes or match an escaped char
	      )"		      # Possessively match the above repeatedly, before the closing double quote
	    )?			      # There might or might not be a double quoted string
	  )*			      # The pair of them repeated any number of times
	)			      # Possessively match everything before a pound sign that starts the comment
      )				      # Everything up to here is captured in $1
      (\s*\#.*)$/x;		      # Pound sign through the end of the line is not included in the replacement

package main;

#####################################################################################
# Provenance
#####################################################################################

package Provenance;

# Bounds from "Task Description for English Slot Filling at TAC-KBP 2014"
my $max_chars_per_triple = 150;
my $max_total_chars = 600;
my $max_triples = 4;

{
  my $docids;

  sub set_docids {
    $docids = $_[0];
  }

  # Validate a particular docid/offset-pair entry. Return the updated
  # start/end pair in case it has been updated
  sub check_triple {
    my ($logger, $where, $docid, $start, $end) = @_;
    my %checks;
    # If the offset triple is illegible, the document ID is set to
    # NO_DOCUMENT. Return failure, but don't report it (as the
    # underlying error has already been reported)
    return if $docid eq 'NO_DOCUMENT';

    if ($start !~ /^\d+$/) {
      $logger->record_problem('ILLEGAL_OFFSET', $start, $where);
      $checks{START} = $logger->get_error_type('ILLEGAL_OFFSET');
    }
    if ($end !~ /^\d+$/) {
      $logger->record_problem('ILLEGAL_OFFSET', $end, $where);
      $checks{END} = $logger->get_error_type('ILLEGAL_OFFSET');
    }
    if (defined $docids && !$docids->{$docid}) {
      $logger->record_problem('ILLEGAL_DOCID', $docid, $where);
      $checks{DOCID} = $logger->get_error_type('ILLEGAL_DOCID');
    }
    if (($checks{START} || '') ne 'ERROR' && ($checks{END} || '') ne 'ERROR') {
      if ($end < $start) {
	$logger->record_problem('ILLEGAL_OFFSET_PAIR', $start, $end, $where);
	$checks{PAIR} = $logger->get_error_type('ILLEGAL_OFFSET_PAIR');
      }
      elsif ($end - $start + 1 > $max_chars_per_triple) {
	$logger->record_problem('TOO_MANY_CHARS', $max_chars_per_triple, $where);
	# Fix the problem by truncating
	$end = $start + $max_chars_per_triple - 1;
	$checks{LENGTH} = $logger->get_error_type('TOO_MANY_CHARS');
      }
    }
    if (defined $docids &&
	($checks{START} || '') ne 'ERROR' &&
	($checks{DOCID} || '') ne 'ERROR') {
      if ($start > $docids->{$docid}) {
	$logger->record_problem('ILLEGAL_OFFSET_IN_DOC', $start, $docid, $where);
	$checks{START_OFFSET} = $logger->get_error_type('ILLEGAL_OFFSET_IN_DOC');
      }
    }
    if (defined $docids &&
	($checks{END} || '') ne 'ERROR' &&
	($checks{DOCID} || '') ne 'ERROR') {
      if ($end > $docids->{$docid}) {
	$logger->record_problem('ILLEGAL_OFFSET_IN_DOC', $end, $docid, $where);
	$checks{END_OFFSET} = $logger->get_error_type('ILLEGAL_OFFSET_IN_DOC');
      }
    }
    foreach (values %checks) {
      return if $_ eq 'ERROR';
    }
    return($start, $end);
  }
}

# This is used to, among other things, get a consistent string
# representing the provenance for use in construction of a UUID
sub tostring {
  my ($self) = @_;
  join(",", map {"$_->{DOCID}:$_->{START}-$_->{END}"}
       sort {$a->{DOCID} cmp $b->{DOCID} ||
	     $a->{START} <=> $b->{START} ||
	     $a->{END} cmp $b->{END}}
       @{$self->{TRIPLES}});
}

# tostring() normalizes provenance entry order; this retains the original order
sub tooriginalstring {
  my ($self) = @_;
  join(",", map {"$_->{DOCID}:$_->{START}-$_->{END}"} @{$self->{TRIPLES}});
}

# Create a new Provenance object
sub new {
  my ($class, $logger, $where, $type, @values) = @_;
  my $self = {LOGGER => $logger, TRIPLES => [], WHERE => $where};
  my $total = 0;
  if ($type eq 'EMPTY') {
    # DO NOTHING
  }
  elsif ($type eq 'DOCID_OFFSET_OFFSET') {
    my ($docid, $start, $end) = @values;
    if (($start, $end) = &check_triple($logger, $where, $docid, $start, $end)) {
      push(@{$self->{TRIPLES}}, {DOCID => $docid,
				 START => $start,
				 END => $end,
				 WHERE => $where});
      $total += $end - $start + 1;
    }
  }
  elsif ($type eq 'DOCID_OFFSETPAIRLIST') {
    my ($docid, $offset_pair_list) = @values;
    my $start;
    my $end;
    foreach my $pair (split(/,/, $offset_pair_list)) {
      unless (($start, $end) = $pair =~ /^\s*(\d+)-(\d+)\s*$/) {
	$logger->record_problem('ILLEGAL_OFFSET_PAIR_STRING', $pair, $where);
	$start = 0;
	$end = 0;
      }
      if (($start, $end) = &check_triple($logger, $where, $docid, $start, $end)) {
	push(@{$self->{TRIPLES}}, {DOCID => $docid,
				   START => $start,
				   END => $end,
				   WHERE => $where});
	$total += $end - $start + 1;
      }
      else {
	return;
      }
    }
  }
  elsif ($type eq 'PROVENANCETRIPLELIST') {
    my ($triple_list) = @values;
    my @triple_list = split(/,/, $triple_list);
    if (@triple_list > $max_triples) {
      $logger->record_problem('TOO_MANY_PROVENANCE_TRIPLES',
			      scalar @triple_list, $max_triples, $where);
      $#triple_list = $max_triples - 1;
    }
    foreach my $triple (@triple_list) {
      my $docid;
      my $start;
      my $end;
      unless (($docid, $start, $end) = $triple =~ /^\s*([^:]+):(\d+)-(\d+)\s*$/) {
	$logger->record_problem('ILLEGAL_OFFSET_TRIPLE_STRING', $triple, $where);
	$docid = 'NO_DOCUMENT';
	$start = 0;
	$end = 0;
      }
      if (($start, $end) = &check_triple($logger, $where, $docid, $start, $end)) {
	push(@{$self->{TRIPLES}}, {DOCID => $docid,
				   START => $start,
				   END => $end,
				   WHERE => $where});
	$total += $end - $start + 1;
      }
    }
  }
  if ($total > $max_total_chars) {
    $logger->record_problem('TOO_MANY_TOTAL_CHARS', $max_total_chars, $where);
  }
  bless($self, $class);
  $self;
}

sub get_docid {
  my ($self, $num) = @_;
  $num = 0 unless defined $num;
  return "NO DOCUMENT" unless @{$self->{TRIPLES}};
  $self->{TRIPLES}[$num]{DOCID};
}

sub get_start {
  my ($self, $num) = @_;
  $num = 0 unless defined $num;
  return 0 unless @{$self->{TRIPLES}};
  $self->{TRIPLES}[$num]{START};
}

sub get_end {
  my ($self, $num) = @_;
  $num = 0 unless defined $num;
  return 0 unless @{$self->{TRIPLES}};
  $self->{TRIPLES}[$num]{END};
}

sub get_num_entries {
  my ($self) = @_;
  scalar @{$self->{TRIPLES}};
}


package main;

#####################################################################################
##### Predicates
#####################################################################################

########################################################################################
# This table lists the legal predicates. An asterisk means the relation is single-valued
########################################################################################

my $predicates_spec = <<'END_PREDICATES';
# DOMAIN         NAME                             RANGE        INVERSE
# ------         ----                             -----        -------
  PER            age*                             STRING       none
  PER,ORG        alternate_names                  STRING       none
  GPE            births_in_city                   PER          city_of_birth*
  GPE            births_in_country                PER          country_of_birth*
  GPE            births_in_stateorprovince        PER          stateorprovince_of_birth*
  PER            cause_of_death*                  STRING       none
  PER            charges                          STRING       none
  PER            children                         PER          parents
  PER            cities_of_residence              GPE          residents_of_city
  PER            city_of_birth*                   GPE          births_in_city
  PER            city_of_death*                   GPE          deaths_in_city
  ORG            city_of_headquarters*            GPE          headquarters_in_city
  PER            countries_of_residence           GPE          residents_of_country
  PER            country_of_birth*                GPE          births_in_country
  PER            country_of_death*                GPE          deaths_in_country
  ORG            country_of_headquarters*         GPE          headquarters_in_country
  ORG            date_dissolved*                  STRING       none
  ORG            date_founded*                    STRING       none
  PER            date_of_birth*                   STRING       none
  PER            date_of_death*                   STRING       none
  GPE            deaths_in_city                   PER          city_of_death*
  GPE            deaths_in_country                PER          country_of_death*
  GPE            deaths_in_stateorprovince        PER          stateorprovince_of_death*
  PER            employee_or_member_of            ORG,GPE      employees_or_members
  ORG,GPE        employees_or_members             PER          employee_or_member_of
  ORG            founded_by                       PER,ORG,GPE  organizations_founded
  GPE            headquarters_in_city             ORG          city_of_headquarters*
  GPE            headquarters_in_country          ORG          country_of_headquarters*
  GPE            headquarters_in_stateorprovince  ORG          stateorprovince_of_headquarters*
  PER,ORG,GPE    holds_shares_in                  ORG          shareholders
  ORG,GPE        member_of                        ORG          members
  ORG            members                          ORG,GPE      member_of
  ORG            number_of_employees_members*     STRING       none
  PER,ORG,GPE    organizations_founded            ORG          founded_by
  PER            origin                           STRING       none
  PER            other_family                     PER          other_family
  PER            parents                          PER          children
  ORG            parents                          ORG,GPE      subsidiaries
  ORG            political_religious_affiliation  STRING       none
  PER            religion*                        STRING       none
  GPE            residents_of_city                PER          cities_of_residence
  GPE            residents_of_country             PER          countries_of_residence
  GPE            residents_of_stateorprovince     PER          statesorprovinces_of_residence
  PER            schools_attended                 ORG          students
  ORG            shareholders                     PER,ORG,GPE  holds_shares_in
  PER            siblings                         PER          siblings
  PER            spouse                           PER          spouse
  PER            stateorprovince_of_birth*        GPE          births_in_stateorprovince
  PER            stateorprovince_of_death*        GPE          deaths_in_stateorprovince
  ORG            stateorprovince_of_headquarters* GPE          headquarters_in_stateorprovince
  PER            statesorprovinces_of_residence   GPE          residents_of_stateorprovince
  ORG            students                         PER          schools_attended
  ORG,GPE        subsidiaries                     ORG          parents
  PER            title                            STRING       none
  PER            top_member_employee_of           ORG          top_members_employees
  ORG            top_members_employees            PER          top_member_employee_of
  ORG            website*                         STRING       none
# The following are not TAC slot filling predicates, but rather
# predicates required by the Cold Start task
  PER,ORG,GPE    mention                          STRING       none
  PER,ORG,GPE    canonical_mention                STRING       none
  PER,ORG,GPE    type                             TYPE         none
  PER,ORG,GPE    link                             STRING       none
END_PREDICATES

#####################################################################################
# This table lists known aliases of the legal predicates.
#####################################################################################

my $predicate_aliases = <<'END_ALIASES';
# REASON        DOMAIN    ALIAS                               MAPS TO
# ------        ------    -----                               -------
  DEPRECATED    ORG       dissolved                           date_dissolved
  DEPRECATED    PER       employee_of                         employee_or_member_of
  DEPRECATED    ORG,GPE   employees                           employees_or_members
  DEPRECATED    ORG       founded                             date_founded
  DEPRECATED    PER       member_of                           employee_or_member_of
  DEPRECATED    ORG,GPE   membership                          employees_or_members
  DEPRECATED    ORG       number_of_employees/members         number_of_employees_members
  DEPRECATED    ORG       political/religious_affiliation     political_religious_affiliation
  DEPRECATED    PER       stateorprovinces_of_residence       statesorprovinces_of_residence
  DEPRECATED    ORG       top_members/employees               top_members_employees
  MISSPELLED    PER       ages                                age
  MISSPELLED    ANY       canonical_mentions                  canonical_mention
  MISSPELLED    PER       city_of_residence                   cities_of_residence
  MISSPELLED    PER       country_of_residence                countries_of_residence
  MISSPELLED    ANY       mentions                            mention
  MISSPELLED    PER       spouses                             spouse
  MISSPELLED    PER       stateorprovince_of_residence        statesorprovinces_of_residence
  MISSPELLED    PER       titles                              title
END_ALIASES

package PredicateSet;

# Populate the set of predicate aliases from $predicate_aliases (defined at the top of this file)
my %predicate_aliases;
foreach (grep {!/^\s*#/} split(/\n/, lc $predicate_aliases)) {
  my ($reason, $domains, $alias, $actual) = split;
  foreach my $domain (split(/,/, $domains)) {
    $predicate_aliases{$domain}{$alias} = {REASON => $reason, REPLACEMENT => $actual};
  }
}

sub build_hash { map {$_ => 'true'} @_ }
# Set of legal domain types (e.g., {PER, ORG, GPE})
our %legal_domain_types = &build_hash(qw(per gpe org));
# Set of legal range types (e.g., {PER, ORG, GPE})
our %legal_range_types = &build_hash(qw(per gpe org string type));
# Set of types that are entities
our %legal_entity_types = &build_hash(qw(per gpe org));

# Is one type specification compatible with another?  The second
# argument must be a hash representing a set of types. The first
# argument may either be the same representation, or a single type
# name. The two are compatible if the second is a (possibly improper)
# superset of the first.
sub is_compatible {
  my ($type, $typeset) = @_;
  my @type_names;
  if (ref $type) {
    @type_names = keys %{$type};
  }
  else {
    @type_names = ($type);
  }
  foreach (@type_names) {
    return unless $typeset->{$_};
  }
  return "compatible";
}

# Find all predicates with the given name that are compatible with the
# domain and range given, if any
sub lookup_predicate {
  my ($self, $name, $domain, $range) = @_;
  my @candidates = @{$self->{$name} || []};
  @candidates = grep {&is_compatible($domain, $_->get_domain())} @candidates if defined $domain;
  @candidates = grep {&is_compatible($range, $_->get_range())} @candidates if defined $range;
  @candidates;
}

# Create a new PredicateSet object
sub new {
  my ($class, $logger, $label, $spec) = @_;
  $label = 'TAC' unless defined $label;
  $spec = $predicates_spec unless defined $spec;
  my $self = {LOGGER => $logger};
  bless($self, $class);
  $self->add_predicates($label, $spec) if defined $spec;
  $self;
}

# Populate the predicates tables from $predicates, which is defined at
# the top of this file, or from a user-defined specification
sub add_predicates {
  my ($self, $label, $spec) = @_;
  chomp $spec;
  foreach (grep {!/^\s*#/} split(/\n/, lc $spec)) {
    my ($domain, $name, $range, $inverse) = split;
    # The "single-valued" marker (asterisk) is handled by Predicate->new
    my $predicate = Predicate->new($self, $domain, $name, $range, $inverse, $label);
    $self->add_predicate($predicate);
  }
  $self;
}

sub add_predicate {
  my ($self, $predicate) = @_;
  # Don't duplicate predicates
  foreach my $existing (@{$self->{$predicate->{NAME}}}) {
    return if $predicate == $existing;
  }
  push(@{$self->{$predicate->{NAME}}}, $predicate);
}

# Find the correct predicate name for this (verb, subject, object)
# triple, performing a variety of error checks
sub get_predicate {
  # The source appears as the last argument passed; preceding
  # arguments are not necessarily present
  my $source = pop(@_);
  my ($self, $verb, $subject_type, $object_type) = @_;
  return $verb if ref $verb;
  $subject_type = lc $subject_type if defined $subject_type;
  $object_type = lc $object_type if defined $object_type;
  my $domain_string = $subject_type;
  my $range_string = $object_type;
  if ($verb =~ /^(.*?):(.*)$/) {
    $domain_string = lc $1;
    $verb = $2;
    unless($PredicateSet::legal_domain_types{$domain_string}) {
      $self->{LOGGER}->record_problem('ILLEGAL_PREDICATE_TYPE', $domain_string, $source);
      return;
    }
  }
  if (defined $domain_string &&
      defined $subject_type &&
      $PredicateSet::legal_domain_types{$subject_type} &&
      $domain_string ne $subject_type) {
    $self->{LOGGER}->record_problem('SUBJECT_PREDICATE_MISMATCH',
				    $subject_type,
				    $domain_string,
				    $source);
    return;
  }
  $verb = $self->rewrite_predicate($verb, $domain_string || $subject_type || 'any', $source);
  my @candidates = $self->lookup_predicate($verb, $domain_string, $range_string);
  unless (@candidates) {
    $self->{LOGGER}->record_problem('ILLEGAL_PREDICATE', $verb, $source);
    return 'undefined';
  }
  return $candidates[0] if @candidates == 1;
  $self->{LOGGER}->record_problem('AMBIGUOUS_PREDICATE', $verb, $source);
  return 'ambiguous';
}

# Rewrite this predicate name if it is an alias
sub rewrite_predicate {
  my ($self, $predicate, $domain, $source) = @_;
  my $alias = $predicate_aliases{lc $domain}{$predicate} ||
              $predicate_aliases{'any'}{$predicate};
  return $predicate unless defined $alias;
  $self->{LOGGER}->record_problem('PREDICATE_ALIAS',
				  $alias->{REASON},
				  $predicate,
				  $alias->{REPLACEMENT},
				  $source);
  $alias->{REPLACEMENT};
}

# Load predicates from a file. This allows additional user-defined predicates.
sub load {
  my ($self, $filename) = @_;
  my $base_filename = $filename;
  $base_filename =~ s/.*\///;
  $self->{LOGGER}->NIST_die("Filename for predicates files should be <label>.predicates.txt")
    unless $base_filename =~ /^(\w+)\.predicates.txt$/;
  my $label = uc $1;
  open(my $infile, "<:utf8", $filename)
    or $self->{LOGGER}->NIST_die("Could not open $filename: $!");
  local($/);
  my $predicates = <$infile>;
  close $infile;
  $self->add_predicates($label, $predicates);
}

#####################################################################################
# Predicate
#####################################################################################

package Predicate;

# Create a new Predicate object
sub new {
  my ($class, $predicates, $domain_string, $original_name, $range_string, $original_inverse_name, $label) = @_;
  # Convert the comma-separated list of types to a hash
  my $domain = {map {$_ => 'true'} split(/,/, lc $domain_string)};
  # Make sure each type is legal
  foreach my $type (keys %{$domain}) {
    $predicates->{LOGGER}->NIST_die("Illegal domain type: $type")
      unless $PredicateSet::legal_domain_types{$type};
  }
  # Do the same for the range
  my $range = {map {$_ => 'true'} split(/,/, lc $range_string)};
  foreach my $type (keys %{$range}) {
    $predicates->{LOGGER}->NIST_die("Illegal range type: $type")
      unless $PredicateSet::legal_range_types{$type};
  }
  my $name = $original_name;
  my $inverse_name = $original_inverse_name;
  my $quantity = 'list';
  my $inverse_quantity = 'list';
  # Single-valued slots are indicated by a trailing asterisk in the predicate name
  if ($name =~ /\*$/) {
    substr($name, -1, 1, '');
    $quantity = 'single';
  }
  if ($inverse_name =~ /\*$/) {
    substr($inverse_name, -1, 1, '');
    $inverse_quantity = 'single';
  }
  # If this predicate has already been defined, make sure that
  # definition is compatible with the current one, then return it
  my @predicates = $predicates->lookup_predicate($name, $domain, $range);
  $predicates->{LOGGER}->NIST_die("More than one predicate defined for " .
				  "$name($domain_string, $range_string)")
    if @predicates > 1;
  my $predicate;
  if (@predicates) {
    $predicate = $predicates[0];
    my $current_inverse_name = $predicate->get_inverse_name();
    $predicates->{LOGGER}->NIST_die("Attempt to redefine inverse of predicate " .
				    "$domain_string:$name from $current_inverse_name " .
				    "to $inverse_name")
      unless $current_inverse_name eq $inverse_name;
    $predicates->{LOGGER}->NIST_die("Attempt to redefine quantity of predicate " .
				    "$domain_string:$name from $predicate->{QUANTITY} " .
				    "to $quantity")
	unless $predicate->{QUANTITY} eq $quantity;
    my @inverses = $predicates->lookup_predicate($inverse_name, $range, $domain);
    $predicates->{LOGGER}->NIST_die("Multiple inverses with form " .
				    "$inverse_name($range_string, $domain_string)")
      if (@inverses > 1);
    if (@inverses) {
      my $current_inverse = $inverses[0];
      $predicates->{LOGGER}->NIST_die("Attempt to redefine inverse of $domain_string:$name")
	if defined $predicate->{INVERSE} && $predicate->{INVERSE} ne $current_inverse;
    }
    return $predicate;
  }
  # This predicate has not been defined already, so build it. INVERSE is added below.
  $predicate = bless({NAME         => $name,
		      LABEL        => $label,
		      DOMAIN       => $domain,
		      RANGE        => $range,
		      INVERSE_NAME => $inverse_name,
		      QUANTITY     => $quantity},
		     $class);
  # Save the new predicate in $predicates
  $predicates->add_predicate($predicate);
  # Automatically generate the inverse predicate
  $predicate->{INVERSE} = $class->new($predicates, $range_string,
				      $original_inverse_name, $domain_string,
				      $original_name, $label)
    unless $inverse_name eq 'none';
  $predicate;
}

# Handy selectors
sub get_name {$_[0]->{NAME}}
sub get_domain {$_[0]->{DOMAIN}}
sub get_range {$_[0]->{RANGE}}
sub get_inverse {$_[0]->{INVERSE}}
sub get_inverse_name {$_[0]->{INVERSE_NAME}}
sub get_quantity {$_[0]->{QUANTITY}}

package main;

# I don't know where this script will be run, so pick a reasonable
# screen width for describing program usage (with the -help switch)
my $terminalWidth = 80;


#####################################################################################
# This switch processing code written many years ago by James Mayfield
# and used here with permission. It really has nothing to do with
# TAC KBP; it's just a partial replacement for getopt that closely ties
# the documentation to the switch specification. The code may well be cheesy,
# so no peeking.
#####################################################################################

package SwitchProcessor;

sub _max {
    my $first = shift;
    my $second = shift;
    $first > $second ? $first : $second;
}

sub _quotify {
    my $string = shift;
    if (ref($string)) {
	join(", ", @{$string});
    }
    else {
	(!$string || $string =~ /\s/) ? "'$string'" : $string;
    }
}

sub _formatSubs {
    my $value = shift;
    my $switch = shift;
    my $formatted;
    if ($switch->{SUBVARS}) {
	$formatted = "";
	foreach my $subval (@{$value}) {
	    $formatted .= " " if $formatted;
	    $formatted .= _quotify($subval);
	}
    }
    # else if this is a constant switch, omit the vars [if they match?]
    else {
	$formatted = _quotify($value);
    }
    $formatted;
}

# Print an error message, display program usage, and exit unsuccessfully
sub _barf {
    my $self = shift;
    my $errstring = shift;
    open(my $handle, "|more") or Logger->new()->NIST_die("Couldn't even barf with message $errstring");
    print $handle "ERROR: $errstring\n";
    $self->showUsage($handle);
    close $handle;
    exit(-1);
}

# Create a new switch processor.  Arguments are the name of the
# program being run, and deneral documentation for the program
sub new {
    my $classname = shift;
    my $self = {};
    bless ($self, $classname);
    $self->{PROGNAME} = shift;
    $self->{PROGNAME} =~ s(^.*/)();
    $self->{DOCUMENTATION} = shift;
    $self->{POSTDOCUMENTATION} = shift;
    $self->{HASH} = {};
    $self->{PARAMS} = [];
    $self->{SWITCHWIDTH} = 0;
    $self->{PARAMWIDTH} = 0;
    $self->{SWITCHES} = {};
    $self->{VARSTOCHECK} = ();
    $self->{LEGALVARS} = {};
    $self->{PROCESS_INVOKED} = undef;
    $self;
}

# Fill a paragraph, with different leaders for first and subsequent lines
sub _fill {
    $_ = shift;
    my $leader1 = shift;
    my $leader2 = shift;
    my $width = shift;
    my $result = "";
    my $thisline = $leader1;
    my $spaceOK = undef;
    foreach my $word (split) {
	if (length($thisline) + length($word) + 1 <= $width) {
	    $thisline .= " " if ($spaceOK);
	    $spaceOK = "TRUE";
	    $thisline .= $word;
	}
	else {
	    $result .= "$thisline\n";
	    $thisline = "$leader2$word";
	    $spaceOK = "TRUE";
	}
    }
    "$result$thisline\n";
}

# Show program usage
sub showUsage {
    my $self = shift;
    my $handle = shift;
    open($handle, "|more") unless defined $handle;
    print $handle _fill($self->{DOCUMENTATION}, "$self->{PROGNAME}:  ",
			" " x (length($self->{PROGNAME}) + 3), $terminalWidth);
    print $handle "\nUsage: $self->{PROGNAME}";
    print $handle " {-switch {-switch ...}}"
	if (keys(%{$self->{SWITCHES}}) > 0);
    # Count the number of optional parameters
    my $optcount = 0;
    # Print each parameter
    foreach my $param (@{$self->{PARAMS}}) {
	print $handle " ";
	print $handle "{" unless $param->{REQUIRED};
	print $handle $param->{NAME};
	$optcount++ if (!$param->{REQUIRED});
	print $handle "..." if $param->{ALLOTHERS};
    }
    # Close out the optional parameters
    print $handle "}" x $optcount;
    print $handle "\n\n";
    # Show details of each switch
    my $headerprinted = undef;
    foreach my $key (sort keys %{$self->{SWITCHES}}) {
	my $usage = "  $self->{SWITCHES}->{$key}->{USAGE}" .
	    " " x ($self->{SWITCHWIDTH} - length($self->{SWITCHES}->{$key}->{USAGE}) + 2);
	if (defined($self->{SWITCHES}->{$key}->{DOCUMENTATION})) {
	    print $handle "Legal switches are:\n"
		unless defined($headerprinted);
	    $headerprinted = "TRUE";
	    print $handle _fill($self->{SWITCHES}->{$key}->{DOCUMENTATION},
			$usage,
			" " x (length($usage) + 2),
			$terminalWidth);
	}
    }
    # Show details of each parameter
    if (@{$self->{PARAMS}} > 0) {
	print $handle "parameters are:\n";
	foreach my $param (@{$self->{PARAMS}}) {
	    my $usage = "  $param->{USAGE}" .
		" " x ($self->{PARAMWIDTH} - length($param->{USAGE}) + 2);
	    print $handle _fill($param->{DOCUMENTATION}, $usage, " " x (length($usage) + 2), $terminalWidth);
	}
    }
    print $handle "\n$self->{POSTDOCUMENTATION}\n" if $self->{POSTDOCUMENTATION};
}

# Retrieve all keys defined for this switch processor
sub keys {
    my $self = shift;
    keys %{$self->{HASH}};
}

# Add a switch that causes display of program usage
sub addHelpSwitch {
    my $self = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    my $switch = SP::_Switch->newHelp($filename, $line, @_);
    $self->_addSwitch($filename, $line, $switch);
}

# Add a switch that causes a given variable(s) to be assigned a given
# constant value(s)
sub addConstantSwitch {
    my $self = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    my $switch = SP::_Switch->newConstant($filename, $line, @_);
    $self->_addSwitch($filename, $line, $switch);
}

# Add a switch that assigns to a given variable(s) value(s) provided
# by the user on the command line
sub addVarSwitch {
    my $self = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    my $switch = SP::_Switch->newVar($filename, $line, @_);
    $self->_addSwitch($filename, $line, $switch);
}

# Add a switch that invokes a callback as soon as it is encountered on
# the command line.  The callback receives three arguments: the switch
# object (which is needed by the internal routines, but presumably may
# be ignored by user-defined functions), the switch processor, and all
# the remaining arguments on the command line after the switch (as the
# remainder of @_, not a reference).  If it returns, it must return
# the list of command-line arguments that remain after it has dealt
# with whichever ones it wants to.
sub addImmediateSwitch {
    my $self = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    my $switch = SP::_Switch->newImmediate($filename, $line, @_);
    $self->_addSwitch($filename, $line, $switch);
}

sub addMetaSwitch {
    my $self = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    my $switch = SP::_Switch->newMeta($filename, $line, @_);
    $self->_addSwitch($filename, $line, $switch);
}

# Add a new switch
sub _addSwitch {
    my $self = shift;
    my $filename = shift;
    my $line = shift;
    my $switch = shift;
    # Can't add switches after process() has been invoked
    Logger->new()->NIST_die("Attempt to add a switch after process() has been invoked, at $filename line $line\n")
	if ($self->{PROCESS_INVOKED});
    # Bind the switch object to its name
    $self->{SWITCHES}->{$switch->{NAME}} = $switch;
    # Remember how much space is required for the usage line
    $self->{SWITCHWIDTH} = _max($self->{SWITCHWIDTH}, length($switch->{USAGE}))
	if (defined($switch->{DOCUMENTATION}));
    # Make a note of the variable names that are legitimized by this switch
    $self->{LEGALVARS}->{$switch->{NAME}} = "TRUE";
}

# Add a new command-line parameter
sub addParam {
    my ($shouldBeUndef, $filename, $line) = caller;
    my $self = shift;
    # Can't add params after process() has been invoked
    Logger->new()->NIST_die("Attempt to add a param after process() has been invoked, at $filename line $line\n")
	if ($self->{PROCESS_INVOKED});
    # Create the parameter object
    my $param = SP::_Param->new($filename, $line, @_);
    # Remember how much space is required for the usage line
    $self->{PARAMWIDTH} = _max($self->{PARAMWIDTH}, length($param->{NAME}));
    # Check for a couple of potential problems with parameter ordering
    if (@{$self->{PARAMS}} > 0) {
	my $previous = ${$self->{PARAMS}}[$#{$self->{PARAMS}}];
        Logger->new()->NIST_die("Attempt to add param after an allOthers param, at $filename line $line\n")
	    if ($previous->{ALLOTHERS});
        Logger->new()->NIST_die("Attempt to add required param after optional param, at $filename line $line\n")
	    if ($param->{REQUIRED} && !$previous->{REQUIRED});
    }
    # Make a note of the variable names that are legitimized by this param
    $self->{LEGALVARS}->{$param->{NAME}} = "TRUE";
    # Add the parameter object to the list of parameters for this program
    push(@{$self->{PARAMS}}, $param);
}

# Set a switch processor variable to a given value
sub put {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    $self->_varNameCheck($filename, $line, $key, undef);
    my $switch = $self->{SWITCHES}->{$key};
    Logger->new()->NIST_die("Wrong number of values in second argument to put, at $filename line $line.\n")
	if ($switch->{SUBVARS} &&
	    (!ref($value) ||
	     scalar(@{$value}) != @{$switch->{SUBVARS}}));
    $self->{HASH}->{$key} = $value;
}

# Get the value of a switch processor variable
sub get {
    my $self = shift;
    my $key = shift;
    # Internally, we sometimes want to do a get before process() has
    # been invoked.  The secret second argument to get allows this.
    my $getBeforeProcess = shift;
    my ($shouldBeUndef, $filename, $line) = caller;
    Logger->new()->NIST_die("Get called before process, at $filename line $line\n")
	if (!$self->{PROCESS_INVOKED} && !$getBeforeProcess);
    # Check for var.subvar syntax
    $key =~ /([^.]*)\.*(.*)/;
    my $var = $1;
    my $subvar = $2;
    # Make sure this is a legitimate switch processor variable
    $self->_varNameCheck($filename, $line, $var, $subvar);
    my $value = $self->{HASH}->{$var};
    $subvar ? $value->[$self->_getSubvarIndex($var, $subvar)] : $value;
}

sub _getSubvarIndex {
    my $self = shift;
    my $var = shift;
    my $subvar = shift;
    my $switch = $self->{SWITCHES}->{$var};
    return(-1) unless $switch;
    return(-1) unless $switch->{SUBVARS};
    for (my $i = 0; $i < @{$switch->{SUBVARS}}; $i++) {
	return($i) if ${$switch->{SUBVARS}}[$i] eq $subvar;
    }
    -1;
}

# Check whether a given switch processor variable is legitimate
sub _varNameCheck {
    my $self = shift;
    my $filename = shift;
    my $line = shift;
    my $key = shift;
    my $subkey = shift;
    # If process() has already been invoked, check the variable name now...
    if ($self->{PROCESS_INVOKED}) {
	$self->_immediateVarNameCheck($filename, $line, $key, $subkey);
    }
    # ...Otherwise, remember the variable name and check it later
    else {
	push(@{$self->{VARSTOCHECK}}, [$filename, $line, $key, $subkey]);
    }
}

# Make sure this variable is legitimate
sub _immediateVarNameCheck {
    my $self = shift;
    my $filename = shift;
    my $line = shift;
    my $key = shift;
    my $subkey = shift;
    Logger->new()->NIST_die("No such SwitchProcessor variable: $key, at $filename line $line\n")
	unless $self->{LEGALVARS}->{$key};
    Logger->new()->NIST_die("No such SwitchProcessor subvariable: $key.$subkey, at $filename line $line\n")
	unless (!$subkey || $self->_getSubvarIndex($key, $subkey) >= 0);
}

# Add default values to switch and parameter documentation strings,
# where appropriate
sub _addDefaultsToDoc {
    my $self = shift;
    # Loop over all switches
    foreach my $switch (values %{$self->{SWITCHES}}) {
	if ($switch->{METAMAP}) {
	    $switch->{DOCUMENTATION} .= " (Equivalent to";
	    foreach my $var (sort CORE::keys %{$switch->{METAMAP}}) {
		my $rawval = $switch->{METAMAP}->{$var};
		my $val = SwitchProcessor::_formatSubs($rawval, $self->{SWITCHES}->{$var});
		$switch->{DOCUMENTATION} .= " -$var $val";
	    }
	    $switch->{DOCUMENTATION} .= ")";
	}
	# Default values aren't reported for constant switches
	if (!defined($switch->{CONSTANT})) {
	    my $default = $self->get($switch->{NAME}, "TRUE");
	    if (defined($default)) {
		$switch->{DOCUMENTATION} .= " (Default = " . _formatSubs($default, $switch) . ").";
	    }
	}
    }
    # Loop over all params
    foreach my $param (@{$self->{PARAMS}}) {
	my $default = $self->get($param->{NAME}, "TRUE");
	# Add default to documentation if the switch is optional and there
	# is a default value
	$param->{DOCUMENTATION} .= " (Default = " . _quotify($default) . ")."
	    if (!$param->{REQUIRED} && defined($default));
    }
}

# Process the command line
sub process {
    my $self = shift;
    # Add defaults to the documentation
    $self->_addDefaultsToDoc();
    # Remember that process() has been invoked
    $self->{PROCESS_INVOKED} = "TRUE";
    # Now that all switches have been defined, check all pending
    # variable names for legitimacy
    foreach (@{$self->{VARSTOCHECK}}) {
	# FIXME: Can't we just use @{$_} here?
	$self->_immediateVarNameCheck(${$_}[0], ${$_}[1], ${$_}[2], ${$_}[3]);
    }
    # Switches must come first.  Keep processing switches as long as
    # the next element begins with a dash
    while (@_ && $_[0] =~ /^-(.*)/) {
	# Get the switch with this name
	my $switch = $self->{SWITCHES}->{$1};
	$self->_barf("Unknown switch: -$1\n")
	    unless $switch;
	# Throw away the switch name
	shift;
	# Invoke the process code associated with this switch
	# FIXME:  How can switch be made implicit?
	@_ = $switch->{PROCESS}->($switch, $self, @_);
    }
    # Now that the switches have been handled, loop over the legal params
    foreach my $param (@{$self->{PARAMS}}) {
	# Bomb if a required arg wasn't provided
	$self->_barf("Not enough arguments; $param->{NAME} must be provided\n")
	    if (!@_ && $param->{REQUIRED});
	# If this is an all others param, grab all the remaining arguments
	if ($param->{ALLOTHERS}) {
	    $self->put($param->{NAME}, [@_]) if @_;
	    @_ = ();
	}
	# Otherwise, if there are arguments left, bind the next one to the parameter
	elsif (@_) {
	    $self->put($param->{NAME}, shift);
	}
    }
    # If any arguments are left over, the user botched it
    $self->_barf("Too many arguments\n")
	if (@_);
}

################################################################################

package SP::_Switch;

sub new {
    my $classname = shift;
    my $filename = shift;
    my $line = shift;
    my $self = {};
    bless($self, $classname);
    Logger->new()->NIST_die("Too few arguments to constructor while creating classname, at $filename line $line\n")
	unless @_ >= 2;
    # Switch name and documentation are always present
    $self->{NAME} = shift;
    $self->{DOCUMENTATION} = pop;
    $self->{USAGE} = "-$self->{NAME}";
    # I know, these are unnecessary
    $self->{PROCESS} = undef;
    $self->{CONSTANT} = undef;
    $self->{SUBVARS} = ();
    # Return two values
    # FIXME: Why won't [$self, \@_] work here?
    ($self, @_);
}

# Create new help switch
sub newHelp {
    my @args = new (@_);
    my $self = shift(@args);
    Logger->new()->NIST_die("Too many arguments to addHelpSwitch, at $_[1] line $_[2]\n")
	if (@args);
    # A help switch just prints out program usage then exits
    $self->{PROCESS} = sub {
	my $self = shift;
	my $sp = shift;
	$sp->showUsage();
	exit(0);
    };
    $self;
}

# Create a new constant switch
sub newConstant {
    my @args = new(@_);
    my $self = shift(@args);
    Logger->new()->NIST_die("Too few arguments to addConstantSwitch, at $_[1] line $_[2]\n")
	unless @args >= 1;
    Logger->new()->NIST_die("Too many arguments to addConstantSwitch, at $_[1] line $_[2]\n")
	unless @args <= 2;
    # Retrieve the constant value
    $self->{CONSTANT} = pop(@args);
    if (@args) {
	$self->{SUBVARS} = shift(@args);
	# Make sure, if there are subvars, that the number of subvars
	# matches the number of constant arguments
	Logger->new()->NIST_die("Number of values [" . join(", ", @{$self->{CONSTANT}}) .
	    "] does not match number of variables [" . join(", ", @{$self->{SUBVARS}}) .
		"], at $_[1] line $_[2]\n")
		    unless $#{$self->{CONSTANT}} == $#{$self->{SUBVARS}};
    }
    $self->{PROCESS} = sub {
	my $self = shift;
	my $sp = shift;
	my $counter = 0;
	$sp->put($self->{NAME}, $self->{CONSTANT});
	@_;
    };
    $self;
}

# Create a new var switch
sub newVar {
    my @args = new(@_);
    my $self = shift(@args);
    Logger->new()->NIST_die("Too many arguments to addVarSwitch, at $_[1] line $_[2]\n")
	unless @args <= 1;
    # If there are subvars
    if (@args) {
	my $arg = shift(@args);
	if (ref $arg) {
	    $self->{SUBVARS} = $arg;
	    # Augment the usage string with the name of the subvar
	    foreach my $subvar (@{$self->{SUBVARS}}) {
		$self->{USAGE} .= " <$subvar>";
	    }
	    # A var switch with subvars binds each subvar
	    $self->{PROCESS} = sub {
		my $self = shift;
		my $sp = shift;
		my $counter = 0;
		my $value = [];
		# Make sure there are enough arguments for this switch
		foreach (@{$self->{SUBVARS}}) {
		    $sp->_barf("Not enough arguments to switch -$self->{NAME}\n")
			unless @_;
		    push(@{$value}, shift);
		}
		$sp->put($self->{NAME}, $value);
		@_;
	    };
	}
	else {
	    $self->{USAGE} .= " <$arg>";
	    $self->{PROCESS} = sub {
		my $self = shift;
		my $sp = shift;
		$sp->put($self->{NAME}, shift);
		@_;
	    };
	}
    }
    else {
	# A var switch without subvars gets one argument, called 'value'
	# in the usage string
	$self->{USAGE} .= " <value>";
	# Bind the argument to the parameter
	$self->{PROCESS} = sub {
	    my $self = shift;
	    my $sp = shift;
	    $sp->put($self->{NAME}, shift);
	    @_;
	};
    }
    $self;
}

# Create a new immediate switch
sub newImmediate {
    my @args = new(@_);
    my $self = shift(@args);
    Logger->new()->NIST_die("Wrong number of arguments to addImmediateSwitch or addMetaSwitch, at $_[1] line $_[2]\n")
	unless @args == 1;
    $self->{PROCESS} = shift(@args);
    $self;
}

# Create a new meta switch
sub newMeta {
    # The call looks just like a call to newImmediate, except that
    # instead of a fn as the second argument, there's a hashref.  So
    # use newImmediate to do the basic work, then strip out the
    # hashref and replace it with the required function.
    my $self = newImmediate(@_);
    $self->{METAMAP} = $self->{PROCESS};
    $self->{PROCESS} = sub {
	my $var;
	my $val;
	my $self = shift;
	my $sp = shift;
	# FIXME: Doesn't properly handle case where var is itself a metaswitch
	while (($var, $val) = each %{$self->{METAMAP}}) {
	    $sp->put($var, $val);
	}
	@_;
    };
    $self;
}

################################################################################

package SP::_Param;

# A parameter is just a struct for the four args
sub new {
    my $classname = shift;
    my $filename = shift;
    my $line = shift;
    my $self = {};
    bless($self, $classname);
    $self->{NAME} = shift;
    # param name and documentation are first and last, respectively.
    $self->{DOCUMENTATION} = pop;
    $self->{USAGE} = $self->{NAME};
    # If omitted, REQUIRED and ALLOTHERS default to undef
    $self->{REQUIRED} = shift;
    $self->{ALLOTHERS} = shift;
    # Tack on required to the documentation stream if this arg is required
    $self->{DOCUMENTATION} .= " (Required)."
	if ($self->{REQUIRED});
    $self;
}

################################################################################

package main;

##################################################################################### 
# Predicates
##################################################################################### 


##################################################################################### 
# Knowledge base
##################################################################################### 

# This is not really a KB per se, because we have to be resilient to errors in the input
package KB;

# A KB contains the following fields:
#  ASSERTIONS0	- All assertions
#  ASSERTIONS1	- Assertions indexed by subject
#  ASSERTIONS2	- Assertions indexed by subject and verb
#  ASSERTIONS3	- Assertions indexed by subject, verb and object
#  DOCIDS	- Assertions indexed by subject, verb and docid
#  ENTITIES	- Maps from entity name to entity structure
#  LOGGER	- Logger object for reporting errors and traces
#  MENTIONS	- Mention assertions indexed by docid
#  PREDICATES	- PredicateSet object
#  RUNID	- Run ID of the KB file this KB was built from
#  RUNID_LINE	- Entire line from which RUNID was extracted, including comments

# Create a new empty KB
sub new {
  my ($class, $logger, $predicates) = @_;
  my $self = {LOGGER => $logger, PREDICATES => $predicates};
  bless($self, $class);
  $self;
}

# Find or create the KB entity with a given name
sub intern {
  my ($kb, $name, $source) = @_;
  return $name if ref $name;
  if ($name =~ /^"/) {
    $kb->{LOGGER}->record_problem('STRING_USED_FOR_ENTITY', $name, $source);
    return;
  }
  unless ($name =~ /^:?\w+$/) {
    $kb->{LOGGER}->record_problem('ILLEGAL_ENTITY_NAME', $name, $source);
    return;
  }
  unless ($name =~ /^:/) {
    $kb->{LOGGER}->record_problem('COLON_OMITTED', $name, $source);
    $name = ":$name";
  }
  my $entity = $kb->{ENTITIES}{$name};
  unless (defined $entity) {
    $entity = {NAME => $name};
    $kb->{ENTITIES}{$name} = $entity;
  }
  $entity;
}

# Record that an entity has been used in a particular way (e.g., it's
# been given a type, it appears as the subject of a predicate, etc.)
sub entity_use {
  my ($kb, $name, $use_type, $source) = @_;
  $kb->{LOGGER}->NIST_die("Unknown use type: $use_type") unless $use_priority{$use_type};
  my $entity = $kb->intern($name, $source);
  # Do nothing if the name is malformed
  return unless defined $entity;
  $use_type = uc $use_type;
  push(@{$entity->{USES}{$use_type}}, $source);
  # When an error message refers to a particular entity, we'd like to
  # give as clear a pointer to the entity as we can. This code keeps
  # track of the "best" use of an entity for reporting purposes, with
  # %use_priority providing the definition of "best."
  my $thisuse = {USE_TYPE => $use_type, SOURCE => $source};
  my $bestuse = $entity->{BESTUSE} || $thisuse;
  $bestuse = $thisuse if $bestuse->{USE_TYPE} eq $thisuse->{USE_TYPE} &&
                         $bestuse->{SOURCE}{LINENUM} > $thisuse->{SOURCE}{LINENUM};
  $bestuse = $thisuse if $use_priority{$bestuse->{USE_TYPE}} > $use_priority{$thisuse->{USE_TYPE}};
  $entity->{BESTUSE} = $bestuse;
  $entity;
}

# Assert that an entity has the given type
sub entity_typedef {
  my ($kb, $name, $type, $def_type, $source) = @_;
  $kb->{LOGGER}->NIST_die("Unknown def type: $def_type") unless $use_priority{$def_type};
  # A type specification with multiple types doesn't give us any information, so ignore it
  if (ref $type) {
    my @types = keys %{$type};
    return if (@types > 1);
    $kb->{LOGGER}->NIST_die("type set with no entries in entity_typedef") unless @types;
    $type = $types[0];
  }
  $type = lc $type;
  # Only legal types may be asserted
  unless ($PredicateSet::legal_domain_types{$type}) {
    $kb->{LOGGER}->record_problem('ILLEGAL_ENTITY_TYPE', $type, $source);
    return;
  }
  my $entity = $kb->intern($name, $source);
  # Do nothing if the name is malformed
  return unless defined $entity;
  $def_type = uc $def_type;
  push(@{$entity->{TYPEDEFS}{$type}{$def_type}}, $source);
  my $thisdef = {DEFTYPE => $def_type, SOURCE => $source};
  my $bestdef = $entity->{BESTDEF}{$type} || $thisdef;
  # The best definition to point the user at is the one with the
  # highest use_priority, or, if they're the same, the one that occurs
  # first in the file
  $bestdef = $thisdef if $bestdef->{DEFTYPE} eq $thisdef->{DEFTYPE} &&
                         $bestdef->{SOURCE}{LINENUM} > $thisdef->{SOURCE}{LINENUM};
  $bestdef = $thisdef if $use_priority{$bestdef->{DEFTYPE}} > $use_priority{$thisdef->{DEFTYPE}};
  $entity->{BESTDEF}{$type} = $bestdef;
  $entity;
}

# Find the type of a given entity, if known
sub get_entity_type {
  my ($kb, $entity, $source) = @_;
  $entity = $kb->intern($entity, $source);
  # We'll only get nil if the entity name is malformed, but return
  # unknown nonetheless
  return 'unknown' unless defined $entity;
  my @types = keys %{$entity->{TYPEDEFS}};
  return $types[0] if @types == 1;
  return 'unknown' unless @types;
  return 'multiple';
}

# Assert a particular triple into the KB
sub add_assertion {
  my ($kb, $subject, $verb, $object, $provenance, $confidence, $source, $comment) = @_;
  $comment = "" unless defined $comment;
  # First, normalize all of the triple components
  my $subject_entity = $kb->intern($subject, $source);
  return unless defined $subject_entity;
  $subject = $subject_entity->{NAME};
  my $subject_type = $kb->get_entity_type($subject_entity);
  $subject_type = undef unless $PredicateSet::legal_domain_types{$subject_type};
  my $object_entity;
  my $predicate = $kb->{PREDICATES}->get_predicate($verb, $subject_type, $source);
  return unless ref $predicate;
  $verb = $predicate->get_name();
  # Record entity uses and type definitions. 'type' assertions are special-cased (as they have no object)
  if ($verb eq 'type') {
    $kb->entity_use($subject_entity, 'TYPEDEF', $source);
    $kb->entity_typedef($subject_entity, $object, 'TYPEDEF', $source);
  }
  elsif ($verb eq 'link') {
    # FIXME
  }
  else {
    $kb->entity_use($subject_entity, 'SUBJECT', $source);
    $kb->entity_typedef($subject_entity, $predicate->get_domain(), 'SUBJECT', $source);
    if (&PredicateSet::is_compatible('string', $predicate->get_range())) {
      # Make sure this is a properly double quoted string
      unless ($object =~ /^"(?>(?:(?>[^"\\]+)|\\.)*)"$/) {
	# If not, complain and stick double quotes around it
	# FIXME: Need to quote internal quotes; use String::Escape
	$kb->{LOGGER}->record_problem('UNQUOTED_STRING', $object, $source);
	$object =~ s/(["\\])/\\$1/g;
	$object = "\"$object\"";
      }
    }
    if (&PredicateSet::is_compatible($predicate->get_range(), \%PredicateSet::legal_entity_types)) {
      $object_entity = $kb->intern($object, $source);
      return unless defined $object_entity;
      $object = $object_entity->{NAME};
      $kb->entity_use($object_entity, 'OBJECT', $source);
      $kb->entity_typedef($object_entity, $predicate->get_range(), 'OBJECT', $source);
    }
  }
  # Check for duplicate assertions
  my $is_duplicate_of;
  unless ($verb eq 'mention' || $verb eq 'canonical_mention' || $verb eq 'type' || $verb eq 'link') {
  existing:
    # We don't consider inferred assertions to be duplicates
    foreach my $existing (grep {!$_->{INFERRED}} $kb->get_assertions($subject, $verb, $object)) {
      # Don't worry about duplicates of assertions that have already been omitted from the output
      next if $existing->{OMIT_FROM_OUTPUT};
      # If only one is allowed, any matching assertion is a duplicate
      if ($multiple_attestations eq 'ONE') {
	$is_duplicate_of = $existing;
	last existing;
      }
      # In all other cases, it's not a duplicate unless it was extracted from the same document
      next existing unless $existing->{PROVENANCE}->get_docid() eq $provenance->get_docid();
      if ($multiple_attestations eq 'ONEPERDOC') {
	$is_duplicate_of = $existing;
	last existing;
      }
      # If "many" duplicate assertions are allowed, we only have a
      # problem if it is being asserted about exactly the same mention
      next if $existing->{PROVENANCE}->tostring() ne $provenance->tostring();
      # This if is entirely unnecessary, but it makes everything look nice and symmetric
      if ($multiple_attestations eq 'MANY') {
	# This is an actual duplicate of exactly the same information
	$is_duplicate_of = $existing;
	last existing;
      }
    }
  }

  # Handle single-valued slots that are given more than one filler
  my $is_multiple_of;
  if ($predicate->{QUANTITY} eq 'single') {
    foreach my $existing ($kb->get_assertions($subject, $verb)) {
      # Again, ignore assertions that have already been omitted from the output
      next if $existing->{OMIT_FROM_OUTPUT};
      if (defined $object_entity && defined $existing->{OBJECT_ENTITY}) {
	if ($object_entity != $existing->{OBJECT_ENTITY}) {
	  $is_multiple_of = $existing;
	  last;
	}
      }
      elsif ($object ne $existing->{OBJECT}) {
	$is_multiple_of = $existing;
	last;
      }
    }
  }
  # Create the assertion, but don't record it yet. We do this before
  # handling $is_duplicate_of because we may want to use the new
  # assertion rather than the duplicate
  my $assertion = {SUBJECT => $subject,
		   VERB => $verb,
		   OBJECT => $object,
		   PRINT_STRING => "$verb($subject, $object)",
		   SUBJECT_ENTITY => $subject_entity,
		   PREDICATE => $predicate,
		   OBJECT_ENTITY => $object_entity,
		   PROVENANCE => $provenance,
		   CONFIDENCE => $confidence,
		   SOURCE => $source,
		   COMMENT => $comment};
  # Only output one of a set of multiples
  if ($is_multiple_of) {
    $kb->{LOGGER}->record_problem('MULTIPLE_FILLS_ENTITY', $subject, $verb, $source);
    if ($confidence < $is_multiple_of->{CONFIDENCE}) {
      $assertion->{OMIT_FROM_OUTPUT} = 'true';
    }
    elsif ($confidence > $is_multiple_of->{CONFIDENCE}) {
      $is_multiple_of->{OMIT_FROM_OUTPUT} = 'true';
    }
    elsif ($assertion->{SOURCE}{LINENUM} < $is_multiple_of->{SOURCE}{LINENUM}) {
      $is_multiple_of->{OMIT_FROM_OUTPUT} = 'true';
    }
    else {
      $assertion->{OMIT_FROM_OUTPUT} = 'true';
    }
  }
  # Now we can decide how to handle the duplicate
  if ($is_duplicate_of) {
    # Make sure this isn't exactly the same assertion
    return if $provenance->tostring() eq $is_duplicate_of->{PROVENANCE}->tostring();
    $kb->{LOGGER}->record_problem('DUPLICATE_ASSERTION', "$is_duplicate_of->{SOURCE}{FILENAME} line $is_duplicate_of->{SOURCE}{LINENUM}", $source);
    # Keep the duplicate with higher confidence. If the confidences are the same, keep the earlier one
    if ($confidence < $is_duplicate_of->{CONFIDENCE}) {
      $assertion->{OMIT_FROM_OUTPUT} = 'true';
    }
    elsif ($confidence > $is_duplicate_of->{CONFIDENCE}) {
      $is_duplicate_of->{OMIT_FROM_OUTPUT} = 'true';
    }
    elsif ($assertion->{SOURCE}{LINENUM} < $is_duplicate_of->{SOURCE}{LINENUM}) {
      $is_duplicate_of->{OMIT_FROM_OUTPUT} = 'true';
    }
    else {
      $assertion->{OMIT_FROM_OUTPUT} = 'true';
    }
  }
  # Record the assertion in various places for easy retrieval
  push(@{$kb->{MENTIONS}{$provenance->get_docid()}}, $assertion)
    if defined $predicate && ($predicate->{NAME} eq 'mention');
  push(@{$kb->{DOCIDS}{$subject}{$verb}{$provenance->get_docid()}}, $assertion)
    if defined $predicate && ($predicate->{NAME} eq 'mention' || $predicate->{NAME} eq 'canonical_mention');
  push(@{$kb->{ASSERTIONS3}{$subject}{$verb}{$object}}, $assertion);
  push(@{$kb->{ASSERTIONS2}{$subject}{$verb}}, $assertion);
  push(@{$kb->{ASSERTIONS1}{$subject}}, $assertion);
  push(@{$kb->{ASSERTIONS0}}, $assertion);
  $assertion;
}

# Select a global canonical mention for this entity
sub get_best_mention {
  my ($kb, $entity, $docid) = @_;
  my $best = "";
  if (defined $docid) {
    my @mentions = $kb->get_assertions($entity, 'canonical_mention', undef, $docid);
    if (@mentions == 1) {
      $best = $mentions[0]{OBJECT};
    }
    else {
      print $error_output "Oh dear, Wrong number of canonical mentions in document $docid\n";
    }
  } else {
    my @mentions = $kb->get_assertions($entity, 'canonical_mention');
    foreach my $mention (@mentions) {
      $best = $mention->{OBJECT} if length($mention->{OBJECT}) > length($best);
    }
  }
  $best;
}

# More handy accessors
sub get_subjects { my ($kb) = @_;                  keys %{$kb->{ASSERTIONS1}} }
sub get_verbs    { my ($kb, $subject) = @_;        keys %{$kb->{ASSERTIONS2}{$subject}} }
sub get_objects  { my ($kb, $subject, $verb) = @_; keys %{$kb->{ASSERTIONS3}{$subject}{$verb}} }
sub get_docids   { my ($kb, $subject, $verb) = @_; keys %{$kb->{DOCIDS}{$subject}{$verb}} }

# Find all assertions that match a given pattern
sub get_assertions {
  my ($kb, $subject, $verb, $object, $docid) = @_;
  $kb->{LOGGER}->NIST_die("get_assertions given both object and docid")
    if defined $object && defined $docid;

  $subject = $subject->{NAME} if ref $subject;
  $verb = $verb->{VERB} if ref $verb;
  $object = $object->{NAME} if ref $object;

  return(@{$kb->{ASSERTIONS3}{$subject}{$verb}{$object} || []}) if defined $object;
  return(@{$kb->{DOCIDS}{$subject}{$verb}{$docid} || []}) if defined $docid;
  return(@{$kb->{ASSERTIONS2}{$subject}{$verb} || []}) if defined $verb;
  return(@{$kb->{ASSERTIONS1}{$subject} || []}) if defined $subject;
  return(@{$kb->{ASSERTIONS0} || []});
}


##################################################################################### 
# Error checking and inferred relations
##################################################################################### 

# Report entities that don't have exactly one type
sub check_entity_types {
  my ($kb) = @_;
  while (my ($name, $entity) = each %{$kb->{ENTITIES}}) {
    my $type = $kb->get_entity_type($entity);
    if ($type eq 'unknown') {
      $kb->{LOGGER}->record_problem('UNKNOWN_TYPE', $name, $entity->{BESTUSE}{SOURCE});
    }
    elsif ($type eq 'multiple') {
      $kb->{LOGGER}->record_problem('MULTITYPED_ENTITY', $name,
			    join(", ", map {"$_ at line $entity->{BESTDEF}{$_}{SOURCE}{LINENUM}"}
				 sort keys %{$entity->{BESTDEF}}), 'NO_SOURCE');
    }
  }
}

# Make sure that every entity that has been mentioned or used somewhere has a typedef
sub check_definitions {
  my ($kb) = @_;
  while (my ($name, $entity) = each %{$kb->{ENTITIES}}) {
    # I suspect that having multiple types here (PER, ORG, GPE) is at this point vestigial
    foreach my $type (keys %{$entity->{BESTDEF}}) {
      # An entity that is used in any way must have an actual typedef somewhere
      $kb->{LOGGER}->record_problem('MISSING_TYPEDEF', $name, $entity->{BESTDEF}{$type}{SOURCE})
	unless $entity->{TYPEDEFS}{$type}{TYPEDEF};
    }
  }
}

# Make sure that every assertion also has an asserted inverse
sub assert_inverses {
  my ($kb) = @_;
  foreach my $assertion ($kb->get_assertions()) {
    next unless ref $assertion->{PREDICATE};
    next unless &PredicateSet::is_compatible($assertion->{PREDICATE}{RANGE}, \%PredicateSet::legal_entity_types);
    unless ($kb->get_assertions($assertion->{OBJECT}, $assertion->{PREDICATE}{INVERSE_NAME}, $assertion->{SUBJECT})) {
      $kb->{LOGGER}->record_problem('MISSING_INVERSE', $assertion->{PREDICATE}->get_name(),
			    $assertion->{SUBJECT}, $assertion->{OBJECT}, $assertion->{SOURCE});
      # Assert the inverse if it's not already there
      my $inverse = $kb->add_assertion($assertion->{OBJECT}, $assertion->{PREDICATE}{INVERSE_NAME}, $assertion->{SUBJECT},
				       $assertion->{PROVENANCE}, $assertion->{CONFIDENCE}, $assertion->{SOURCE});
      # And flag this as an inferred relation
      $inverse->{INFERRED} = 'true';
      # Make sure the visibility of the assertion and its inverse is in sync
      $assertion->{OMIT_FROM_OUTPUT} = 'true' if $inverse->{OMIT_FROM_OUTPUT};
      $inverse->{OMIT_FROM_OUTPUT} = 'true' if $assertion->{OMIT_FROM_OUTPUT};
    }
  }
}

# Make sure that mentions and canonical_mentions are in sync
sub assert_mentions {
  my ($kb) = @_;
  foreach my $subject ($kb->get_subjects()) {
    my %docids;
    foreach my $docid ($kb->get_docids($subject, 'mention'),
		       $kb->get_docids($subject, 'canonical_mention')) {
      $docids{$docid}++;
    }
    unless (keys %docids) {
      $kb->{LOGGER}->record_problem('NO_MENTIONS', $subject, 'NO_SOURCE');
      next;
    }
    foreach my $docid (keys %docids) {
      my %mentions = map {$_->{PROVENANCE}->tostring() => $_} $kb->get_assertions($subject, 'mention', undef, $docid);
      my %canonical_mentions = map {$_->{PROVENANCE}->tostring() => $_} $kb->get_assertions($subject, 'canonical_mention', undef, $docid);
      if (!keys %canonical_mentions && keys %mentions) {
	$kb->{LOGGER}->record_problem('MISSING_CANONICAL', $subject, $docid, 'NO_SOURCE');
	# Pick a mention at random to serve as the canonical
	# mention. This makes the validator non-deterministic, but
	# it's hard to see how that will be a problem (& ya shoulda
	# selected a canonical mention)
	my ($mention) = values %mentions;
	my $assertion = $kb->add_assertion($mention->{SUBJECT}, 'canonical_mention', $mention->{OBJECT},
					   $mention->{PROVENANCE}, $mention->{CONFIDENCE}, $mention->{SOURCE});
	$assertion->{INFERRED} = 'true';
      }
      elsif (keys %canonical_mentions > 1) {
	$kb->{LOGGER}->record_problem('MULTIPLE_CANONICAL', $subject, $docid, 'NO_SOURCE');
      }
      while (my ($string, $canonical_mention) = each %canonical_mentions) {
	# Find the mention that matches this canonical mention, if any
	my $mention = $mentions{$string};
	unless ($mention) {
	  # Canonical mention without a corresponding mention
	  $kb->{LOGGER}->record_problem('UNASSERTED_MENTION', $canonical_mention->{PRINT_STRING}, $docid, $canonical_mention->{SOURCE});
	  my $assertion = $kb->add_assertion($canonical_mention->{SUBJECT}, 'mention', $canonical_mention->{OBJECT},
					     $canonical_mention->{PROVENANCE},
					     $canonical_mention->{CONFIDENCE},
					     $canonical_mention->{SOURCE});
	  $assertion->{INFERRED} = 'true';
	}
      }
    }
  }
}

# Make sure that all confidence values are legal
sub check_confidence {
  my ($kb) = @_;
  foreach my $assertion ($kb->get_assertions()) {
    if (defined $assertion->{CONFIDENCE}) {
      unless ($assertion->{CONFIDENCE} =~ /^(?:1\.0*)$|^(?:0?\.[0-9]+)$/) {
	$kb->{LOGGER}->record_problem('ILLEGAL_CONFIDENCE_VALUE', $assertion->{CONFIDENCE}, $assertion->{SOURCE});
	$assertion->{CONFIDENCE} = '1.0';
      }
    }
  }
}

my @do_not_check_endpoints = qw(
  type
  mention
  canonical_mention
  link
);

my %do_not_check_endpoints = map {$_ => $_} @do_not_check_endpoints;

# Each endpoint of a relation that is an entity must be attested in
# a document that attests to the relation
sub check_relation_endpoints {
  my ($kb) = @_;
  foreach my $assertion ($kb->get_assertions()) {
    next unless ref $assertion->{PREDICATE};
    next if $do_not_check_endpoints{$assertion->{PREDICATE}{NAME}};
    my $provenance = $assertion->{PROVENANCE};
    my $num_provenance_entries = $provenance->get_num_entries();
    if (defined $assertion->{SUBJECT_ENTITY}) {
      my @subject_mentions;
      for (my $i = 0; $i < $num_provenance_entries; $i++) {
	my $docid = $assertion->{PROVENANCE}->get_docid($i);
	unless(@subject_mentions) {
	  @subject_mentions = $kb->get_assertions($assertion->{SUBJECT_ENTITY}, 'mention', undef, $docid);
	}
      }
      $kb->{LOGGER}->record_problem('UNATTESTED_RELATION_ENTITY',
				    $assertion->{PRINT_STRING},
				    $assertion->{SUBJECT_ENTITY}{NAME},
				    $provenance->tostring(),
				    $assertion->{SOURCE})
	unless @subject_mentions;
    }
    if (defined $assertion->{OBJECT_ENTITY}) {
      my @object_mentions;
      for (my $i = 0; $i < $num_provenance_entries; $i++) {
	my $docid = $assertion->{PROVENANCE}->get_docid($i);
	unless(@object_mentions) {
	  @object_mentions = $kb->get_assertions($assertion->{OBJECT_ENTITY}, 'mention', undef, $docid);
	}
      }
      $kb->{LOGGER}->record_problem('UNATTESTED_RELATION_ENTITY',
				    $assertion->{PRINT_STRING},
				    $assertion->{OBJECT_ENTITY}{NAME},
				    $provenance->tostring(),
				    $assertion->{SOURCE})
	unless @object_mentions;
    }
  }
}

# Perform a number of basic checks to make sure that the KB is well-formed
sub check_integrity {
  my ($kb) = @_;
  $kb->check_entity_types();
  $kb->check_definitions();
  $kb->assert_inverses();
  $kb->assert_mentions();
  $kb->check_relation_endpoints();
  $kb->check_confidence();
}

# Print out all assertions
sub dump_assertions {
  my ($kb) = @_;
  my $outfile = $program_output || *STDERR{IO};
  foreach my $assertion ($kb->get_assertions()) {
    if (defined $assertion->{PREDICATE}) {
      print $outfile "p:$assertion->{PREDICATE}{NAME}";
    }
    else {
      print $outfile "v:$assertion->{VERB}";
    }
    print $outfile "($assertion->{SUBJECT}, $assertion->{OBJECT})";
    if (ref $assertion->{PROVENANCE}) {
      print $outfile " $assertion->{PROVENANCE}->tostring()";
    }
    print $outfile "\n";
  }
}


##################################################################################### 
# Loading and saving
##################################################################################### 

package main;

sub trim {
  my ($string) = @_;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  $string;
}

# Load a KB that is expressed in TAC format (tab-separated triples with provenance)
sub load_tac {
  my ($logger, $predicates, $filename, $docids) = @_;
  my $kb = KB->new($logger, $predicates);
  open(my $infile, "<:utf8", $filename) or $logger->NIST_die("Could not open $filename: $!");
  my $runid = <$infile>;
  chomp $runid;
  $kb->{RUNID_LINE} = $runid;
  $runid =~ s/\s*#.*//;
  $runid =~ s/^\s+//;
  $runid =~ s/\s+$//;
  if (length($runid) == 0 || $runid =~ /^:/ || $runid =~ /\s/) {
    $kb->{LOGGER}->record_problem('MISSING_RUNID', {FILENAME => $filename, LINENUM => $.});
    # The most likely explanation if the line is not blank is that the
    # runid was omitted entirely, so go back to the beginning and
    # process as if there is no runid there
    seek($infile, 0, 0) or $logger->NIST_die("Could not seek to the start of $filename: $!");
    my $date = `date`;
    $runid = 'OmittedRunID';
    $kb->{RUNID_LINE} = "OmittedRunID\t# $date  Did not find a legal run ID at the start of $filename";
  }
  $kb->{RUNID} = $runid;
  while (<$infile>) {
    chomp;
    my $source = {FILENAME => $filename, LINENUM => $.};
    my $confidence = '1.0';
    # Eliminate comments, ensuring that pound signs in the middle of
    # strings are not treated as comment characters
    s/$main::comment_pattern/$1/;
    my $comment = $2 || "";
    next unless /\S/;
    my @entries = map {&trim($_)} split(/\t/);
    # Get the confidence out of the way if it is provided
    $confidence = pop(@entries) if @entries && $entries[-1] =~ /^\d+\.\d+$/;
    # Now assign the entries to the appropriate fields
    my ($subject, $predicate, $object, $provenance_string) = @entries;
    my $provenance;
    if (lc $predicate eq 'type' || lc $predicate eq 'link') {
      unless (@entries == 3) {
	$kb->{LOGGER}->record_problem('WRONG_NUM_ENTRIES', 3, scalar @entries, $source);
	next;
      }
      $provenance = Provenance->new($logger, $source, 'EMPTY');
    }
    else {
      unless (@entries == 4) {
	$kb->{LOGGER}->record_problem('WRONG_NUM_ENTRIES', 4, scalar @entries, $source);
	next;
      }
      $provenance = Provenance->new($logger, $source, 'PROVENANCETRIPLELIST', $provenance_string)
    }
    $kb->add_assertion($subject, $predicate, $object, $provenance, $confidence, $source, $comment);
  }
  close $infile;
  $kb->check_integrity();
#&main::dump_structure($kb, 'KB', [qw(LOGGER CONFIDENCE LABEL QUANTITY BESTDEF BESTUSE TYPEDEFS USES COMMENT INVERSE_NAME SOURCE WHERE DOMAIN RANGE)]);
#exit 0;
  $kb;
}

# When outputting TAC format, place assertions in a particular order
sub get_assertion_priority {
  my ($name) = @_;
  return 3 if $name eq 'type';
  return 2 if $name eq 'link';
  return 1 if $name eq 'mention' || $name eq 'canonical_mention';
  return 0;
}

sub assertion_comparator {
  return $a->{SUBJECT} cmp $b->{SUBJECT} unless $a->{SUBJECT} eq $b->{SUBJECT};
  my $aname = lc $a->{PREDICATE}{NAME};
  my $bname = lc $b->{PREDICATE}{NAME};
  my $apriority = &get_assertion_priority($aname);
  my $bpriority = &get_assertion_priority($bname);
  return $bpriority <=> $apriority ||
	 $aname cmp $bname ||
         $a->{PROVENANCE}->get_docid() cmp $b->{PROVENANCE}->get_docid() ||
	 $a->{PROVENANCE}->get_start() <=> $b->{PROVENANCE}->get_start();
}  

# TAC format is just a list of assertions. Output the assertions in
# the order defined by the above comparator (just to make the output
# pretty; there is no fundamental need to do so)
sub export_tac {
  my ($kb, $output_labels) = @_;
  print $program_output "$kb->{RUNID_LINE}\n\n";
  foreach my $assertion (sort assertion_comparator $kb->get_assertions()) {
    next if $assertion->{OMIT_FROM_OUTPUT};
    next unless $output_labels->{$assertion->{PREDICATE}{LABEL}};
    # Only output assertions that have fully resolved predicates
    next unless ref $assertion->{PREDICATE};
    my $predicate_string = $assertion->{PREDICATE}{NAME};
    my $domain_string = "";
    if ($predicate_string ne 'type' &&
	$predicate_string ne 'mention' &&
	$predicate_string ne 'canonical_mention' &&
	$predicate_string ne 'link') {
      $domain_string = $kb->get_entity_type($assertion->{SUBJECT_ENTITY});
      next if $domain_string eq 'unknown';
      next if $domain_string eq 'multiple';
      $domain_string .= ":";
    }
    print $program_output "$assertion->{SUBJECT}\t$domain_string$assertion->{PREDICATE}{NAME}\t$assertion->{OBJECT}";
    print $program_output "\t", $assertion->{PROVENANCE}->tooriginalstring();
    print $program_output "\t$assertion->{CONFIDENCE}" if $predicate_string ne 'type';
    print $program_output $assertion->{COMMENT};
    print $program_output "\n";
  }
}

# EDL format is a tab-separated file with the following columns:
#  1. System run ID
#  2. Mention ID
#  3. Mention head string
#  4. Provenance
#  5. KBID or NIL
#  6. Entity type (GPE, ORG, PER, LOC, FAC)
#  7. Mention type (NAM, NOM)
#  8. Confidence value

sub export_edl {
  my ($kb) = @_;
  # Collect type information
  my %entity2type;
  my %entity2link;
  my $next_nilnum = "0001";
  foreach my $assertion (sort assertion_comparator $kb->get_assertions()) {
    next if $assertion->{OMIT_FROM_OUTPUT};
    # Only output assertions that have fully resolved predicates
    next unless ref $assertion->{PREDICATE};
    my $predicate_string = $assertion->{PREDICATE}{NAME};
    if ($predicate_string eq 'type') {
      $entity2type{$assertion->{SUBJECT}} = $assertion->{OBJECT};
      $entity2link{$assertion->{SUBJECT}} = $next_nilnum++ unless $entity2link{$assertion->{SUBJECT}};
    }
    elsif ($predicate_string eq 'link') {
      # FIXME: Ensure only one link relation
      $entity2link{$assertion->{SUBJECT}} = $assertion->{OBJECT};
    }
  }
  my $next_mentionid = "M00001";
  foreach my $assertion (sort assertion_comparator $kb->get_assertions()) {
    next if $assertion->{OMIT_FROM_OUTPUT};
    # Only output assertions that have fully resolved predicates
    next unless ref $assertion->{PREDICATE};
    my $predicate_string = $assertion->{PREDICATE}{NAME};
    my $domain_string = "";
    next unless $predicate_string eq 'mention';
    my $runid = $kb->{RUNID};
    my $mention_id = $next_mentionid++;
    my $mention_string = $assertion->{OBJECT};
    my $provenance = $assertion->{PROVENANCE}->tooriginalstring();
    my $kbid = "NIL_$entity2link{$assertion->{SUBJECT}}";
    my $entity_type = $entity2type{$assertion->{SUBJECT}};
    my $mention_type = "NAM";
    my $confidence = $assertion->{CONFIDENCE};
    print $program_output join("\t", $runid, $mention_id, $mention_string,
			             $provenance, $kbid, $entity_type,
			             $mention_type, $confidence), "\n";
  }
}

##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Validate a TAC Cold Start KB file, checking for common errors.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('output_file', "Specify a file to which output should be redirected");
$switches->put('output_file', 'STDOUT');
$switches->addVarSwitch("output", "Specify the output format. Legal formats are $output_formats." .
		                  " Use 'none' to perform error checking with no output.");
$switches->put("output", 'none');
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addVarSwitch("predicates", "File containing specification of additional predicates to allow");
$switches->addVarSwitch("labels", "Colon-separated list of triple labels for output");
$switches->put("labels", "TAC");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addVarSwitch('multiple', "Are multiple assertions of the same triple allowed? " .
			"Legal values are: " . join(", ", map {"$_ ($multiple_attestations{$_})"} sort keys %multiple_attestations));
$switches->put('multiple', $multiple_attestations);
$switches->addVarSwitch('docs', "Tab-separated file containing docids and document lengths, measured in unnormalized Unicode characters");
$switches->addVarSwitch('ignore', "Colon-separated list of warnings to ignore. Legal values are: " .
			Logger->new()->get_warning_names());
$switches->addParam("filename", "required", "File containing input KB specification.");

$switches->process(@ARGV);

# This holds the "knowledge base"
my $kb;

# Allow redirection of stdout and stderr
my $output_filename = $switches->get("output_file");
if (lc $output_filename eq 'stdout') {
  $program_output = *STDOUT{IO};
}
elsif (lc $output_filename eq 'stderr') {
  $program_output = *STDERR{IO};
}
elsif (lc $output_filename ne 'none') {
  open($program_output, ">:utf8", $output_filename) or Logger->new()->NIST_die("Could not open $output_filename: $!");
}

my $error_filename = $switches->get("error_file");
if (lc $error_filename eq 'stdout') {
  $error_output = *STDOUT{IO};
}
elsif (lc $error_filename eq 'stderr') {
  $error_output = *STDERR{IO};
}
else {
  open($error_output, ">:utf8", $error_filename) or Logger->new()->NIST_die("Could not open $error_filename: $!");
}

my $logger = Logger->new(undef, $error_output);

my $output_mode = lc $switches->get('output');
$logger->NIST_die("Unknown output mode: $output_mode") unless $type2export{$output_mode} || $output_mode eq 'none';
my $output_fn = $type2export{$output_mode};

my $predicates = PredicateSet->new($logger);

# The input file to process
my $filename = $switches->get("filename");
$logger->NIST_die("File $filename does not exist") unless -e $filename;

# What triple labels should be output?
my $labels = $switches->get("labels");
# Courtesy check that basic TAC relations are being output
my $tac_found;
foreach my $label (split(/:/, uc $labels)) {
  $output_labels{$label} = 'true';
  $tac_found++ if $label eq 'TAC';
}
print $error_output "WARNING: 'TAC' not included in output labels\n" unless $tac_found;

# Load any additional predicate specifications
my $predicates_file = $switches->get("predicates");
$predicates->load($predicates_file) if defined $predicates_file;

# How should multiple assertions of the same triple be handled?
$multiple_attestations = uc $switches->get("multiple");
$logger->NIST_die("Argument to -multiple switch must be one of [" . join(", ", sort keys %multiple_attestations) . "]")
  unless $multiple_attestations{$multiple_attestations};

# Add the user's selected warnings to the list of warnings to ignore
my $ignore = $switches->get("ignore");
if (defined $ignore) {
  my @warnings = map {uc} split(/:/, $ignore);
  foreach my $warning (@warnings) {
    $logger->ignore_warning($warning);
  }
}

# Load mapping from docid to length of that document
my $docids_file = $switches->get("docs");
my $docids;
if (defined $docids_file) {
  open(my $infile, "<:utf8", $docids_file) or $logger->NIST_die("Could not open $docids_file: $!");
  while(<$infile>) {
    chomp;
    my ($docid, $document_length) = split(/\t/);
    $docids->{$docid} = $document_length;
  }
  close $infile;
  Provenance::set_docids($docids);
}

# Load the knowledge base
$kb = &load_tac($logger, $predicates, $filename, $docids);

# Problems were identified while the KB was loaded; now report them
my ($num_errors, $num_warnings) = $logger->report_all_problems();
if ($num_errors) {
  $logger->NIST_die("$num_errors error" . ($num_errors == 1 ? '' : 's') . " encountered");
}
else {
  print $error_output ($num_warnings || 'No'), " warning", ($num_warnings == 1 ? '' : 's'), " encountered\n";
  # Output the KB if so desired
  if ($output_fn) {
    &{$output_fn}($kb, \%output_labels);
  }
}

exit 0;

################################################################################
# Revision History
################################################################################

# 1.0 - Original version
# 1.1 - Changed comment deletion pattern to use older syntax for possessive matches
#     - Increased robustness to ill-formed submission files
#     - Allowed multiple predicate domains and ranges
# 1.2 - Added check that entities in relations are attested in the document attesting to the relation
#     - Added switches for redirecting standard and error output
#     - Added NIST exit code on failure
#     - Modified document lengths code to accept length rather than index of last character
#     - UTF-8 compliance
#     - Allowed user-defined relations
#     - Ensured that if a relation is omitted from the output, its inverse is too
# 1.3 - Added binmode(STDOUT, ":utf8"); to avoid wide character errors
#
# 2.0 - Updated for TAC 2013
#     - per:employee_or_member_of
#     - New offset specifications (no longer pairs)
#     - Updated predicate alias list
#     - Added tac2012 input option
#
# 3.0 - Updated for TAC 2014
#     - Completely refactored
# 3.1 - Minor refactoring to help support other scripts
# 3.2 - Ensured all program exits are NIST-compliant
#
# 4.0 - First version on GitHub
# 4.1 - Added export in EDL format
# 4.2 - Fixed bug in which LINK relations were receiving a leading entity type

1;

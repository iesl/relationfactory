#!/usr/bin/perl

use warnings;
use strict;

binmode(STDOUT, ":utf8");

##################################################################################### 
# This program produces Cold Start 2014 queries for the second round
# of a Slot Filling variant submission. It takes as input the
# evaluation queries and a first round output file.
#
# Author: James Mayfield
# Please send questions or comments to jamesmayfield "at" gmail "dot" com
#
# For usage, run with no arguments
##################################################################################### 

my $version = "1.4";

# Filehandles for program and error output
my $program_output = *STDOUT{IO};
my $error_output = *STDERR{IO};


package main;

##################################################################################### 
# UUIDs from UUID::Tiny
##################################################################################### 

# The following UUID code is taken from UUID::Tiny, available on
# cpan.org. I have stripped out much of the functionality in that
# module, keeping only what's needed here. If there is a better way to
# deliver a cpan module within a single script, I'd love to know about
# it. I believe that this use conforms with the perl terms.

####################################
# From the UUID::Tiny documentation:
####################################

=head1 ACKNOWLEDGEMENTS

Kudos to ITO Nobuaki E<lt>banb@cpan.orgE<gt> for his UUID::Generator::PurePerl
module! My work is based on his code, and without it I would've been lost with
all those incomprehensible RFC texts and C codes ...

Thanks to Jesse Vincent (C<< <jesse at bestpractical.com> >>) for his feedback, tips and refactoring!

=head1 COPYRIGHT & LICENSE

Copyright 2009, 2010, 2013 Christian Augustin, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

ITO Nobuaki has very graciously given me permission to take over copyright for
the portions of code that are copied from or resemble his work (see
rt.cpan.org #53642 L<https://rt.cpan.org/Public/Bug/Display.html?id=53642>).

=cut

use Digest::MD5;

our $IS_UUID_STRING = qr/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/is;
our $IS_UUID_HEX    = qr/^[0-9a-f]{32}$/is;
our $IS_UUID_Base64 = qr/^[+\/0-9A-Za-z]{22}(?:==)?$/s;

my $MD5_CALCULATOR = Digest::MD5->new();

use constant UUID_NIL => "\x00" x 16;
use constant UUID_V1 => 1; use constant UUID_TIME   => 1;
use constant UUID_V3 => 3; use constant UUID_MD5    => 3;
use constant UUID_V4 => 4; use constant UUID_RANDOM => 4;
use constant UUID_V5 => 5; use constant UUID_SHA1   => 5;

sub _create_v3_uuid {
    my $ns_uuid = shift;
    my $name    = shift;
    my $uuid    = '';

    # Create digest in UUID ...
    $MD5_CALCULATOR->reset();
    $MD5_CALCULATOR->add($ns_uuid);

    if ( ref($name) =~ m/^(?:GLOB|IO::)/ ) {
        $MD5_CALCULATOR->addfile($name);
    }
    elsif ( ref $name ) {
        Logger->new()->NIST_die('::create_uuid(): Name for v3 UUID'
            . ' has to be SCALAR, GLOB or IO object, not '
            . ref($name) .'!')
            ;
    }
    elsif ( defined $name ) {
        $MD5_CALCULATOR->add($name);
    }
    else {
        Logger->new()->NIST_die('::create_uuid(): Name for v3 UUID is not defined!');
    }

    # Use only first 16 Bytes ...
    $uuid = substr( $MD5_CALCULATOR->digest(), 0, 16 ); 

    return _set_uuid_version( $uuid, 0x30 );
}

sub _set_uuid_version {
    my $uuid = shift;
    my $version = shift;
    substr $uuid, 6, 1, chr( ord( substr( $uuid, 6, 1 ) ) & 0x0f | $version );

    return $uuid;
}

sub create_uuid {
    use bytes;
    my ($v, $arg2, $arg3) = (shift || UUID_V1, shift, shift);
    my $uuid    = UUID_NIL;
    my $ns_uuid = string_to_uuid(defined $arg3 ? $arg2 : UUID_NIL);
    my $name    = defined $arg3 ? $arg3 : $arg2;

    ### Portions redacted from UUID::Tiny
    if ($v == UUID_V3 ) {
        $uuid = _create_v3_uuid($ns_uuid, $name);
    }
    else {
        Logger->new()->NIST_die("::create_uuid(): Invalid UUID version '$v'!");
    }

    # Set variant 2 in UUID ...
    substr $uuid, 8, 1, chr(ord(substr $uuid, 8, 1) & 0x3f | 0x80);

    return $uuid;
}

sub string_to_uuid {
    my $uuid = shift;

    use bytes;
    return $uuid if length $uuid == 16;
    return decode_base64($uuid) if ($uuid =~ m/$IS_UUID_Base64/);
    my $str = $uuid;
    $uuid =~ s/^(?:urn:)?(?:uuid:)?//io;
    $uuid =~ tr/-//d;
    return pack 'H*', $uuid if $uuid =~ m/$IS_UUID_HEX/;
    Logger->new()->NIST_die("::string_to_uuid(): '$str' is no UUID string!");
}

sub uuid_to_string {
    my $uuid = shift;
    use bytes;
    return $uuid
        if $uuid =~ m/$IS_UUID_STRING/;
    Logger->new()->NIST_die("::uuid_to_string(): Invalid UUID!")
        unless length $uuid == 16;
    return  join '-',
            map { unpack 'H*', $_ }
            map { substr $uuid, 0, $_, '' }
            ( 4, 2, 2, 2, 6 );
}

sub create_UUID_as_string {
    return uuid_to_string(create_uuid(@_));
}

##################################################################################### 
# This is the end of the code taken from UUID::Tiny
##################################################################################### 

sub uuid_generate {
  my ($queryid, $value, $provenance_string) = @_;
  create_UUID_as_string(UUID_V3, "$queryid:$value:$provenance_string");
}

sub dump_structure {
  my ($structure, $label, $indent, $history, $skip) = @_;
  if (ref $indent) {
    $skip = $indent;
    undef $indent;
  }
  my $outfile = *STDERR;
  $indent = 0 unless defined $indent;
  $history = {} unless defined $history;
  # if ($history->{$structure}) {
  #   print $outfile "  " x $indent, "$label: CIRCULAR\n";
  #   return;
  # }
  my $type = ref $structure;
  unless ($type) {
    $structure = 'undef' unless defined $structure;
    print $outfile "  " x $indent, "$label: $structure\n";
    return;
  }
  if ($type eq 'ARRAY') {
    $history->{$structure}++;
    print $outfile "  " x $indent, "$label:\n";
    for (my $i = 0; $i < @{$structure}; $i++) {
      &dump_structure($structure->[$i], $i, $indent + 1, $history, $skip);
    }
  }
  elsif ($type eq 'CODE') {
    print $outfile "  " x $indent, "$label: CODE\n";
  }
  elsif ($type eq 'IO::File') {
    print $outfile "  " x $indent, "$label: IO::File\n";
  }
  else {
    $history->{$structure}++;
    print $outfile "  " x $indent, "$label:\n";
    my %done;
  outer: 
    foreach my $key ('STEPS', 'HIERARCHY', 'TYPE', 'NAME', 'ENTRY', 'REQUIREMENTS', 'COMMAND', 'CREATIONS', 'EXIT', sort keys %{$structure}) {
      if ($skip) {
	foreach my $skipname (@{$skip}) {
	  next outer if $key eq $skipname;
	}
      }
      next if $done{$key}++;
      # Skip undefs
      next unless defined $structure->{$key};
      next unless $structure->{$key};
      &dump_structure($structure->{$key}, $key, $indent + 1, $history, $skip);
    }
  }
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
  ILLEGAL_DOCID                ERROR    DOCID %s is not a valid DOCID for this task
  ILLEGAL_OFFSET               ERROR    %s is not a valid offset
  ILLEGAL_OFFSET_IN_DOC        ERROR    %s is not a valid offset for DOCID %s
  ILLEGAL_OFFSET_PAIR          ERROR    (%s, %s) is not a valid offset pair
  ILLEGAL_OFFSET_PAIR_STRING   ERROR    %s is not a valid offset pair string
  ILLEGAL_OFFSET_TRIPLE_STRING ERROR    %s is not a valid docid/offset pair string
  TOO_MANY_PROVENANCE_TRIPLES  WARNING  Too many provenance triples (%d) provided; only the first %d will be used
  TOO_MANY_CHARS               WARNING  Provenance contains too many characters; only the first %d will be used
  TOO_MANY_TOTAL_CHARS         ERROR    All provenance strings contain a total of more than %d characters

########## Knowledge Base Errors
  AMBIGUOUS_PREDICATE          ERROR    %s: ambiguous predicate
  COLON_OMITTED                WARNING  Initial colon omitted from name of entity %s
  DUPLICATE_ASSERTION          WARNING  The same assertion is made more than once (%s)
  ILLEGAL_CONFIDENCE_VALUE     ERROR    Illegal confidence value: %s
  ILLEGAL_ENTITY_NAME          ERROR    Illegal entity name: %s
  ILLEGAL_ENTITY_TYPE          ERROR    Illegal entity type: %s
  ILLEGAL_PREDICATE            ERROR    Illegal predicate: %s
  ILLEGAL_PREDICATE_TYPE       ERROR    Illegal predicate type: %s
  MISSING_CANONICAL            WARNING  Entity %s has no canonical mention in document %s
  MISSING_INVERSE              WARNING  No inverse relation asserted for %s(%s, %s)
  MISSING_RUNID                ERROR    The first line of the file does not contain a legal runid
  MISSING_TYPEDEF              WARNING  No type asserted for Entity %s
  MULTIPLE_CANONICAL           ERROR    More than one canonical mention for Entity %s in document %s
  MULTIPLE_FILLS_ENTITY        WARNING  Entity %s has multiple %s fills, but should be single-valued
  MULTITYPED_ENTITY            ERROR    Entity %s has more than one type: %s
  NO_MENTIONS                  WARNING  Entity %s has no mentions
# OVERLAPPING_MENTIONS         ERROR    Overlapping mentions at positions %s and %s in document %s
  PREDICATE_ALIAS              WARNING  Use of %s predicate; %s replaced with %s
  STRING_USED_FOR_ENTITY       ERROR    Expecting an entity, but got string %s
  SUBJECT_PREDICATE_MISMATCH   ERROR    Type of subject (%s) does not match type of predicate (%s)
  UNASSERTED_MENTION           WARNING  Failed to assert that %s in document %s is also a mention
  UNATTESTED_RELATION_ENTITY   ERROR    Relation %s uses entity %s, but that entity is has no mentions in provenance %s
  UNQUOTED_STRING              WARNING  String %s not surrounded by double quotes
  UNKNOWN_TYPE                 ERROR    Cannot infer type for Entity %s

########## Query File Errors
  DUPLICATE_QUERY              WARNING  Duplicate query ID %s
  DUPLICATE_QUERY_FIELD        WARNING  Duplicate <%s> tag
  MALFORMED_QUERY              ERROR    Malformed query
  MISMATCHED_TAGS              WARNING  <%s> tag closed with </%s>
  MISSING_QUERY_FIELD          ERROR    Missing <%s> tag in query %s
  NO_QUERIES_LOADED            WARNING  No queries found
  QUERY_WITHOUT_LOADED_PARENT  ERROR    Query %s has parent %s that was not loaded
  UNKNOWN_QUERY_FIELD          WARNING  <%s> is not a recognized query field
  UNLOADED_QUERY               WARNING  Query %s is not present in the query files; skipping it

########## Submission File/Assessment File Errors
  MISMATCHED_RUNID             WARNING  Round 1 uses runid %s but Round 2 uses runid %s; selecting the former
  MULTIPLE_FILLS_SLOT          WARNING  Multiple responses given to single-valued slot %s
  MULTIPLE_RUNIDS              WARNING  File contains multiple run IDs (%s, %s)
  UNKNOWN_QUERY_ID             ERROR    Unknown query: %s
  UNKNOWN_RESPONSE_FILE_TYPE   FATAL_ERROR %s is not a known response file type
  UNKNOWN_SLOT_NAME            ERROR    Unknown slot name: %s
  
########## Multi-Use Errors
  WRONG_NUM_ENTRIES            ERROR    Wrong number of entries on line (expected %d, got %d)

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

my $NIST_error_code = 255;

sub NIST_die {
  my ($self, @messages) = @_;
  my $outfile = $self->{ERROR_OUTPUT};
  print $outfile join("", @messages), " at (", join(":", caller), ")\n";
  exit $NIST_error_code;
}

package main;

##################################################################################### 
# Provenance
##################################################################################### 

package Provenance;

# Bounds

my $max_chars_per_triple = 150;
my $max_total_chars = 600;
my $max_triples = 4;

{
  my $docids;

  sub set_docids {
    $docids = $_[0];
  }

  # Validate a particular docid/offset-pair entry
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
    return 'passed';
  }
}

# This is used to, among other things, get a consistent string
# representing the provenance for use in construction of a UUID
sub tostring {
  my ($self) = @_;
#print STDERR "tostring called from ", join(":", caller), "\n";
  join(",", map {"$_->{DOCID}:$_->{START}-$_->{END}"}
       sort {$a->{DOCID} cmp $b->{DOCID} || $a->{START} <=> $b->{START} || $a->{END} cmp $b->{END}}
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
#print STDERR "====> empty\n";
    # DO NOTHING
  }
  elsif ($type eq 'DOCID_OFFSET_OFFSET') {
#print STDERR "====> doo\n";
    my ($docid, $start, $end) = @values;
    if (&check_triple($logger, $where, $docid, $start, $end)) {
      push(@{$self->{TRIPLES}}, {DOCID => $docid,
				 START => $start,
				 END => $end,
				 WHERE => $where});
      $total += $end - $start + 1;
    }
  }
  elsif ($type eq 'DOCID_OFFSETPAIRLIST') {
#print STDERR "====> dopl\n";
    my ($docid, $offset_pair_list) = @values;
    my $start;
    my $end;
    foreach my $pair (split(/,/, $offset_pair_list)) {
      unless (($start, $end) = $pair =~ /^\s*(\d+)-(\d+)\s*$/) {
	$logger->record_problem('ILLEGAL_OFFSET_PAIR_STRING', $pair, $where);
	$start = 0;
	$end = 0;
      }
      if (&check_triple($logger, $where, $docid, $start, $end)) {
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
#print STDERR "====> ptl\n";
    my ($triple_list) = @values;
    my @triple_list = split(/,/, $triple_list);
    if (@triple_list > $max_triples) {
      $logger->record_problem('TOO_MANY_PROVENANCE_TRIPLES', scalar @triple_list, $max_triples, $where);
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
      if (&check_triple($logger, $where, $docid, $start, $end)) {
#print STDERR "($docid, $start, $end) passed\n";
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

###############################################################################################################
##### Predicates
###############################################################################################################

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


package Predicates;

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

# Create a new Predicates object
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
  # The source appears as the last argument passed; preceding arguments are not necessarily present
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
    unless($Predicates::legal_domain_types{$domain_string}) {
      $self->{LOGGER}->record_problem('ILLEGAL_PREDICATE_TYPE', $domain_string, $source);
      return;
    }
  }
  if (defined $domain_string &&
      defined $subject_type &&
      $Predicates::legal_domain_types{$subject_type} &&
      $domain_string ne $subject_type) {
    $self->{LOGGER}->record_problem('SUBJECT_PREDICATE_MISMATCH', $subject_type, $domain_string, $source);
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
  my $alias = $predicate_aliases{lc $domain}{$predicate} || $predicate_aliases{'any'}{$predicate};
  return $predicate unless defined $alias;
  $self->{LOGGER}->record_problem('PREDICATE_ALIAS', $alias->{REASON}, $predicate, $alias->{REPLACEMENT}, $source);
  $alias->{REPLACEMENT};
}

# Load predicates from a file. This allows additional user-defined predicates.
sub load {
  my ($self, $filename) = @_;
  my $base_filename = $filename;
  $base_filename =~ s/.*\///;
  $self->{LOGGER}->NIST_die("Filename for predicates files should be <label>.predicates.txt") unless $base_filename =~ /^(\w+)\.predicates.txt$/;
  my $label = uc $1;
  open(my $infile, "<:utf8", $filename) or $self->{LOGGER}->NIST_die("Could not open $filename: $!");
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
    $predicates->{LOGGER}->NIST_die("Illegal domain type: $type") unless $Predicates::legal_domain_types{$type};
  }
  # Do the same for the range
  my $range = {map {$_ => 'true'} split(/,/, lc $range_string)};
  foreach my $type (keys %{$range}) {
    $predicates->{LOGGER}->NIST_die("Illegal range type: $type") unless $Predicates::legal_range_types{$type};
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
  $predicates->{LOGGER}->NIST_die("More than one predicate defined for $name($domain_string, $range_string)") if @predicates > 1;
  my $predicate;
  if (@predicates) {
    $predicate = $predicates[0];
    my $current_inverse_name = $predicate->get_inverse_name();
    $predicates->{LOGGER}->NIST_die("Attempt to redefine inverse of predicate $domain_string:$name from $current_inverse_name to $inverse_name")
      unless $current_inverse_name eq $inverse_name;
    $predicates->{LOGGER}->NIST_die("Attempt to redefine quantity of predicate $domain_string:$name from $predicate->{QUANTITY} to $quantity")
	unless $predicate->{QUANTITY} eq $quantity;
    my @inverses = $predicates->lookup_predicate($inverse_name, $range, $domain);
    $predicates->{LOGGER}->NIST_die("Multiple inverses with form $inverse_name($range_string, $domain_string)")
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
  $predicate->{INVERSE} = $class->new($predicates, $range_string, $original_inverse_name, $domain_string, $original_name, $label)
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

##################################################################################### 
# Query
##################################################################################### 

package Query;

my %tags = (
  ENTRYPOINTS => {ORD => 0, TYPE => 'single'},
  ENTTYPE =>     {ORD => 1, TYPE => 'single',   YEARS => '2014'},
  SLOT =>        {ORD => 2, TYPE => 'single',   YEARS => '2014'},
  SLOT0 =>       {ORD => 3, TYPE => 'single',   REQUIRED => 'yes'},
  SLOT1 =>       {ORD => 4, TYPE => 'single',   },
  SLOT2 =>       {ORD => 5, TYPE => 'single',   YEARS => '2012'},

  NAME =>        {ORD => 1, TYPE => 'multiple', REQUIRED => 'yes'},
  DOCID =>       {ORD => 2, TYPE => 'multiple', REQUIRED => 'yes'},
  BEG =>         {ORD => 3, TYPE => 'multiple', REQUIRED => 'yes', REWRITE => 'START'},
  END =>         {ORD => 4, TYPE => 'multiple', REQUIRED => 'yes'},
  OFFSET =>      {ORD => 5, TYPE => 'multiple', YEARS => '2012:2013'},
);

sub put {
  my ($self, $fieldname, $value) = @_;
  $self->{uc $fieldname} = $value;
  $value;
}

sub get {
  my ($self, $fieldname) = @_;
  $self->{uc $fieldname};
}

sub get_entrypoint {
  my ($self, $pos) = @_;
  $pos = 0 unless defined $pos;
  $self->{ENTRYPOINTS}[$pos];
}

sub add_entrypoint {
  my ($self, %entrypoint) = @_;
#print STDERR "add_entrypoint called from ", join(":", caller), "\n";
  unless (defined($entrypoint{PROVENANCE})) {
    $entrypoint{PROVENANCE} = Provenance->new($self->{LOGGER},
					      $entrypoint{WHERE} || {FILENAME => 'UNKNOWN', LINENUM => 'UNKNOWN'},
					      'DOCID_OFFSET_OFFSET',
					      $entrypoint{DOCID},
					      $entrypoint{START},
					      $entrypoint{END});
  }
  my $provenance = $entrypoint{PROVENANCE};
  $entrypoint{DOCID} = $provenance->{TRIPLES}[0]{DOCID} unless defined $entrypoint{DOCID};
  $entrypoint{START} = $provenance->{TRIPLES}[0]{START} unless defined $entrypoint{START};
  $entrypoint{END} = $provenance->{TRIPLES}[0]{END} unless defined $entrypoint{END};
  $entrypoint{UUID} = &main::uuid_generate($self->{QUERY_ID}, $entrypoint{NAME}, $provenance->tostring())
    unless defined $entrypoint{UUID};
  push(@{$self->{ENTRYPOINTS}}, \%entrypoint);
  \%entrypoint;
}

# Create a new Query object
sub new {
  my ($class, $logger, $text) = @_;
  my $self = {LOGGER => $logger, ENTRYPOINTS => []};
  bless($self, $class);
  $self->populate_from_text($text) if defined $text;
  $self;
}

# Convert the text of the query to a query object
sub populate_from_text {
  my ($self, $text) = @_;
  if ($text !~ /^\s*<query\s+id="(.*?)">\s*(.*?)\s*<\/query>\s*$/s) {
    $self->{LOGGER}->record_problem('MALFORMED_QUERY', "Query starting with \"" . substr($text, 0, 25) . "\"", "In text beginning <<" . substr($text, 0, 25) . ">>");
    return;
  }
  my $id = $1;
  my $body = $2;
  $self->{QUERY_ID} = $id;
  my $where = {FILENAME => $self->{FILENAME}, LINENUM => "In query $id"};
  my $entrypoint = {};
  # Find all tag pairs within the query
  while ($body =~ /<(.*?)>(.*?)<\/(.*?)>/gs) {
    my ($tag, $value, $closer) = ($1, $2, $3);
    $tag = uc $tag;
    $closer = uc $closer;
    # Map from <beg> to <start>
    $self->{LOGGER}->record_problem('MISMATCHED_TAGS', $tag, $closer, $where) unless $tag eq $closer;
    my $info = $tags{$tag};
    unless (defined $info) {
      $self->{LOGGER}->record_problem('UNKNOWN_QUERY_FIELD', $tag, $where);
      next;
    }
    # apply aliases and renamings
    $tag = $info->{REWRITE} if defined $info->{REWRITE};
    # 2013 included more than one entrypoint per query. Here we
    # collect each such entrypoint into its own hash
    if ($info->{TYPE} eq 'multiple') {
      if (defined $entrypoint->{$tag}) {
	$self->add_entrypoint(%{$entrypoint}, WHERE => $where);
	$entrypoint = {};
      }
      $entrypoint->{$tag} = $value;
    }
    else {
      if (defined $self->{$tag}) {
	$self->{LOGGER}->record_problem('DUPLICATE_QUERY_FIELD', $tag, $where);
      }
      else {
	$self->put($tag, $value);
      }
    }
  }
  $self->add_entrypoint(%{$entrypoint}, WHERE => $where) if keys %{$entrypoint};

  # The Query ID is not a field, but comes from the <query> tag. So
  # we add it to the result explicitly
  $self->{QUERY_ID} = $id;
  # Find all the slots for this query (different evaluation queries
  # may have different numbers of slots to be traversed).
  for (my $i = 0; ; $i++) {
    # Slots are all named something like 'slot3'
    my $key = "SLOT$i";
    last unless defined $self->{$key};
    push (@{$self->{SLOTS}}, $self->{$key});
  }
  $self;
}

# Convert the query object back to the correct text file format
sub tostring {
  my ($self, $indent) = @_;
  $indent = "" unless defined $indent;
  my $string = "$indent<query id=\"$self->{QUERY_ID}\">\n";
  foreach my $field (sort {$tags{$a}{ORD} <=> $tags{$b}{ORD}} grep {$tags{$_}{TYPE} eq 'single'} keys %tags) {
    if ($field eq 'ENTRYPOINTS') {
      foreach my $entrypoint (@{$self->{ENTRYPOINTS}}) {
	foreach my $subfield (sort {$tags{$a}{ORD} <=> $tags{$b}{ORD}} grep {$tags{$_}{TYPE} eq 'multiple'} keys %tags) {
	  my $value = defined $tags{$subfield}{REWRITE} ? $entrypoint->{$tags{$subfield}{REWRITE}} : $entrypoint->{$subfield};
	  if (defined $value) {
	    $string .= "$indent  <" . lc($subfield) . ">$value</" . lc($subfield) . ">\n";
	  }
	  elsif ($tags{$subfield}{REQUIRED}) {
	    # FIXME
	    $self->{LOGGER}->NIST_die("Missing query field: <$subfield>");
	  }
	  else {
	    # Just skip this field
	  }
	}
      }
    }
    else {
      $string .= "$indent  <" . lc($field) . ">$self->{$field}</" . lc($field) . ">\n" if defined $self->{$field};
    }
  }
  $string .= "$indent</query>\n";
  $string;
}

package main;

##################################################################################### 
# QuerySet
##################################################################################### 

package QuerySet;

# Create a new QuerySet object
sub new {
  my ($class, $logger, @filenames) = @_;
  my $self = {LOGGER => $logger, FILENAMES => \@filenames, QUERIES => {}};
  bless($self, $class);
  foreach my $filename (@filenames) {
    # Slurp the entire text
    open(my $infile, "<:utf8", $filename) or $logger->NIST_die("Could not open $filename: $!");
    local($/);
    my $text = <$infile>;
    close $infile;
    $self->populate_from_text($text);
  }
  # Make sure that at least one query was found
  $logger->record_problem('NO_QUERIES_LOADED', "files(" . join(", ", @filenames) . ")")
    unless !@filenames || keys %{$self->{QUERIES}};
#  $self->check_queries($logger);
  $self;
}

# Convert an evaluation query file to a QuerySet
sub populate_from_text {
  my ($self, $text) = @_;
  # Repeatedly look for text that lies between <query> and </query>
  # tags.
  while ($text =~ /(<query .*?>.*?<\/query>)/gs) {
    my $querytext = $1;
    my $query = Query->new($self->{LOGGER}, $querytext);
    $self->add($query);
  }
}

# Add a query to this QuerySet
sub add {
  my ($self, $query) = @_;
  my $id = $query->get("QUERY_ID");
  if ($self->{QUERIES}{$id}) {
    $self->{LOGGER}->record_problem('DUPLICATE_QUERY', $id, "NO_SOURCE");
  } else {
    $self->{QUERIES}{$id} = $query;
  }
  $query;
}

# Find the query with the provided query ID
sub get {
  my ($self, $queryid) = @_;
  $self->{QUERIES}{$queryid};
}

sub get_all {
  my ($self) = @_;
  values %{$self->{QUERIES}};
}

# Convert the QuerySet to text form, suitable for print as a TAC evaluation query file
sub tostring {
  my ($self, $indent) = @_;
  $indent = "" unless defined $indent;
  my $string = "$indent<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n$indent<query_set>\n";
  foreach my $query (sort {$a->{QUERY_ID} cmp $b->{QUERY_ID}} values %{$self->{QUERIES}}) {
    $string .= $query->tostring("$indent  ");
  }
  $string .= "$indent</query_set>\n";
  $string;
}


package main;

###############################################################################################################
##### Evaluation Query Output
###############################################################################################################

# This class is used to represent Slot Filling Variant output, the
# result of applying evaluation queries to a knowledge base, and
# assessment output from LDC

package EvaluationQueryOutput;

# Maps LDC judgments to one of {CORRECT, INCORRECT, IGNORE, NOT_ASSESSED}
my %correctness_map = (
  CORRECT =>       'CORRECT',
  WRONG =>         'INCORRECT',
  INEXACT =>       'INCORRECT',
  INEXACT_SHORT => 'INCORRECT',
  INEXACT_LONG =>  'INCORRECT',
  IGNORE =>        'IGNORE',
  NOT_ASSESSED =>  'NOT_ASSESSED',
);

# The schemas for the submission and assessment files have changed
# over the years. This table specifies each such format, and allows
# code that calculates or normalizes fields
my %schemas = (

  '2014SFsubmissions' => {
    YEAR => 2014,
    TYPE => 'SUBMISSION',
    TASK => 'SF',
    COLUMNS => [qw(
      QUERY_ID
      SLOT_NAME
      RUNID
      RELATION_PROVENANCE_TRIPLES
      VALUE
      VALUE_PROVENANCE_TRIPLES
      CONFIDENCE
    )],
    BUILD => sub {
      my ($logger, $where, $entry, $globals) = @_;
      $entry->{VALUE_PROVENANCE} = Provenance->new($logger, $where, 'PROVENANCETRIPLELIST',
						   $entry->{VALUE_PROVENANCE_TRIPLES});
      $entry->{RELATION_PROVENANCE} = Provenance->new($logger, $where, 'PROVENANCETRIPLELIST',
						      $entry->{RELATION_PROVENANCE_TRIPLES});
      # Split the domain name from the slot name
      $entry->{SLOT_NAME} =~ /^(.*?):(.*)$/;
      $entry->{TYPE} = $1;
      my $shortname = $2;
      my $predicates = Predicates->new($logger);
      my @candidates = $predicates->lookup_predicate($shortname, $entry->{TYPE});
      unless (@candidates) {
	$logger->record_problem('UNKNOWN_SLOT_NAME', $entry->{SLOT_NAME}, $where);
	return;
      }
      my $quantity = $candidates[0]{QUANTITY};
      if ($quantity eq 'single') {
	if ($globals->{SINGLES}{$entry->{QUERY_ID}}++) {
	  $logger->record_problem('MULTIPLE_FILLS_SLOT', $entry->{SLOT_NAME}, $where);
	  return;
	}
      }
      return "success";
    },
  },


);

# Build a pattern that will recognize assessment codes (we just build
# a single one for all years)
my %all_assessment_codes;
foreach my $schema (values %schemas) {
  next unless $schema->{ASSESSMENT_CODES};
  foreach my $key (keys %{$schema->{ASSESSMENT_CODES}}) {
    $all_assessment_codes{$key}++;
  }
}
my $assessment_code_string = join("|", keys %all_assessment_codes);
my $assessment_code_pattern = qr/$assessment_code_string/o;
# Build other patterns that will be helpful in recognizing file types
my $provenance_triples_pattern = qr/(?:[^:]+:\d+-\d+,){0,3}[^:]+:\d+-\d+/;
my $anything_pattern = qr/.+/;
my $digits_pattern = qr/\d+/;


# Map each field name that appears in any schema to a pattern that
# will recognize it with 100% recall (precision may well be under
# 100%)
my %schema_patterns = (
  CONFIDENCE =>                  qr/\d+\.\d+/,
  DOCID =>                       $anything_pattern,
  ID =>                          $anything_pattern,
  OBJECT_ASSESSMENT =>           $assessment_code_pattern,
  OBJECT_OFFSETS =>              qr/\d+-\d+(?:,\d+-\d+)?/,
  OBJECT_OFFSET_END =>           $digits_pattern,
  OBJECT_OFFSET_START =>         $digits_pattern,
  PARENT_ID =>                   $anything_pattern,
  PREDICATE_OFFSETS =>           qr/\d+-\d+(?:,\d+-\d+)?/,
  PREDICATE_OFFSET_END =>        $digits_pattern,
  PREDICATE_OFFSET_START =>      $digits_pattern,
  PROVENANCE_ASSESSMENT =>       $assessment_code_pattern,
  QUERY_ID =>                    $anything_pattern,
  QUERY_AND_HOP =>               qr/.+_\d+/,
  RELATION_ASSESSMENT =>         $assessment_code_pattern,
  RELATION_PROVENANCE_TRIPLES => $provenance_triples_pattern,
  RUNID =>                       $anything_pattern,
  SLOT_NAME =>                   qr/[^:]+:[^:]+/,
  SUBJECT_ASSESSMENT =>          $assessment_code_pattern,
  SUBJECT_OFFSETS =>             qr/\d+-\d+(?:,\d+-\d+)?/,
  VALUE =>                       $anything_pattern,
  VALUE_ASSESSMENT =>            $assessment_code_pattern,
  VALUE_EC =>                    $anything_pattern,
  VALUE_PROVENANCE_TRIPLES =>    $provenance_triples_pattern,
);

# Try to determine what type of TSV file this is, based on how the
# first line of entries matches field patterns
sub identify_file_type {
  my ($logger, $filename) = @_;
  open(my $infile, "<:utf8", $filename) or $logger->NIST_die("Could not open $filename: $!");
  while (<$infile>) {
    chomp;
    s/$main::comment_pattern/$1/;
    my $comment = $2 || "";
    # Skip blank lines
    next unless /\S/;
    # Kill carriage returns (FIXME: We might need to replace them with
    # \ns in some strange Microsoft future)
    s/\r//gs;
    # Go through each tab-separated element, seeing whether it is
    # compatible with the field required by this schema
    my @elements = split(/\t/);
  schema:
    foreach my $type (keys %schemas) {
      my $schema = $schemas{$type};
      next unless @elements == @{$schema->{COLUMNS}};
      my @current_elements = @elements;
      foreach my $column (@{$schema->{COLUMNS}}) {
	my $element = shift @current_elements;
	my $pattern = $schema_patterns{$column};
	$logger->NIST_die("Internal error: no pattern found for column $column") unless $pattern;
	next schema unless $element =~ /^$pattern$/;
      }
      close $infile;
      return $type;
    }
    $logger->NIST_die("Unknown file type: $filename");
  }
  $logger->NIST_die("Empty file: $filename");
}

sub generate_round2_query {
#print STDERR "VVVVV gr2q\n";
  my ($logger, $submission) = @_;
  my $original_query = $submission->{QUERY};
  $logger->NIST_die("Query ID $submission->{QUERY_ID} not found") unless defined $original_query;
  my $new_queryid = "$submission->{QUERY_ID_BASE}_$submission->{TARGET_UUID}";
  my $new_query = Query->new($logger);
  $new_query->put('QUERY_ID', $new_queryid);
  $new_query->add_entrypoint(NAME => $submission->{VALUE},
			     PROVENANCE => $submission->{VALUE_PROVENANCE});
  $new_query->put('ENTTYPE', $submission->{TYPE});
  foreach my $key (keys %{$original_query}) {
    $new_query->put($key, $original_query->get($key)) if $key =~ /^slot(\d+)$/i;
  }
  # FIXME: Should be generalized to multiple hops
  $new_query->put('SLOT', $new_query->get('SLOT1'));
#print STDERR "^^^^^ gr2q\n";
  $new_query;
}

# Load an evaluation query output file or an assessment file
sub load {
  my ($self, $logger, $queries, $filename, $schema) = @_;
  my $globals = {};
  open(my $infile, "<:utf8", $filename) or$logger->NIST_die("Could not open $filename: $!");
  my $columns = $schema->{COLUMNS};
  while (<$infile>) {
    chomp;
    # Kill carriage returns (FIXME: We might need to replace them with
    # \ns in some strange Microsoft future)
    s/\r//gs;
    # Eliminate comments, ensuring that pound signs in the middle of
    # strings are not treated as comment characters
    s/$main::comment_pattern/$1/;
    my $comment = $2 || "";
    # Skip blank lines
    next unless /\S/;
    # Note the current location for use by the logger
    my $where = {FILENAME => $filename, LINENUM => $.};
    # Align the tab-separated elements on the line with the expected set of columns
    my @elements = split(/\t/);
    if (@elements != @{$columns}) {
      $logger->record_problem('WRONG_NUM_ENTRIES', scalar @{$columns}, scalar @elements, $where);
      next;
    }
    my $entry = {map {$columns->[$_] => $elements[$_]} 0..$#elements};
    $entry->{COMMENT} = $comment;
    # Remember where this entry came from
    $entry->{LINE} = $_;
    $entry->{FILENAME} = $filename;
    $entry->{LINENUM} = $.;

    # Remember the year and type of the entry
    $entry->{YEAR} = $schema->{YEAR};
    $entry->{TYPE} = uc $schema->{TYPE};

    if ($schema->{BUILD}) {
      my $success = &{$schema->{BUILD}}($logger, $where, $entry, $globals);
      next unless $success;
    }

    my $current_runid = $self->get_runid();
    if (defined $current_runid) {
      if (defined $entry->{RUNID} && $entry->{RUNID} ne $current_runid) {
	$logger->record_problem('MULTIPLE_RUNIDS', $current_runid, $entry->{RUNID}, $entry);
	$entry->{RUNID} = $current_runid;
      }
    }
    else {
      $self->set_runid($entry->{RUNID});
    }

    my $query = $queries->get($entry->{QUERY_ID});
    unless ($query) {
      $logger->record_problem('UNLOADED_QUERY', $entry->{QUERY_ID}, $where);
      next;
    }
    $entry->{QUERY} = $query;

    # We may need to remove _PSEUDO (for 2013 queries) or a UUID (for 2014 queries) to get the base query name
    $entry->{QUERY_ID_BASE} = $entry->{QUERY_ID};
    $entry->{QUERY_ID_BASE} = $1 if $entry->{QUERY_ID} =~ /^(.*?)_\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/;
    $entry->{QUERY_ID_BASE} = $1 if $entry->{QUERY_ID} =~ /^(.*?)_PSEUDO/;

    # Map assessments onto a standard set valid across years
    foreach my $key (keys %{$entry}) {
      next unless $key =~ /_ASSESSMENT$/;
      $entry->{$key} = $schema->{ASSESSMENT_CODES}{$entry->{$key}} or $logger->NIST_die("Unknown assessment code: $entry->{$key}");
    }

    $entry->{QUERY_UUID} = $entry->{QUERY}{UUID};
    $entry->{TARGET_UUID} = &main::uuid_generate($entry->{QUERY_ID}, $entry->{VALUE}, $entry->{VALUE_PROVENANCE}->tostring());
    $self->{TARGET_UUID_INDEX}{$entry->{TARGET_UUID}} = $entry if $entry->{TYPE} eq 'ASSESSMENT';

    push(@{$self->{ENTRIES}{$schema->{TYPE}}}, $entry);

    # Add the query corresponding to this entry to the set of queries
    $queries->add(&generate_round2_query($logger, $entry));
  }
  close $infile;
}

# Create a new EvaluationQueryOutput object
sub new {
  my ($class, $logger, $queries, @rawfilenames) = @_;
  $logger->NIST_die("$class->new called with no filenames") unless @rawfilenames;
  # Poor man's find
  my @filenames = map {-d $_ ? <$_/*.tab.txt> : $_} @rawfilenames;
  my $self = {QUERIES => $queries, RAW_FILENAMES => \@rawfilenames};
  bless($self, $class);
  foreach my $filename (@filenames) {
    my $type = &identify_file_type($logger, $filename);
    my $schema = $schemas{$type};
    unless ($schema) {
      $logger->record_problem('UNKNOWN_RESPONSE_FILE_TYPE', $type, 'NO_SOURCE');
      next;
    }
    $self->load($logger, $queries, $filename, $schema);
  }
  $self;
}

# Map a particular column entry to its string representation
sub column2string {
  my ($self, $entry, $schema, $column) = @_;
  if ($column =~ /^(.*)_TRIPLES$/) {
    my $provenance_column = $1;
    # NOTE: This outputs normalized provenance. That should be fine
    # for now, but might be a problem in the future.
    return $entry->{$provenance_column}->tostring();
  }
  elsif ($column eq 'RUNID') {
    return $self->{RUNID};
  }
  else {
    return $entry->{$column};
  }
}

# Convert this structure back to its proper printed representation
sub tostring {
  my ($self, $schema_name) = @_;
  $schema_name = '2014SFsubmissions' unless defined $schema_name;
  my $schema = $schemas{$schema_name};
  $self->{LOGGER}->NIST_die("Unknown file schema: $schema_name") unless $schema;
  my $string = "";
  foreach my $entry (@{$self->{ENTRIES}{$schema->{TYPE}}}) {
    $string .= join("\t", map {$self->column2string($entry, $schema, $_)} @{$schema->{COLUMNS}}) . "\n";
  }
  $string;
}

sub get_runid {
  my ($self) = @_;
  $self->{RUNID};
}

sub set_runid {
  my ($self, $new_runid) = @_;
  $self->{RUNID} = $new_runid;
}

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

# Hush up perl worrywart module
my $pattern = $main::comment_pattern;

sub generate_round1_query {
  my ($logger, $query) = @_;
  $query->put('SLOT', $query->get('SLOT0'));
  $query;
}

sub generate_round2_query {
  my ($logger, $submission) = @_;
  my $original_query = $submission->{QUERY};
  $logger->NIST_die("Query ID $submission->{QUERY_ID} not found") unless defined $original_query;
  my $new_queryid = "$submission->{QUERY_ID_BASE}_$submission->{TARGET_UUID}";
  my $new_query = Query->new($logger);
  $new_query->put('QUERY_ID', $new_queryid);
  $new_query->add_entrypoint(NAME => $submission->{VALUE},
			     PROVENANCE => $submission->{VALUE_PROVENANCE});
  foreach my $key (keys %{$original_query}) {
    $new_query->put($key, $original_query->get($key)) if $key =~ /^slot(\d+)$/i;
  }
  # FIXME: Should be generalized to multiple hops
  my $next_slot = $new_query->get('SLOT1');
  my ($next_slot_type) = $next_slot =~ /^(.*?):/;
  $new_query->put('SLOT', $next_slot);
  $new_query->put('ENTTYPE', $next_slot_type);
  $new_query;
}

sub generate_round1_queries {
  my ($logger, $queries) = @_;
  my $new_queries = QuerySet->new($logger);
  foreach my $query ($queries->get_all()) {
    $new_queries->add(&generate_round1_query($logger, $query));
  }
  $new_queries;
}  

sub generate_round2_queries {
  my ($logger, $round1_submissions) = @_;
  my $new_queries = QuerySet->new($logger);
  foreach my $submission (@{$round1_submissions->{ENTRIES}{SUBMISSION}}) {
    my $new_query = &generate_round2_query($logger, $submission);
    $new_queries->add($new_query);
  }
  $new_queries;
}

##################################################################################### 
# Runtime switches and main program
##################################################################################### 

# Handle run-time switches
my $switches = SwitchProcessor->new($0, "Generate a query file for a Cold Start Slot Filling variant submission. With two arguments, it updates the input queries with the <slot> field. With three arguments it generates a second round query file based on the first round slot filling output.",
				    "");
$switches->addHelpSwitch("help", "Show help");
$switches->addHelpSwitch("h", undef);
$switches->addVarSwitch('error_file', "Specify a file to which error output should be redirected");
$switches->put('error_file', "STDERR");
$switches->addVarSwitch('docs', "Tab-separated file containing docids and document lengths, measured in unnormalized Unicode characters");
$switches->addImmediateSwitch('version', sub { print "$0 version $version\n"; exit 0; }, "Print version number and exit");
$switches->addParam("queryfile", "required", "File containing queries used to generate the file being validated");
$switches->addParam("outputfile", "required", "File into which new queries are to be placed.");
$switches->addParam("runfile", "File containing query output. Omit to generate initial queries.");

$switches->process(@ARGV);

my $queryfile = $switches->get("queryfile");
my $outputfile = $switches->get("runfile");


my $logger = Logger->new();

# Allow redirection of stdout and stderr
my $output_filename = $switches->get("outputfile");
if (lc $output_filename eq 'stdout') {
  $program_output = *STDOUT{IO};
} elsif (lc $output_filename eq 'stderr') {
  $program_output = *STDERR{IO};
} else {
  open($program_output, ">:utf8", $output_filename) or $logger->NIST_die("Could not open $output_filename: $!");
}

my $error_filename = $switches->get("error_file");
if (lc $error_filename eq 'stdout') {
  $error_output = *STDOUT{IO};
}
elsif (lc $error_filename eq 'stderr') {
  $error_output = *STDERR{IO};
}
else {
  open($error_output, ">:utf8", $error_filename) or $logger->NIST_die("Could not open $error_filename: $!");
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
}

my $queries = QuerySet->new($logger, $queryfile);

# The input file to process
my $filename = $switches->get("runfile");

if (!defined $program_output && !defined $filename) {
  print $error_output "WARNING: to generate first round queries, you should use the -output_file switch\n\n";
}

if (defined $filename) {
  $logger->NIST_die("File $filename does not exist") unless -e $filename;
  my $sf_output = EvaluationQueryOutput->new($logger, $queries, $filename);

  # Problems were identified while the KB was loaded; now report them
  my ($num_errors, $num_warnings) = $logger->report_all_problems();
  if ($num_errors) {
    $logger->NIST_die("$num_errors error" . ($num_errors == 1 ? '' : 's') . " encountered");
  }
  my $new_queries = &generate_round2_queries($logger, $sf_output);
  print $program_output $new_queries->tostring() if defined $program_output;
  print $error_output ($num_warnings || 'No'), " warning", ($num_warnings == 1 ? '' : 's'), " encountered\n";
  exit 0;
}
else {
  my $new_queries = &generate_round1_queries($logger, $queries);
  print $program_output $new_queries->tostring() if defined $program_output;
  exit 0;
}


################################################################################
# Revision History
################################################################################

# 1.0 - Initial version
# 1.1 - Eliminated improperly included junk code
# 1.2 - Ensured all program exits are NIST-compliant
# 1.3 - Bug fixes
# 1.4 - Bug fixes

1;

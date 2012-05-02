package WebHACC::Language::WebVTT;
use strict;
use warnings;
require WebHACC::Language::Base;
push our @ISA, 'WebHACC::Language::Base';

sub new ($) {
  my $self = bless {}, shift;
  return $self;
} # new

sub generate_syntax_error_section ($) {
  my $self = shift;

  $self->result->layer_uncertain ('charset');

  my $out = $self->output;
  $out->start_section (role => 'parse-errors');
  $out->start_error_list (role => 'parse-errors');
  $self->result->layer_applicable ('syntax');

  my $input = $self->input;
  my $result = $self->result;

  $self->result->layer_uncertain ('encode')
      ;#unless $input->{is_char_string};

  require Whatpm::WebVTT::Parser;
  my $parser = Whatpm::WebVTT::Parser->new;
  $parser->onerror (sub {
    $result->add_error (@_, layer => 'syntax');
  });

  my $track;
  if ($input->{is_char_string}) {
    $track = $parser->parse_char_string ($input->{s});
  } else {
    $track = $parser->parse_byte_string ($input->{s});
  }
  $self->{structure} = $track;

  $out->end_error_list (role => 'parse-errors');
  $out->end_section;
} # generate_parse_error_section

sub generate_structure_dump_section ($) {
  my $self = shift;
  
  require Whatpm::WebVTT::Serializer;
  my $out = $self->output;

  $out->start_section (role => 'reformatted');

  $out->start_code_block;
  $out->text (Whatpm::WebVTT::Serializer->track_to_char_string
                  ($self->{structure}));
  $out->end_code_block;

  $out->end_section
} # generate_structure_dump_section

sub generate_structure_error_section ($) {
  my $self = shift;

  my $out = $self->output;
  
  $out->start_section (role => 'structure-errors');
  $out->start_error_list (role => 'structure-errors');
  $self->result->layer_applicable ('structure');

  require Whatpm::WebVTT::Checker;
  my $checker = Whatpm::WebVTT::Checker->new;
  $checker->onerror (sub {
    $self->result->add_error (@_, layer => 'structure');
  });

  $checker->check_track ($self->{structure});
  
  $out->end_error_list (role => 'structure-errors');
  $out->end_section;
} # generate_structure_error_section

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

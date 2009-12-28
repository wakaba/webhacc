package WebHACC::Language::WebIDL;
use strict;
require WebHACC::Language::Base;
push our @ISA, 'WebHACC::Language::Base';

sub new ($) {
  my $self = bless {}, shift;
  return $self;
} # new

sub generate_syntax_error_section ($) {
  my $self = shift;

  require Whatpm::WebIDL;

  $self->result->layer_uncertain ('charset');

  my $out = $self->output;
  $out->start_section (role => 'parse-errors');
  $out->start_error_list (role => 'parse-errors');
  $self->result->layer_applicable ('syntax');

  my $input = $self->input;
  my $result = $self->result;

  $self->result->layer_uncertain ('encode') unless $input->{is_char_string};

  require Encode;
  my $s = $input->{is_char_string} ? $input->{s} : Encode::decode ($input->{charset} || 'utf-8', $input->{s}); ## TODO: charset
  my $parser = Whatpm::WebIDL::Parser->new;

  $self->{structure} = $parser->parse_char_string ($input->{s}, sub {
    $result->add_error (@_, layer => 'syntax');
  });

  $out->end_error_list (role => 'parse-errors');
  $out->end_section;
} # generate_parse_error_section

sub generate_structure_dump_section ($) {
  my $self = shift;
  
  my $out = $self->output;

  $out->start_section (role => 'reformatted');

  $out->start_code_block;
  $out->text ($self->{structure}->idl_text);
  $out->end_code_block;

  $out->end_section
} # generate_structure_dump_section

sub generate_structure_error_section ($) {
  my $self = shift;

  my $out = $self->output;
  
  $out->start_section (role => 'structure-errors');
  $out->start_error_list (role => 'structure-errors');
  $self->result->layer_applicable ('structure');

  $self->{structure}->check (sub {
    $self->result->add_error (@_, layer => 'structure');
  });
  
  $out->end_error_list (role => 'structure-errors');
  $out->end_section;
} # generate_structure_error_section

1;

package WebHACC::Language::Default;
use strict;
require WebHACC::Language::Base;
push our @ISA, 'WebHACC::Language::Base';

sub new ($) {
  my $self = bless {}, shift;
  return $self;
} # new

sub generate_syntax_error_section ($) {
  my $self = shift;

  my $out = $self->output;

  $out->start_section (id => 'parse-errors', title => 'Errors');
  $out->start_tag ('dl');

  $self->result->add_error (input => $self->input,
                            level => 'u',
                            layer => 'syntax',
                            type => 'media type not supported',
                            text => $self->input->{media_type});

  $out->end_tag ('dl');
  $out->end_section;
} # generate_syntax_error_section

sub generate_source_string_section ($) { }

sub generate_structure_error_section ($) { }

1;

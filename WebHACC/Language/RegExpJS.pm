package WebHACC::Language::RegExpJS;
use strict;
require WebHACC::Language::Base;
push our @ISA, 'WebHACC::Language::Base';

sub new ($) {
  my $self = bless {}, shift;
  return $self;
} # new

sub generate_syntax_error_section ($) {
  my $self = shift;

  require Regexp::Parser::JavaScript;

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
  my $parser = Regexp::Parser::JavaScript->new;

  $parser->onerror (sub {
    my %opt = @_;
    
    if ($opt{code} == [$parser->RPe_BADESC]->[0]) {
      $opt{type} =~ s{%s%s}{
        '%s' . (defined $opt{args}->[1] ? $opt{args}->[1] : '')
      }e;
    } elsif ($opt{code} == [$parser->RPe_FRANGE]->[0] or
             $opt{code} == [$parser->RPe_IRANGE]->[0]) {
      $opt{text} = $opt{args}->[0] . '-';
      $opt{text} .= $opt{args}->[1] if defined $opt{args}->[1];
    } elsif ($opt{code} == [$parser->RPe_BADFLG]->[0]) {
      ## NOTE: Not used by JavaScript regexp parser in fact.
      $opt{text} = $opt{args}->[0] . $opt{args}->[1];
    } else {
      $opt{text} = $opt{args}->[0];
    }

    $result->add_error (%opt, layer => 'syntax');
  });

  eval {
    $parser->parse ($s);
  };

  $self->{structure} = $parser;

  $out->end_error_list (role => 'parse-errors');
  $out->end_section;
} # generate_parse_error_section

sub generate_structure_dump_section ($) { }

sub generate_structure_error_section ($) { }

1;

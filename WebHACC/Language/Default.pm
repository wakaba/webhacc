package WebHACC::Language::Default;
use strict;
require WebHACC::Language::Base;
push our @ISA, 'WebHACC::Language::Base';

sub new ($) {
  my $self = bless {}, shift;
  return $self;
} # new

sub generate_parse_error_section ($) {
  my $self = shift;

  my $out = shift;

  $out->start_section (id => 'parse-errors', title => 'Errors');
  $out->start_tag ('dl');

  ## TODO:
  $out->start_tag ('dt', class => 'unsupported');
  $out->url ($input->{uri});
  $out->html (q[<dd class=unsupported><strong><a href="../error-description#level-u">Not
        supported</a></strong>:
    Media type
    <code class="MIME" lang="en">]);
  $out->text ($input->{media_type});
  $out->html (q[</code> is not supported.]);
  $out->end_tag ('dl');
  $out->end_section;

  my $result = $self->result;

  add_error (char => {level => 'u'} => $result);
  add_error (syntax => {level => 'u'} => $result);
  add_error (structure => {level => 'u'} => $result);
} # generate_parse_error_section

sub generate_structure_error_section ($) { }

1;

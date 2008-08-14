package WebHACC::Language::CacheManifest;
use strict;
require WebHACC::Language::Base;
push our @ISA, 'WebHACC::Language::Base';

sub new ($) {
  my $self = bless {}, shift;
  return $self;
} # new

sub generate_syntax_error_section ($) {
  my $self = shift;

  require Whatpm::CacheManifest;

  my $out = $self->output;

  $self->result->layer_uncertain ('encode');
  $self->result->layer_uncertain ('charset');

  $out->start_section (role => 'parse-errors');
  $out->start_error_list (role => 'parse-errors');
  $self->result->layer_applicable ('syntax');

  my $input = $self->input;
  my $result = $self->result;

  my $m = $input->{is_char_string} ? 'parse_char_string' : 'parse_byte_string';
  $self->{structure} = Whatpm::CacheManifest->$m
      ($input->{s}, $input->{uri}, $input->{base_uri}, sub {
        $result->add_error (@_, layer => 'syntax', index_has_link => 1);
      });
       
  $out->end_error_list (role => 'parse-errors');
  $out->end_section;
} # generate_syntax_error_section

sub generate_structure_dump_section ($) {
  my $self = shift;
  my $manifest = $self->{structure};

  my $out = $self->output;

  $out->start_section (role => 'structure');

  $out->html (qq[<dl><dt>Explicit entries</dt>]);
  my $i = 0;
  for my $uri (@{$manifest->[0]}) {
    $out->start_tag ('dd', id => 'index-' . $i++);
    $out->url ($uri);
  }

  $out->html (qq[<dt>Fallback entries</dt><dd>
      <table><thead><tr><th scope=row>Oppotunistic Caching Namespace</th>
      <th scope=row>Fallback Entry</tr><tbody>]);
  for my $uri (sort {$a cmp $b} keys %{$manifest->[1]}) {
    $out->start_tag ('tr');

    $out->start_tag ('td', id => 'index-' . $i++);
    $out->url ($uri);

    $out->start_tag ('td', id => 'index-' . $i++);
    $out->url ($manifest->[1]->{$uri});
  }

  $out->html (qq[</table><dt>Online whitelist</dt>]);
  for my $uri (@{$manifest->[2]}) {
    $out->start_tag ('dd', id => 'index-' . $i++);
    $out->url ($uri);
  }

  $out->end_section;
} # generate_structure_dump_section

sub generate_structure_error_section ($) {
  my $self = shift;

  my $out = $self->output;

  $out->start_section (role => 'structure-errors');
  $out->start_error_list (role => 'structure-errors');
  $self->result->layer_applicable ('structure');

  my $result = $self->result;

  Whatpm::CacheManifest->check_manifest ($self->{structure}, sub {
    $result->add_error (@_, layer => 'structure');
  });

  $out->end_error_list;
  $out->end_section;
} # generate_structure_error_section

sub source_charset ($) {
  return 'utf-8';
} # source_charset

1;

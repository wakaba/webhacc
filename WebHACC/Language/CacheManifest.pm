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

  $self->result->layer_uncertain ('charset');

  $out->start_section (role => 'parse-errors');
  $out->start_error_list (role => 'parse-errors');
  $self->result->layer_applicable ('syntax');

  my $input = $self->input;
  my $result = $self->result;

  $self->result->layer_uncertain ('encode') unless $input->{is_char_string};

  my $m = $input->{is_char_string} ? 'parse_char_string' : 'parse_byte_string';
  $self->{structure} = Whatpm::CacheManifest->$m
      ($input->{s}, $input->url, $input->{base_uri}, sub {
        $result->add_error (@_, layer => 'syntax', index_has_link => 1);
      });
       
  $out->end_error_list (role => 'parse-errors');
  $out->end_section;
} # generate_syntax_error_section

sub generate_structure_dump_section ($) {
  my $self = shift;
  my $manifest = $self->{structure} || [[], {}, []]; # undef if it is not a manifest.

  my $out = $self->output;

  $out->start_section (role => 'structure');

  $out->start_tag ('dl');
  my $i = 0;

  $out->start_tag ('dt');
  $out->nl_text ('Explicit entries');
  if (@{$manifest->[0]}) {
    for my $uri (@{$manifest->[0]}) {
      $out->start_tag ('dd', id => 'index-' . $i++);
      $out->url ($uri);
    }
  } else {
    $out->start_tag ('dd', class => 'no-entry');
    $out->nl_text ('No entry');
  }

  $out->start_tag ('dt');
  $out->nl_text ('Fallback entries');
  if (keys %{$manifest->[1]}) {
    $out->start_tag ('dd', class => 'manifest-fallbacks');
    for my $uri (sort {$a cmp $b} keys %{$manifest->[1]}) {
      $out->start_tag ('p', id => 'index-' . $i++);
      $out->nl_text ('Opportunistic caching namespace');
      $out->text (': ');
      $out->url ($uri);
      
      $out->start_tag ('p', id => 'index-' . $i++);
      $out->nl_text ('Fallback entry');
      $out->text (': ');
      $out->url ($manifest->[1]->{$uri});
    }
  } else {
    $out->start_tag ('dd', class => 'no-entry');
    $out->nl_text ('No entry');
  }

  $out->start_tag ('dt');
  $out->nl_text ('Online whitelist');
  if (@{$manifest->[2]}) {
    for my $uri (@{$manifest->[2]}) {
      $out->start_tag ('dd', id => 'index-' . $i++);
      $out->url ($uri);
    }
  } else {
    $out->start_tag ('dd', class => 'no-entry');
    $out->nl_text ('No entry');
  }

  $out->end_tag ('dl');

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

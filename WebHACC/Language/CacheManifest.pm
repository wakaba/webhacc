package WebHACC::Language::CacheManifest;
use strict;
require WebHACC::Language::Base;
push our @ISA, 'WebHACC::Langauge::Base';

sub new ($) {
  my $self = bless {}, shift;
  return $self;
} # new

sub generate_syntax_error_section ($) {
  my $self = shift;

  require Whatpm::CacheManifest;

  my $out = $self->output;

  $out->start_section (id => 'parse-errors', title => 'Parse Errors');
  $out->start_tag ('dl', id => 'parse-errors-list');

  my $input = $self->input;
  my $result = $self->result;

  my $onerror = sub {
    my (%opt) = @_;
    my ($type, $cls, $msg) = get_text ($opt{type}, $opt{level});
    $out->html (qq[<dt class="$cls">], get_error_label ($input, \%opt));
    $type =~ tr/ /-/;
    $type =~ s/\|/%7C/g;
    $msg .= qq[ [<a href="../error-description#@{[htescape ($type)]}">Description</a>]];
    $out->html (qq[<dd class="$cls">], get_error_level_label (\%opt) . $msg);

    add_error ('syntax', \%opt => $result);
  };

  my $m = $input->{is_char_string} ? 'parse_char_string' : 'parse_byte_string';
  $self->{structure} = Whatpm::CacheManifest->$m
      ($input->{s}, $input->{uri}, $input->{base_uri}, $onerror);

  $out->end_tag ('dl');
  $out->end_section;
} # generate_syntax_error_section

sub generate_structure_dump_section ($) {
  my $self = shift;
  my $manifest = $self->{structure};

  $self->start_section (id => 'dump-manifest', title => 'Cache Manifest');

  $self->html (qq[<dl><dt>Explicit entries</dt>]);
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

  $out->start_section (id => 'document-errors', title => 'Document Errors');
  $out->start_tag ('dl');

  my $result = $out->result;

  Whatpm::CacheManifest->check_manifest ($self->{structure}, sub {
    my %opt = @_;
    my ($type, $cls, $msg) = get_text ($opt{type}, $opt{level}, $opt{node});
    $type =~ tr/ /-/;
    $type =~ s/\|/%7C/g;
    $msg .= qq[ [<a href="../error-description#@{[htescape ($type)]}">Description</a>]];
    $out->html (qq[<dt class="$cls">] . get_error_label ($input, \%opt) .
        qq[</dt>\n<dd class="$cls">], $msg, "</dd>\n");
    add_error ('structure', \%opt => $result);
  });

  $out->end_section;
} # generate_structure_error_section

sub source_charset ($) {
  return 'utf-8';
} # source_charset

1;

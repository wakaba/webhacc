package WebHACC::Input;
use strict;

sub new ($) {
  return bless {}, shift;
} # new

sub id_prefix ($) { '' }

sub nested ($) { 0 }

sub subdocument_index ($) { 0 }

sub full_subdocument_index ($) { 0 }

sub generate_info_section ($$) {
  my $self = shift;
  
  my $result = shift;
  my $out = $result->output;

  $out->start_section (id => 'document-info', title => 'Information');
  $out->start_tag ('dl');

  $out->dt ('Request URL');
  $out->start_tag ('dd');
  $out->url ($self->{request_uri});

  $out->dt ('Document URL'); ## TODO: HTML5 "document's address"?
  $out->start_tag ('dd');
  $out->url ($self->{uri}, id => 'anchor-document-url');
  $out->script (q[
      document.title = '<'
          + document.getElementById ('anchor-document-url').href + '> \\u2014 '
          + document.title;
  ]);

  if (defined $self->{s}) {
    $out->dt ('Base URL');
    $out->start_tag ('dd');
    $out->url ($self->{base_uri});
    
    $out->dt ('Internet Media Type');
    $out->start_tag ('dd');
    $out->code ($self->{media_type}, class => 'MIME', lang => 'en');
    if ($self->{media_type_overridden}) {
      $out->nl_text ('... overridden');
    } elsif (defined $self->{official_type}) {
      if ($self->{media_type} eq $self->{official_type}) {
        #
      } else {
        $out->nl_text ('... sniffed, official type is #',
                       text => $self->{official_type});
      }
    } else {
      $out->nl_text ( '... sniffed');
    }

    $out->dt ('Character Encoding');
    $out->start_tag ('dd');
    if (defined $self->{charset}) {
      $out->code ($self->{charset}, class => 'charset', lang => 'en');
    } else {
      $out->nl_text ('(unknown)');
    }
    $out->nl_text ('... overridden') if $self->{charset_overridden};

    $out->dt ($self->{is_char_string} ? 'Character Length' : 'Byte Length');
    ## TODO: formatting
    $out->start_tag ('dd');
    my $length = length $self->{s};
    $out->text ($length . ' ');
    $out->nl_text (($self->{is_char_string} ? 'character' : 'byte') .
                   ($length == 1 ? '' : 's'));
  }

  $out->end_tag ('dl');
  $out->end_section;
} # generate_info_section

sub generate_transfer_sections ($$) {
  my $self = shift;
  my $result = shift;
  
  $self->generate_http_header_section ($result);
} # generate_transfer_sections

sub generate_http_header_section ($$) {
  my ($self, $result) = @_;
  
  return unless defined $self->{header_status_code} or
      defined $self->{header_status_text} or
      @{$self->{header_field} or []};

  my $out = $result->output;
  
  $out->start_section (id => 'source-header', title => 'HTTP Header');
  $out->html (qq[<p><strong>Note</strong>: Due to the limitation of the
network library in use, the content of this section might
not be the real header.</p>

<table><tbody>
]);

  if (defined $self->{header_status_code}) {
    $out->html (qq[<tr><th scope="row">Status code</th>]);
    $out->start_tag ('td');
    $out->code ($self->{header_status_code});
  }
  if (defined $self->{header_status_text}) {
    $out->html (qq[<tr><th scope="row">Status text</th>]);
    $out->start_tag ('td');
    $out->code ($self->{header_status_text});
  }
  
  for (@{$self->{header_field}}) {
    $out->start_tag ('tr');
    $out->start_tag ('th', scope => 'row');
    $out->code ($_->[0]);
    $out->start_tag ('td');
    $out->code ($_->[1]);
  }

  $out->end_tag ('table');

  $out->end_section;
} # generate_http_header_section

package WebHACC::Input::Subdocument;
push our @ISA, 'WebHACC::Input';

sub new ($$) {
  my $self = bless {}, shift;
  $self->{subdocument_index} = shift;
  return $self;
} # new

sub id_prefix ($) {
  return 'subdoc-' . shift->full_subdocument_index . '-';
} # id_prefix

sub nested ($) { 1 }

sub subdocument_index ($) {
  return shift->{subdocument_index};
} # subdocument_index

sub full_subdocument_index ($) {
  my $self = shift;
  my $parent = $self->{parent_input}->full_subdocument_index;
  if ($parent) {
    return $parent . '.' . $self->{subdocument_index};
  } else {
    return $self->{subdocument_index};
  }
} # full_subdocument_index

sub start_section ($$) {
  my $self = shift;

  my $result = shift;
  my $out = $result->output;

  my $index = $self->full_subdocument_index;
  $out->start_section (id => $self->id_prefix,
                       title => qq[Subdocument #],
                       short_title => 'Sub #',
                       text => $index);
} # start_section

sub end_section ($$) {
  $_[1]->output->end_section;
} # end_section

sub generate_info_section ($$) {
  my $self = shift;

  my $result = shift;
  my $out = $result->output;

  $out->start_section (id => 'document-info', title => 'Information');
  $out->start_tag ('dl');

  $out->dt ('Internet Media Type');
  $out->start_tag ('dd');
  $out->code ($self->{media_type}, code => 'MIME', lang => 'en');

  if (defined $self->{container_node}) {
    $out->dt ('Container Node');
    $out->start_tag ('dd');
    my $original_input = $out->input;
    $out->input ($self->{parent_input});
    $out->node_link ($self->{container_node});
    $out->input ($original_input);
  }

  $out->dt ('Base URL');
  $out->start_tag ('dd');
  $out->url ($self->{base_uri});

  $out->end_tag ('dl');
  $out->end_section;
} # generate_info_section

package WebHACC::Input::Error;
push our @ISA, 'WebHACC::Input';

sub generate_transfer_sections ($$) {
  my $self = shift;

  $self->SUPER::generate_transfer_sections (@_);
  
  my $result = shift;
  my $out = $result->output;

  $out->start_section (id => 'transfer-errors', title => 'Transfer Errors');

  $out->start_tag ('dl');
  $result->add_error (layer => 'transfer',
                      level => 'u',
                      type => 'resource retrieval error',
                      url => $self->{request_uri},
                      text => $self->{error_status_text});
  $out->end_tag ('dl');

  $out->end_section;
} # generate_transfer_sections

1;

package WebHACC::Input;
use strict;

sub new ($) {
  return bless {id_prefix => ''}, shift;
} # new

sub id_prefix ($;$) {
  if (@_ > 1) {
    if (defined $_[1]) {
      $_[0]->{id_prefix} = ''.$_[1];
    } else {
      $_[0]->{id_prefix} = '';
    }
  }

  return $_[0]->{id_prefix};
} # id_prefix

sub nested ($;$) {
  if (@_ > 1) {
    if ($_[1]) {
      $_[0]->{nested} = 1;
    } else {
      delete $_[0]->{nested};
    }
  }

  return $_[0]->{nested};
} # nested

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

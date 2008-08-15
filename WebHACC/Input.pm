package WebHACC::Input;
use strict;

sub new ($) {
  return bless {urls => []}, shift;
} # new

sub id_prefix ($) { '' }

sub nested ($) { 0 }

sub subdocument_index ($) { 0 }

sub full_subdocument_index ($) { 0 }

sub url ($) {
  my $self = shift;
  if (@{$self->{urls}}) {
    return $self->{urls}->[-1];
  } else {
    return undef;
  }
} # url

sub add_url ($$) {
  my ($self, $url) = @_;
  push @{$self->{urls}}, ''.$url;
} # add_url

sub urls ($) {
  my $self = shift;
  return [@{$self->{urls}}];
} # urls

sub get_document ($$$$) {
  my $self = shift->new;

  my ($cgi => $result => $out) = @_;

  $out->input ($self);

  require Encode;
  my $url_s = Encode::decode ('utf-8', $cgi->get_parameter ('uri'));
  my $url_o;
  if (defined $url_s and length $url_s) {
    require Message::DOM::DOMImplementation;
    my $dom = Message::DOM::DOMImplementation->new;
    
    $url_o = $dom->create_uri_reference ($url_s);
    $url_o->uri_fragment (undef);

    $self->add_url ($url_o->uri_reference);

    my $url_scheme = lc $url_o->uri_scheme; ## TODO: html5_url_scheme
    my $class = {
      http => 'WebHACC::Input::HTTP',
    }->{$url_scheme} || 'WebHACC::Input::UnsupportedURLSchemeError';
    bless $self, $class;
  } else {
    bless $self, 'WebHACC::Input::Text';
  }

  $self->_get_document ($cgi => $result => $out, $url_o);

  return $self unless defined $self->{s};

  if (length $self->{s} > 1000_000) {
    $self->{error_status_text} = 'Entity-body too large';
    delete $self->{s};
    bless $self, 'WebHACC::Input::Error';
    return $self;
  }

  require Whatpm::ContentType;
  ($self->{official_type}, $self->{media_type})
        = Whatpm::ContentType->get_sniffed_type
            (get_file_head => sub {
               return substr $self->{s}, 0, shift;
             },
             http_content_type_byte => $self->{http_content_type_bytes},
             supported_image_types => {});

  my $input_format = $cgi->get_parameter ('i');
  if (defined $input_format and length $input_format) {
    $self->{media_type_overridden}
        = (not defined $self->{media_type} or
           $input_format ne $self->{media_type});
    $self->{media_type} = $input_format;
  }
  if (defined $self->{s} and not defined $self->{media_type}) {
    $self->{media_type} = 'text/html';
    $self->{media_type_overridden} = 1;
  }

  if ($self->{media_type} eq 'text/xml') {
    unless (defined $self->{charset}) {
      $self->{charset} = 'us-ascii';
      $self->{official_charset} = $self->{charset};
    } elsif ($self->{charset_overridden} and $self->{charset} eq 'us-ascii') {
      $self->{charset_overridden} = 0;
    }
  }

  $self->{inner_html_element} = $cgi->get_parameter ('e');

  return $self;
} # get_document

sub _get_document ($$$$) {
  die "$0: _get_document of " . ref $_[0];
} # _get_document

sub generate_info_section ($$) {
  my $self = shift;
  
  my $result = shift;
  my $out = $result->output;

  $out->start_section (id => 'document-info', title => 'Information');
  $out->start_tag ('dl');

  my $urls = $self->urls;

  $out->dt (@$urls == 1 ? 'URL' : 'URLs');
  my $url = pop @$urls;
  for (@$urls) {
    $out->start_tag ('dd');
    $out->url ($_);
  }
  $out->start_tag ('dd');
  $out->url ($url, id => 'anchor-document-url');
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

sub generate_transfer_sections ($$) { }

package WebHACC::Input::HTTP;
push our @ISA, 'WebHACC::Input';

{
my $HostPermit;
sub host_permit ($) {
  return $HostPermit if $HostPermit;
  
  require Message::Util::HostPermit;
  $HostPermit = new Message::Util::HostPermit;
  $HostPermit->add_rule (<<'EOH');
Allow host=suika port=80
Deny host=suika
Allow host=suika.fam.cx port=80
Deny host=suika.fam.cx
Deny host=localhost
Deny host=*.localdomain
Deny ipv4=0.0.0.0/8
Deny ipv4=10.0.0.0/8
Deny ipv4=127.0.0.0/8
Deny ipv4=169.254.0.0/16
Deny ipv4=172.0.0.0/11
Deny ipv4=192.0.2.0/24
Deny ipv4=192.88.99.0/24
Deny ipv4=192.168.0.0/16
Deny ipv4=198.18.0.0/15
Deny ipv4=224.0.0.0/4
Deny ipv4=255.255.255.255/32
Deny ipv6=0::0/0
Allow host=*
EOH
  return $HostPermit;
} # host_permit
}

sub _get_document ($$$$$) {
  my ($self, $cgi => $result => $out, $url_o) = @_;

  unless ($self->host_permit->check ($url_o->uri_host, $url_o->uri_port || 80)) {
    $self->{error_status_text} = 'Connection to the host is forbidden';
    bless $self, 'WebHACC::Input::Error';
    return $self;
  }

  my $ua = WDCC::LWPUA->new;
  $ua->{wdcc_dom} = Message::DOM::DOMImplementation->new;
  $ua->{wdcc_host_permit} = $self->host_permit;
  $ua->agent ('Mozilla'); ## TODO: for now.
  $ua->parse_head (0);
  $ua->protocols_allowed ([qw/http/]);
  $ua->max_size (1000_000);
  my $req = HTTP::Request->new (GET => $url_o->uri_reference);
  $req->header ('Accept-Encoding' => 'identity, *; q=0');
  my $res = $ua->request ($req);
  ## TODO: 401 sets |is_success| true.
  ## TODO: Don't follow redirect if error-page=true
  if ($res->is_success or $cgi->get_parameter ('error-page')) {
    $self->{base_uri} = $res->base; ## NOTE: It does check |Content-Base|, |Content-Location|, and <base>. ## TODO: Use our own code!
    my $new_url = $res->request->uri;
    $self->add_url ($new_url) if $new_url ne $self->url;
    
    ## TODO: More strict parsing...
    my $ct = $self->{http_content_type_bytes} = $res->header ('Content-Type');
    if (defined $ct and $ct =~ /;\s*charset\s*=\s*"?([^\s;"]+)"?/i) {
      $self->{charset} = lc $1;
      $self->{charset} =~ tr/\\//d;
      $self->{official_charset} = $self->{charset};
    }
    
    my $input_charset = $cgi->get_parameter ('charset');
    if (defined $input_charset and length $input_charset) {
      $self->{charset_overridden}
          = (not defined $self->{charset} or $self->{charset} ne $input_charset);
      $self->{charset} = $input_charset;
    }

    ## TODO: Support for HTTP Content-Encoding
    
    $self->{s} = ''.$res->content;
  } else {
    $self->add_url ($res->request->uri);
    $self->{error_status_text} = $res->status_line;
    bless $self, 'WebHACC::Input::HTTPError';
  }
               
  $self->{header_field} = [];
  $res->scan (sub {
    push @{$self->{header_field}}, [$_[0], $_[1]];
  });
  $self->{header_status_code} = $res->code;
  $self->{header_status_text} = $res->message;

  return $self;
} # _get_document

sub generate_transfer_sections ($$) {
  my $self = shift;
  my $result = shift;

  $result->layer_uncertain ('transfer');
  
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

package WebHACC::Input::Text;
push our @ISA, 'WebHACC::Input';

sub _get_document ($$$$) {
  my ($self, $cgi => $result => $out) = @_;
  
  $self->add_url (q<thismessage:/>);
  $self->{base_uri} = q<thismessage:/>;
    
  $self->{s} = ''.$cgi->get_parameter ('s');
  $self->{charset} = ''.$cgi->get_parameter ('_charset_');
  $self->{charset} =~ s/\s+//g;
  $self->{charset} = 'utf-8' if $self->{charset} eq '';
  $self->{official_charset} = $self->{charset};
  $self->{header_field} = [];

  return $self;
} # _get_document

package WebHACC::Input::Subdocument;
push our @ISA, 'WebHACC::Input';

sub new ($$) {
  my $self = bless {}, shift;
  $self->{subdocument_index} = shift;
  return $self;
} # new

sub id_prefix ($) {
  my $self = shift;
  return $self->{parent_input}->id_prefix .
      'subdoc-' . $self->{subdocument_index} . '-';
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

  my $index = $self->subdocument_index;
  $out->start_section (id => my $id = 'subdoc-' . $index . '-',
                       title => qq[Subdocument #],
                       short_title => 'Sub #',
                       role => 'subdoc',
                       text => $self->full_subdocument_index);
  $out->script (q[ insertNavSections ('] . $out->input->id_prefix . $id . q[') ]);
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
  
  my $result = shift;
  my $out = $result->output;

  $out->start_section (role => 'transfer-errors');
  $out->start_error_list (role => 'transfer-errors');

  $result->layer_applicable ('transfer');
  $result->add_error (layer => 'transfer',
                      level => 'u',
                      type => 'resource retrieval error',
                      url => $self->{request_uri},
                      text => $self->{error_status_text});

  $out->end_error_list (role => 'transfer-errors');
  $out->end_section;
} # generate_transfer_sections

package WebHACC::Input::HTTPError;
push our @ISA, 'WebHACC::Input::Error', 'WebHACC::Input::HTTP';

sub generate_transfer_sections ($$) {
  my $self = shift;
  
  my $result = shift;

  $self->WebHACC::Input::Error::generate_transfer_sections ($result);
  $self->WebHACC::Input::HTTP::generate_transfer_sections ($result);

} # generate_transfer_sections

package WebHACC::Input::UnsupportedURLSchemeError;
push our @ISA, 'WebHACC::Input::Error';

sub _get_document ($$$$) {
  my ($self, $cgi => $result => $out) = @_;
  
  $self->{error_status_text} = 'URL scheme not allowed';

  return $self;
} # _get_document

package WDCC::LWPUA;
require LWP::UserAgent;
push our @ISA, 'LWP::UserAgent';

sub redirect_ok {
  my $ua = shift;
  unless ($ua->SUPER::redirect_ok (@_)) {
    return 0;
  }

  my $uris = $_[1]->header ('Location');
  return 0 unless $uris;
  my $uri = $ua->{wdcc_dom}->create_uri_reference ($uris);
  unless ({
           http => 1,
          }->{lc $uri->uri_scheme}) { ## TODO: html5_url_scheme
    return 0;
  }
  unless ($ua->{wdcc_host_permit}->check ($uri->uri_host, $uri->uri_port || 80)) {
    return 0;
  }
  return 1;
} # redirect_ok

1;

#!/usr/bin/perl
use strict;
use utf8;

use lib qw[/home/httpd/html/www/markup/html/whatpm
           /home/wakaba/work/manakai2/lib];
use CGI::Carp qw[fatalsToBrowser];
use Scalar::Util qw[refaddr];

  require WebHACC::Input;
  require WebHACC::Result;
  require WebHACC::Output;

my $out;

  require Message::DOM::DOMImplementation;
  my $dom = Message::DOM::DOMImplementation->new;
{
  use Message::CGI::HTTP;
  my $http = Message::CGI::HTTP->new;

  if ($http->get_meta_variable ('PATH_INFO') ne '/') {
    print STDOUT "Status: 404 Not Found\nContent-Type: text/plain; charset=us-ascii\n\n400";
    exit;
  }
  
  load_text_catalog ('en'); ## TODO: conneg

  $out = WebHACC::Output->new;
  $out->handle (*STDOUT);
  $out->set_utf8;
  $out->set_flush;
  $out->html (qq[Content-Type: text/html; charset=utf-8

<!DOCTYPE html>
<html lang="en">
<head>
<title>Web Document Conformance Checker (BETA)</title>
<link rel="stylesheet" href="../cc-style.css" type="text/css">
</head>
<body>
<h1><a href="../cc-interface">Web Document Conformance Checker</a> 
(<em>beta</em>)</h1>
]);

  my $input = get_input_document ($http, $dom);

  $out->input ($input);
  $out->unset_flush;

  my $result = WebHACC::Result->new;
  $result->output ($out);
  $result->{conforming_min} = 1;
  $result->{conforming_max} = 1;

  $out->html ('<script src="../cc-script.js"></script>');

  check_and_print ($input => $result => $out);
  
  $result->generate_result_section;

  $out->nav_list;

  exit;
}

sub check_and_print ($$$) {
  my ($input, $result, $out) = @_;
  my $original_input = $out->input;
  $out->input ($input);

  $input->generate_info_section ($result);

  $input->generate_transfer_sections ($result);

  unless (defined $input->{s}) {
    $result->{conforming_min} = 0;
    return;
  }

  my $checker_class = {
    'text/cache-manifest' => 'WebHACC::Language::CacheManifest',
    'text/css' => 'WebHACC::Language::CSS',
    'text/html' => 'WebHACC::Language::HTML',
    'text/x-webidl' => 'WebHACC::Language::WebIDL',

    'text/xml' => 'WebHACC::Language::XML',
    'application/atom+xml' => 'WebHACC::Language::XML',
    'application/rss+xml' => 'WebHACC::Language::XML',
    'image/svg+xml' => 'WebHACC::Language::XML',
    'application/xhtml+xml' => 'WebHACC::Language::XML',
    'application/xml' => 'WebHACC::Language::XML',
    ## TODO: Should we make all XML MIME Types fall
    ## into this category?

    ## NOTE: This type has different model from normal XML types.
    'application/rdf+xml' => 'WebHACC::Language::XML',
  }->{$input->{media_type}} || 'WebHACC::Language::Default';

  eval qq{ require $checker_class } or die "$0: Loading $checker_class: $@";
  my $checker = $checker_class->new;
  $checker->input ($input);
  $checker->output ($out);
  $checker->result ($result);

  ## TODO: A cache manifest MUST be text/cache-manifest
  ## TODO: WebIDL media type "text/x-webidl"

  $checker->generate_syntax_error_section;
  $checker->generate_source_string_section;

  my @subdoc;
  $checker->onsubdoc (sub {
    push @subdoc, shift;
  });

  $checker->generate_structure_dump_section;
  $checker->generate_structure_error_section;
  $checker->generate_additional_sections;

=pod

  if (defined $doc or defined $el) {

    print_table_section ($input, $elements->{table}) if @{$elements->{table}};
    print_listing_section ({
      id => 'identifiers', label => 'IDs', heading => 'Identifiers',
    }, $input, $elements->{id}) if keys %{$elements->{id}};
    print_listing_section ({
      id => 'terms', label => 'Terms', heading => 'Terms',
    }, $input, $elements->{term}) if keys %{$elements->{term}};
    print_listing_section ({
      id => 'classes', label => 'Classes', heading => 'Classes',
    }, $input, $elements->{class}) if keys %{$elements->{class}};
   
    print_rdf_section ($input, $elements->{rdf}) if @{$elements->{rdf}};
  }

=cut

  my $id_prefix = 0;
  for my $_subinput (@subdoc) {
    my $subinput = WebHACC::Input::Subdocument->new (++$id_prefix);
    $subinput->{$_} = $_subinput->{$_} for keys %$_subinput;
    $subinput->{base_uri} = $subinput->{container_node}->base_uri
        unless defined $subinput->{base_uri};
    $subinput->{parent_input} = $input;

    $subinput->start_section ($result);
    check_and_print ($subinput => $result => $out);
    $subinput->end_section ($result);
  }

  $out->input ($original_input);
} # check_and_print

sub print_table_section ($$) {
  my ($input, $tables) = @_;
  
#  push @nav, [qq[#$input->{id_prefix}tables] => 'Tables']
#      unless $input->{nested};
  print STDOUT qq[
<div id="$input->{id_prefix}tables" class="section">
<h2>Tables</h2>

<!--[if IE]><script type="text/javascript" src="../excanvas.js"></script><![endif]-->
<script src="../table-script.js" type="text/javascript"></script>
<noscript>
<p><em>Structure of tables are visualized here if scripting is enabled.</em></p>
</noscript>
];
  
  require JSON;
  
  my $i = 0;
  for my $table (@$tables) {
    $i++;
    print STDOUT qq[<div class="section" id="$input->{id_prefix}table-$i"><h3>] .
        get_node_link ($input, $table->{element}) . q[</h3>];

    delete $table->{element};

    for (@{$table->{column_group}}, @{$table->{column}}, $table->{caption},
         @{$table->{row}}) {
      next unless $_;
      delete $_->{element};
    }
    
    for (@{$table->{row_group}}) {
      next unless $_;
      next unless $_->{element};
      $_->{type} = $_->{element}->manakai_local_name;
      delete $_->{element};
    }
    
    for (@{$table->{cell}}) {
      next unless $_;
      for (@{$_}) {
        next unless $_;
        for (@$_) {
          $_->{id} = refaddr $_->{element} if defined $_->{element};
          delete $_->{element};
          $_->{is_header} = $_->{is_header} ? 1 : 0;
        }
      }
    }
        
    print STDOUT '</div><script type="text/javascript">tableToCanvas (';
    print STDOUT JSON::objToJson ($table);
    print STDOUT qq[, document.getElementById ('$input->{id_prefix}table-$i')];
    print STDOUT qq[, '$input->{id_prefix}');</script>];
  }
  
  print STDOUT qq[</div>];
} # print_table_section

sub print_listing_section ($$$) {
  my ($opt, $input, $ids) = @_;
  
#  push @nav, ['#' . $input->{id_prefix} . $opt->{id} => $opt->{label}]
#      unless $input->{nested};
  print STDOUT qq[
<div id="$input->{id_prefix}$opt->{id}" class="section">
<h2>$opt->{heading}</h2>

<dl>
];
  for my $id (sort {$a cmp $b} keys %$ids) {
    print STDOUT qq[<dt><code>@{[htescape $id]}</code></dt>];
    for (@{$ids->{$id}}) {
      print STDOUT qq[<dd>].get_node_link ($input, $_).qq[</dd>];
    }
  }
  print STDOUT qq[</dl></div>];
} # print_listing_section


sub print_rdf_section ($$$) {
  my ($input, $rdfs) = @_;
  
#  push @nav, ['#' . $input->{id_prefix} . 'rdf' => 'RDF']
#      unless $input->{nested};
  print STDOUT qq[
<div id="$input->{id_prefix}rdf" class="section">
<h2>RDF Triples</h2>

<dl>];
  my $i = 0;
  for my $rdf (@$rdfs) {
    print STDOUT qq[<dt id="$input->{id_prefix}rdf-@{[$i++]}">];
    print STDOUT get_node_link ($input, $rdf->[0]);
    print STDOUT qq[<dd><dl>];
    for my $triple (@{$rdf->[1]}) {
      print STDOUT '<dt>' . get_node_link ($input, $triple->[0]) . '<dd>';
      print STDOUT get_rdf_resource_html ($triple->[1]);
      print STDOUT ' ';
      print STDOUT get_rdf_resource_html ($triple->[2]);
      print STDOUT ' ';
      print STDOUT get_rdf_resource_html ($triple->[3]);
    }
    print STDOUT qq[</dl>];
  }
  print STDOUT qq[</dl></div>];
} # print_rdf_section

sub get_rdf_resource_html ($) {
  my $resource = shift;
  if (defined $resource->{uri}) {
    my $euri = htescape ($resource->{uri});
    return '<code class=uri>&lt;<a href="' . $euri . '">' . $euri .
        '</a>></code>';
  } elsif (defined $resource->{bnodeid}) {
    return htescape ('_:' . $resource->{bnodeid});
  } elsif ($resource->{nodes}) {
    return '(rdf:XMLLiteral)';
  } elsif (defined $resource->{value}) {
    my $elang = htescape (defined $resource->{language}
                              ? $resource->{language} : '');
    my $r = qq[<q lang="$elang">] . htescape ($resource->{value}) . '</q>';
    if (defined $resource->{datatype}) {
      my $euri = htescape ($resource->{datatype});
      $r .= '^^<code class=uri>&lt;<a href="' . $euri . '">' . $euri .
          '</a>></code>';
    } elsif (length $resource->{language}) {
      $r .= '@' . htescape ($resource->{language});
    }
    return $r;
  } else {
    return '??';
  }
} # get_rdf_resource_html

{
  my $Msg = {};

sub load_text_catalog ($) {
#  my $self = shift;
  my $lang = shift; # MUST be a canonical lang name
  open my $file, '<:utf8', "cc-msg.$lang.txt"
      or die "$0: cc-msg.$lang.txt: $!";
  while (<$file>) {
    if (s/^([^;]+);([^;]*);//) {
      my ($type, $cls, $msg) = ($1, $2, $_);
      $msg =~ tr/\x0D\x0A//d;
      $Msg->{$type} = [$cls, $msg];
    }
  }
} # load_text_catalog

sub get_text ($;$$) {
#  my $self = shift;
  my ($type, $level, $node) = @_;
  $type = $level . ':' . $type if defined $level;
  $level = 'm' unless defined $level;
  my @arg;
  {
    if (defined $Msg->{$type}) {
      my $msg = $Msg->{$type}->[1];
      $msg =~ s{<var>\$([0-9]+)</var>}{
        defined $arg[$1] ? ($arg[$1]) : '(undef)';
      }ge;                 ##BUG: ^ must be escaped
      $msg =~ s{<var>{\@([A-Za-z0-9:_.-]+)}</var>}{
        UNIVERSAL::can ($node, 'get_attribute_ns')
            ?  ($node->get_attribute_ns (undef, $1)) : ''
      }ge; ## BUG: ^ must be escaped
      $msg =~ s{<var>{\@}</var>}{        ## BUG: v must be escaped
        UNIVERSAL::can ($node, 'value') ? ($node->value) : ''
      }ge;
      $msg =~ s{<var>{local-name}</var>}{
        UNIVERSAL::can ($node, 'manakai_local_name')
          ? ($node->manakai_local_name) : ''
      }ge;  ## BUG: ^ must be escaped
      $msg =~ s{<var>{element-local-name}</var>}{
        (UNIVERSAL::can ($node, 'owner_element') and
         $node->owner_element)
          ?  ($node->owner_element->manakai_local_name)
          : '' ## BUG: ^ must be escaped
      }ge;
      return ($type, 'level-' . $level . ' ' . $Msg->{$type}->[0], $msg);
    } elsif ($type =~ s/:([^:]*)$//) {
      unshift @arg, $1;
      redo;
    }
  }
  return ($type, 'level-'.$level, ($_[0]));
                                 ## BUG: ^ must be escaped
} # get_text

}

sub get_input_document ($$) {
  my ($http, $dom) = @_;

  require Encode;
  my $request_uri = Encode::decode ('utf-8', $http->get_parameter ('uri'));
  my $r = WebHACC::Input->new;
  if (defined $request_uri and length $request_uri) {
    my $uri = $dom->create_uri_reference ($request_uri);
    unless ({
             http => 1,
            }->{lc $uri->uri_scheme}) {
      $r = WebHACC::Input::Error->new;
      $r->{uri} = $request_uri;
      $r->{request_uri} = $request_uri;
      $r->{error_status_text} = 'URL scheme not allowed';
    }

    require Message::Util::HostPermit;
    my $host_permit = new Message::Util::HostPermit;
    $host_permit->add_rule (<<EOH);
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
    unless ($host_permit->check ($uri->uri_host, $uri->uri_port || 80)) {
      my $r = WebHACC::Input::Error->new;
      $r->{uri} = $request_uri;
      $r->{request_uri} = $request_uri;
      $r->{error_status_text} = 'Connection to the host is forbidden';
      return $r;
    }

    require LWP::UserAgent;
    my $ua = WDCC::LWPUA->new;
    $ua->{wdcc_dom} = $dom;
    $ua->{wdcc_host_permit} = $host_permit;
    $ua->agent ('Mozilla'); ## TODO: for now.
    $ua->parse_head (0);
    $ua->protocols_allowed ([qw/http/]);
    $ua->max_size (1000_000);
    my $req = HTTP::Request->new (GET => $request_uri);
    $req->header ('Accept-Encoding' => 'identity, *; q=0');
    my $res = $ua->request ($req);
    ## TODO: 401 sets |is_success| true.
    if ($res->is_success or $http->get_parameter ('error-page')) {
      $r->{base_uri} = $res->base; ## NOTE: It does check |Content-Base|, |Content-Location|, and <base>. ## TODO: Use our own code!
      $r->{uri} = $res->request->uri;
      $r->{request_uri} = $request_uri;

      ## TODO: More strict parsing...
      my $ct = $res->header ('Content-Type');
      if (defined $ct and $ct =~ /;\s*charset\s*=\s*"?([^\s;"]+)"?/i) {
        $r->{charset} = lc $1;
        $r->{charset} =~ tr/\\//d;
        $r->{official_charset} = $r->{charset};
      }

      my $input_charset = $http->get_parameter ('charset');
      if (defined $input_charset and length $input_charset) {
        $r->{charset_overridden}
            = (not defined $r->{charset} or $r->{charset} ne $input_charset);
        $r->{charset} = $input_charset;
      }

      ## TODO: Support for HTTP Content-Encoding

      $r->{s} = ''.$res->content;

      require Whatpm::ContentType;
      ($r->{official_type}, $r->{media_type})
          = Whatpm::ContentType->get_sniffed_type
              (get_file_head => sub {
                 return substr $r->{s}, 0, shift;
               },
               http_content_type_byte => $ct,
               has_http_content_encoding =>
                   defined $res->header ('Content-Encoding'),
               supported_image_types => {});
    } else {
      $r->{uri} = $res->request->uri;
      $r->{request_uri} = $request_uri;
      $r->{error_status_text} = $res->status_line;
    }

    $r->{header_field} = [];
    $res->scan (sub {
      push @{$r->{header_field}}, [$_[0], $_[1]];
    });
    $r->{header_status_code} = $res->code;
    $r->{header_status_text} = $res->message;
  } else {
    $r->{s} = ''.$http->get_parameter ('s');
    $r->{uri} = q<thismessage:/>;
    $r->{request_uri} = q<thismessage:/>;
    $r->{base_uri} = q<thismessage:/>;
    $r->{charset} = ''.$http->get_parameter ('_charset_');
    $r->{charset} =~ s/\s+//g;
    $r->{charset} = 'utf-8' if $r->{charset} eq '';
    $r->{official_charset} = $r->{charset};
    $r->{header_field} = [];

    require Whatpm::ContentType;
    ($r->{official_type}, $r->{media_type})
        = Whatpm::ContentType->get_sniffed_type
            (get_file_head => sub {
               return substr $r->{s}, 0, shift;
             },
             http_content_type_byte => undef,
             has_http_content_encoding => 0,
             supported_image_types => {});
  }

  my $input_format = $http->get_parameter ('i');
  if (defined $input_format and length $input_format) {
    $r->{media_type_overridden}
        = (not defined $r->{media_type} or $input_format ne $r->{media_type});
    $r->{media_type} = $input_format;
  }
  if (defined $r->{s} and not defined $r->{media_type}) {
    $r->{media_type} = 'text/html';
    $r->{media_type_overridden} = 1;
  }

  if ($r->{media_type} eq 'text/xml') {
    unless (defined $r->{charset}) {
      $r->{charset} = 'us-ascii';
      $r->{official_charset} = $r->{charset};
    } elsif ($r->{charset_overridden} and $r->{charset} eq 'us-ascii') {
      $r->{charset_overridden} = 0;
    }
  }

  if (length $r->{s} > 1000_000) {
    $r->{error_status_text} = 'Entity-body too large';
    delete $r->{s};
    return $r;
  }

  $r->{inner_html_element} = $http->get_parameter ('e');

  return $r;
} # get_input_document

package WDCC::LWPUA;
BEGIN { push our @ISA, 'LWP::UserAgent'; }

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
          }->{lc $uri->uri_scheme}) {
    return 0;
  }
  unless ($ua->{wdcc_host_permit}->check ($uri->uri_host, $uri->uri_port || 80)) {
    return 0;
  }
  return 1;
} # redirect_ok

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

Copyright 2007-2008 Wakaba <w@suika.fam.cx>

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

## $Date: 2008/07/21 05:24:32 $

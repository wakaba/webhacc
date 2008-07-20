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

  my $char_length = 0;

  $out->start_section (id => 'document-info', title => 'Information');
  $out->html (qq[<dl>
<dt>Request URL</dt>
    <dd>]);
  $out->url ($input->{request_uri});
  $out->html (q[<dt>Document URL<!-- HTML5 document's address? -->
    <dd>]);
  $out->url ($input->{uri}, id => 'anchor-document-url');
  $out->html (q[
    <script>
      document.title = '<'
          + document.getElementById ('anchor-document-url').href + '> \\u2014 '
          + document.title;
    </script>]);
  ## NOTE: no </dl> yet

  if (defined $input->{s}) {
    $char_length = length $input->{s};

    $out->html (qq[<dt>Base URI<dd>]);
    $out->url ($input->{base_uri});
    $out->html (qq[<dt>Internet Media Type</dt>
    <dd><code class="MIME" lang="en">]);
    $out->text ($input->{media_type});
    $out->html (qq[</code> ]);
    if ($input->{media_type_overridden}) {
      $out->html ('<em>(overridden)</em>');
    } elsif (defined $input->{official_type}) {
      if ($input->{media_type} eq $input->{official_type}) {
        #
      } else {
        $out->html ('<em>(sniffed; official type is: <code class=MIME lang=en>');
        $out->text ($input->{official_type});
        $out->html ('</code>)');
      }
    } else {
      $out->html ('<em>(sniffed)</em>');
    }
    $out->html (q[<dt>Character Encoding<dd>]);
    if (defined $input->{charset}) {
      $out->html ('<code class="charset" lang="en">');
      $out->text ($input->{charset});
      $out->html ('</code>');
    } else {
      $out->text ('(none)');
    }
    $out->html (' <em>overridden</em>') if $input->{charset_overridden};
    $out->html (qq[
<dt>Length</dt>
    <dd>$char_length byte@{[$char_length == 1 ? '' : 's']}</dd>
</dl>

<script src="../cc-script.js"></script>
]);
    $out->end_section;

    my $result = WebHACC::Result->new;
    $result->{conforming_min} = 1;
    $result->{conforming_max} = 1;
    check_and_print ($input => $result => $out);
    print_result_section ($result);
  } else {
    $out->html ('</dl>');
    $out->end_section;
    print_result_input_error_section ($input);
  }

  $out->nav_list;

  exit;
}

sub add_error ($$$) {
  my ($layer, $err, $result) = @_;
  if (defined $err->{level}) {
    if ($err->{level} eq 's') {
      $result->{$layer}->{should}++;
      $result->{$layer}->{score_min} -= 2;
      $result->{conforming_min} = 0;
    } elsif ($err->{level} eq 'w' or $err->{level} eq 'g') {
      $result->{$layer}->{warning}++;
    } elsif ($err->{level} eq 'u' or $err->{level} eq 'unsupported') {
      $result->{$layer}->{unsupported}++;
      $result->{unsupported} = 1;
    } elsif ($err->{level} eq 'i') {
      #
    } else {
      $result->{$layer}->{must}++;
      $result->{$layer}->{score_max} -= 2;
      $result->{$layer}->{score_min} -= 2;
      $result->{conforming_min} = 0;
      $result->{conforming_max} = 0;
    }
  } else {
    $result->{$layer}->{must}++;
    $result->{$layer}->{score_max} -= 2;
    $result->{$layer}->{score_min} -= 2;
    $result->{conforming_min} = 0;
    $result->{conforming_max} = 0;
  }
} # add_error

sub check_and_print ($$$) {
  my ($input, $result, $out) = @_;
  my $original_input = $out->input;
  $out->input ($input);

  print_http_header_section ($input, $result);

  my @subdoc;

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
    my $subinput = WebHACC::Input->new;
    $subinput->{$_} = $_subinput->{$_} for keys %$_subinput;
    $subinput->id_prefix ('subdoc-' . ++$id_prefix);
    $subinput->nested (1);
    $subinput->{base_uri} = $subinput->{container_node}->base_uri
        unless defined $subinput->{base_uri};
    my $ebaseuri = htescape ($subinput->{base_uri});
    $out->start_section (id => $subinput->id_prefix,
                         title => qq[Subdocument #$id_prefix]);
    print STDOUT qq[
      <dl>
      <dt>Internet Media Type</dt>
        <dd><code class="MIME" lang="en">@{[htescape $subinput->{media_type}]}</code>
      <dt>Container Node</dt>
        <dd>@{[get_node_link ($input, $subinput->{container_node})]}</dd>
      <dt>Base <abbr title="Uniform Resource Identifiers">URI</abbr></dt>
        <dd><code class=URI>&lt;<a href="$ebaseuri">$ebaseuri</a>></code></dd>
      </dl>];              

    $subinput->{id_prefix} .= '-';
    check_and_print ($subinput => $result => $out);

    $out->end_section;
  }

  $out->input ($original_input);
} # check_and_print

sub print_http_header_section ($$) {
  my ($input, $result) = @_;
  return unless defined $input->{header_status_code} or
      defined $input->{header_status_text} or
      @{$input->{header_field} or []};
  
  $out->start_section (id => 'source-header', title => 'HTTP Header');
  print STDOUT qq[<p><strong>Note</strong>: Due to the limitation of the
network library in use, the content of this section might
not be the real header.</p>

<table><tbody>
];

  if (defined $input->{header_status_code}) {
    print STDOUT qq[<tr><th scope="row">Status code</th>];
    print STDOUT qq[<td>];
    $out->code ($input->{header_status_code});
  }
  if (defined $input->{header_status_text}) {
    print STDOUT qq[<tr><th scope="row">Status text</th>];
    print STDOUT qq[<td>];
    $out->code ($input->{header_status_text});
  }
  
  for (@{$input->{header_field}}) {
    print STDOUT qq[<tr><th scope="row">];
    $out->code ($_->[0]);
    print STDOUT qq[<td>];
    $out->code ($_->[1]);
  }

  print STDOUT qq[</tbody></table>];

  $out->end_section;
} # print_http_header_section

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

sub print_result_section ($) {
  my $result = shift;

  $out->start_section (id => 'result-summary',
                       title => 'Result');

  if ($result->{unsupported} and $result->{conforming_max}) {  
    print STDOUT qq[<p class=uncertain id=result-para>The conformance
        checker cannot decide whether the document is conforming or
        not, since the document contains one or more unsupported
        features.  The document might or might not be conforming.</p>];
  } elsif ($result->{conforming_min}) {
    print STDOUT qq[<p class=PASS id=result-para>No conformance-error is
        found in this document.</p>];
  } elsif ($result->{conforming_max}) {
    print STDOUT qq[<p class=SEE-RESULT id=result-para>This document
        is <strong>likely <em>non</em>-conforming</strong>, but in rare case
        it might be conforming.</p>];
  } else {
    print STDOUT qq[<p class=FAIL id=result-para>This document is 
        <strong><em>non</em>-conforming</strong>.</p>];
  }

  print STDOUT qq[<table>
<colgroup><col><colgroup><col><col><col><colgroup><col>
<thead>
<tr><th scope=col></th>
<th scope=col><a href="../error-description#level-m"><em class=rfc2119>MUST</em>‐level
Errors</a></th>
<th scope=col><a href="../error-description#level-s"><em class=rfc2119>SHOULD</em>‐level
Errors</a></th>
<th scope=col><a href="../error-description#level-w">Warnings</a></th>
<th scope=col>Score</th></tr></thead><tbody>];

  my $must_error = 0;
  my $should_error = 0;
  my $warning = 0;
  my $score_min = 0;
  my $score_max = 0;
  my $score_base = 20;
  my $score_unit = $score_base / 100;
  for (
    [Transfer => 'transfer', ''],
    [Character => 'char', ''],
    [Syntax => 'syntax', '#parse-errors'],
    [Structure => 'structure', '#document-errors'],
  ) {
    $must_error += ($result->{$_->[1]}->{must} += 0);
    $should_error += ($result->{$_->[1]}->{should} += 0);
    $warning += ($result->{$_->[1]}->{warning} += 0);
    $score_min += (($result->{$_->[1]}->{score_min} *= $score_unit) += $score_base);
    $score_max += (($result->{$_->[1]}->{score_max} *= $score_unit) += $score_base);

    my $uncertain = $result->{$_->[1]}->{unsupported} ? '?' : '';
    my $label = $_->[0];
    if ($result->{$_->[1]}->{must} or
        $result->{$_->[1]}->{should} or
        $result->{$_->[1]}->{warning} or
        $result->{$_->[1]}->{unsupported}) {
      $label = qq[<a href="$_->[2]">$label</a>];
    }

    print STDOUT qq[<tr class="@{[$uncertain ? 'uncertain' : '']}"><th scope=row>$label</th><td class="@{[$result->{$_->[1]}->{must} ? 'FAIL' : '']}">$result->{$_->[1]}->{must}$uncertain</td><td class="@{[$result->{$_->[1]}->{should} ? 'SEE-RESULT' : '']}">$result->{$_->[1]}->{should}$uncertain</td><td>$result->{$_->[1]}->{warning}$uncertain</td>];
    if ($uncertain) {
      print qq[<td class="@{[$result->{$_->[1]}->{must} ? 'FAIL' : $result->{$_->[1]}->{should} ? 'SEE-RESULT' : '']}">&#x2212;&#x221E;..$result->{$_->[1]}->{score_max}];
    } elsif ($result->{$_->[1]}->{score_min} != $result->{$_->[1]}->{score_max}) {
      print qq[<td class="@{[$result->{$_->[1]}->{must} ? 'FAIL' : 'SEE-RESULT']}">$result->{$_->[1]}->{score_min}..$result->{$_->[1]}->{score_max}];
    } else {
      print qq[<td class="@{[$result->{$_->[1]}->{must} ? 'FAIL' : '']}">$result->{$_->[1]}->{score_min}];
    }
    print qq[ / 20];
  }

  $score_max += $score_base;

  print STDOUT qq[
<tr class=uncertain><th scope=row>Semantics</th><td>0?</td><td>0?</td><td>0?</td><td>&#x2212;&#x221E;..$score_base / 20
</tbody>
<tfoot><tr class=uncertain><th scope=row>Total</th>
<td class="@{[$must_error ? 'FAIL' : '']}">$must_error?</td>
<td class="@{[$should_error ? 'SEE-RESULT' : '']}">$should_error?</td>
<td>$warning?</td>
<td class="@{[$must_error ? 'FAIL' : $should_error ? 'SEE-RESULT' : '']}"><strong>&#x2212;&#x221E;..$score_max</strong> / 100
</table>

<p><strong>Important</strong>: This conformance checking service
is <em>under development</em>.  The result above might be <em>wrong</em>.</p>];
  $out->end_section;
} # print_result_section

sub print_result_input_error_section ($) {
  my $input = shift;
  $out->start_section (id => 'result-summary', title => 'Result');
  print STDOUT qq[
<p><em><strong>Input Error</strong>: @{[htescape ($input->{error_status_text})]}</em></p>];
  $out->end_section;
} # print_result_input_error_section

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

  my $request_uri = $http->get_parameter ('uri');
  my $r = WebHACC::Input->new;
  if (defined $request_uri and length $request_uri) {
    my $uri = $dom->create_uri_reference ($request_uri);
    unless ({
             http => 1,
            }->{lc $uri->uri_scheme}) {
      return {uri => $request_uri, request_uri => $request_uri,
              error_status_text => 'URI scheme not allowed'};
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
      return {uri => $request_uri, request_uri => $request_uri,
              error_status_text => 'Connection to the host is forbidden'};
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

## $Date: 2008/07/20 14:58:24 $

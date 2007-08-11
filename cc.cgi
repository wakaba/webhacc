#!/usr/bin/perl
use strict;

use lib qw[/home/httpd/html/www/markup/html/whatpm
           /home/wakaba/work/manakai2/lib];
use CGI::Carp qw[fatalsToBrowser];
use Scalar::Util qw[refaddr];
use Time::HiRes qw/time/;

sub htescape ($) {
  my $s = $_[0];
  $s =~ s/&/&amp;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  $s =~ s/"/&quot;/g;
  $s =~ s{([\x00-\x09\x0B-\x1F\x7F-\xA0\x{FEFF}\x{FFFC}-\x{FFFF}])}{
    sprintf '<var>U+%04X</var>', ord $1;
  }ge;
  return $s;
} # htescape

  use Message::CGI::HTTP;
  my $http = Message::CGI::HTTP->new;

  if ($http->get_meta_variable ('PATH_INFO') ne '/') {
    print STDOUT "Status: 404 Not Found\nContent-Type: text/plain; charset=us-ascii\n\n400";
    exit;
  }

  binmode STDOUT, ':utf8';
  $| = 1;

  require Message::DOM::DOMImplementation;
  my $dom = Message::DOM::DOMImplementation->new;

  load_text_catalog ('en'); ## TODO: conneg

  my @nav;
  print STDOUT qq[Content-Type: text/html; charset=utf-8

<!DOCTYPE html>
<html lang="en">
<head>
<title>Web Document Conformance Checker (BETA)</title>
<link rel="stylesheet" href="../cc-style.css" type="text/css">
</head>
<body>
<h1><a href="../cc-interface">Web Document Conformance Checker</a> 
(<em>beta</em>)</h1>
];

  $| = 0;
  my $input = get_input_document ($http, $dom);
  my $inner_html_element = $http->get_parameter ('e');
  my $char_length = 0;
  my %time;
  my $time1;
  my $time2;

  print qq[
<div id="document-info" class="section">
<dl>
<dt>Request URI</dt>
    <dd><code class="URI" lang="">&lt;<a href="@{[htescape $input->{request_uri}]}">@{[htescape $input->{request_uri}]}</a>&gt;</code></dd>
<dt>Document URI</dt>
    <dd><code class="URI" lang="">&lt;<a href="@{[htescape $input->{uri}]}">@{[htescape $input->{uri}]}</a>&gt;</code></dd>
]; # no </dl> yet
  push @nav, ['#document-info' => 'Information'];

if (defined $input->{s}) {
  $char_length = length $input->{s};

  print STDOUT qq[
<dt>Base URI</dt>
    <dd><code class="URI" lang="">&lt;<a href="@{[htescape $input->{base_uri}]}">@{[htescape $input->{base_uri}]}</a>&gt;</code></dd>
<dt>Internet Media Type</dt>
    <dd><code class="MIME" lang="en">@{[htescape $input->{media_type}]}</code>
    @{[$input->{media_type_overridden} ? '<em>(overridden)</em>' : '']}</dd>
<dt>Character Encoding</dt>
    <dd>@{[defined $input->{charset} ? '<code class="charset" lang="en">'.htescape ($input->{charset}).'</code>' : '(none)']}
    @{[$input->{charset_overridden} ? '<em>(overridden)</em>' : '']}</dd>
<dt>Length</dt>
    <dd>$char_length byte@{[$char_length == 1 ? '' : 's']}</dd>
</dl>
</div>
];

  print_http_header_section ($input);

  my $doc;
  my $el;

  if ($input->{media_type} eq 'text/html') {
    require Encode;
    require Whatpm::HTML;

    $input->{charset} ||= 'ISO-8859-1'; ## TODO: for now.

    $time1 = time;
    my $t = Encode::decode ($input->{charset}, $input->{s});
    $time2 = time;
    $time{decode} = $time2 - $time1;

    print STDOUT qq[
<div id="parse-errors" class="section">
<h2>Parse Errors</h2>

<dl>];
  push @nav, ['#parse-errors' => 'Parse Error'];

  my $onerror = sub {
    my (%opt) = @_;
    my ($type, $cls, $msg) = get_text ($opt{type}, $opt{level});
    if ($opt{column} > 0) {
      print STDOUT qq[<dt class="$cls"><a href="#line-$opt{line}">Line $opt{line}</a> column $opt{column}</dt>\n];
    } else {
      $opt{line} = $opt{line} - 1 || 1;
      print STDOUT qq[<dt class="$cls"><a href="#line-$opt{line}">Line $opt{line}</a></dt>\n];
    }
    $type =~ tr/ /-/;
    $type =~ s/\|/%7C/g;
    $msg .= qq[ [<a href="../error-description#@{[htescape ($type)]}">Description</a>]];
    print STDOUT qq[<dd class="$cls">$msg</dd>\n];
  };

  $doc = $dom->create_document;
  $time1 = time;
  if (defined $inner_html_element and length $inner_html_element) {
    $el = $doc->create_element_ns
        ('http://www.w3.org/1999/xhtml', [undef, $inner_html_element]);
    Whatpm::HTML->set_inner_html ($el, $t, $onerror);
  } else {
    Whatpm::HTML->parse_string ($t => $doc, $onerror);
  }
  $time2 = time;
  $time{parse} = $time2 - $time1;

  print STDOUT qq[</dl>
</div>
];

    print_source_string_section (\($input->{s}), $input->{charset});
  } elsif ({
            'text/xml' => 1,
            'application/atom+xml' => 1,
            'application/rss+xml' => 1,
            'application/svg+xml' => 1,
            'application/xhtml+xml' => 1,
            'application/xml' => 1,
           }->{$input->{media_type}}) {
    require Message::DOM::XMLParserTemp;

    print STDOUT qq[
<div id="parse-errors" class="section">
<h2>Parse Errors</h2>

<dl>];
  push @nav, ['#parse-errors' => 'Parse Error'];

  my $onerror = sub {
    my $err = shift;
    my $line = $err->location->line_number;
    print STDOUT qq[<dt><a href="#line-$line">Line $line</a> column ];
    print STDOUT $err->location->column_number, "</dt><dd>";
    print STDOUT htescape $err->text, "</dd>\n";
    return 1;
  };

  $time1 = time;
  open my $fh, '<', \($input->{s});
  $doc = Message::DOM::XMLParserTemp->parse_byte_stream
      ($fh => $dom, $onerror, charset => $input->{charset});
  $time2 = time;
  $time{parse_xml} = $time2 - $time1;

    print STDOUT qq[</dl>
</div>

];
    print_source_string_section (\($input->{s}), $doc->input_encoding);
  } else {
    ## TODO: Change HTTP status code??
    print STDOUT qq[
<div id="result-summary" class="section">
<p><em>Media type <code class="MIME" lang="en">@{[htescape $input->{media_type}]}</code> is not supported!</em></p>
</div>
];
    push @nav, ['#result-summary' => 'Result'];
  }


  if (defined $doc or defined $el) {
    print STDOUT qq[
<div id="document-tree" class="section">
<h2>Document Tree</h2>
];
    push @nav, ['#document-tree' => 'Tree'];

    print_document_tree ($el || $doc);

    print STDOUT qq[
</div>

<div id="document-errors" class="section">
<h2>Document Errors</h2>

<dl>];
    push @nav, ['#document-errors' => 'Document Error'];

    require Whatpm::ContentChecker;
    my $onerror = sub {
      my %opt = @_;
      my ($type, $cls, $msg) = get_text ($opt{type}, $opt{level}, $opt{node});
      $type =~ tr/ /-/;
      $type =~ s/\|/%7C/g;
      $msg .= qq[ [<a href="../error-description#@{[htescape ($type)]}">Description</a>]];
      print STDOUT qq[<dt class="$cls">] . get_node_link ($opt{node}) .
          qq[</dt>\n<dd class="$cls">], $msg, "</dd>\n";
    };

    $time1 = time;
    my $elements;
    if ($el) {
      $elements = Whatpm::ContentChecker->check_element ($el, $onerror);
    } else {
      $elements = Whatpm::ContentChecker->check_document ($doc, $onerror);
    }
    $time2 = time;
    $time{check} = $time2 - $time1;

    print STDOUT qq[</dl>
</div>
];

    if (@{$elements->{table}}) {
      require JSON;

      push @nav, ['#tables' => 'Tables'];
      print STDOUT qq[
<div id="tables" class="section">
<h2>Tables</h2>

<!--[if IE]><script type="text/javascript" src="../excanvas.js"></script><![endif]-->
<script src="../table-script.js" type="text/javascript"></script>
<noscript>
<p><em>Structure of tables are visualized here if scripting is enabled.</em></p>
</noscript>
];

      my $i = 0;
      for my $table_el (@{$elements->{table}}) {
        $i++;
        print STDOUT qq[<div class="section" id="table-$i"><h3>] .
            get_node_link ($table_el) . q[</h3>];

        ## TODO: Make |ContentChecker| return |form_table| result
        ## so that this script don't have to run the algorithm twice.
        my $table = Whatpm::HTMLTable->form_table ($table_el);
        
        for (@{$table->{column_group}}, @{$table->{column}}, $table->{caption}) {
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
        print STDOUT qq[, document.getElementById ('table-$i'));</script>];
      }
    
      print STDOUT qq[</div>];
    }

    if (keys %{$elements->{id}}) {
      push @nav, ['#identifiers' => 'IDs'];
      print STDOUT qq[
<div id="identifiers" class="section">
<h2>Identifiers</h2>

<dl>
];
      for my $id (sort {$a cmp $b} keys %{$elements->{id}}) {
        print STDOUT qq[<dt><code>@{[htescape $id]}</code></dt>];
        for (@{$elements->{id}->{$id}}) {
          print STDOUT qq[<dd>].get_node_link ($_).qq[</dd>];
        }
      }
      print STDOUT qq[</dl></div>];
    }

    if (keys %{$elements->{term}}) {
      push @nav, ['#terms' => 'Terms'];
      print STDOUT qq[
<div id="terms" class="section">
<h2>Terms</h2>

<dl>
];
      for my $term (sort {$a cmp $b} keys %{$elements->{term}}) {
        print STDOUT qq[<dt>@{[htescape $term]}</dt>];
        for (@{$elements->{term}->{$term}}) {
          print STDOUT qq[<dd>].get_node_link ($_).qq[</dd>];
        }
      }
      print STDOUT qq[</dl></div>];
    }

    if (keys %{$elements->{class}}) {
      push @nav, ['#classes' => 'Classes'];
      print STDOUT qq[
<div id="classes" class="section">
<h2>Classes</h2>

<dl>
];
      for my $class (sort {$a cmp $b} keys %{$elements->{class}}) {
        print STDOUT qq[<dt><code>@{[htescape $class]}</code></dt>];
        for (@{$elements->{class}->{$class}}) {
          print STDOUT qq[<dd>].get_node_link ($_).qq[</dd>];
        }
      }
      print STDOUT qq[</dl></div>];
    }
  }

  ## TODO: Show result
} else {
  print STDOUT qq[
</dl>
</div>

<div class="section" id="result-summary">
<p><em><strong>Input Error</strong>: @{[htescape ($input->{error_status_text})]}</em></p>
</div>
];
  push @nav, ['#result-summary' => 'Result'];

}

  print STDOUT qq[
<ul class="navigation" id="nav-items">
];
  for (@nav) {
    print STDOUT qq[<li><a href="$_->[0]">$_->[1]</a></li>];
  }
  print STDOUT qq[
</ul>
</body>
</html>
];

  for (qw/decode parse parse_xml check/) {
    next unless defined $time{$_};
    open my $file, '>>', ".cc-$_.txt" or die ".cc-$_.txt: $!";
    print $file $char_length, "\t", $time{$_}, "\n";
  }

exit;

sub print_http_header_section ($) {
  my $input = shift;
  return unless defined $input->{header_status_code} or
      defined $input->{header_status_text} or
      @{$input->{header_field}};
  
  push @nav, ['#source-header' => 'HTTP Header'];
  print STDOUT qq[<div id="source-header" class="section">
<h2>HTTP Header</h2>

<p><strong>Note</strong>: Due to the limitation of the
network library in use, the content of this section might
not be the real header.</p>

<table><tbody>
];

  if (defined $input->{header_status_code}) {
    print STDOUT qq[<tr><th scope="row">Status code</th>];
    print STDOUT qq[<td><code>@{[htescape ($input->{header_status_code})]}</code></td></tr>];
  }
  if (defined $input->{header_status_text}) {
    print STDOUT qq[<tr><th scope="row">Status text</th>];
    print STDOUT qq[<td><code>@{[htescape ($input->{header_status_text})]}</code></td></tr>];
  }
  
  for (@{$input->{header_field}}) {
    print STDOUT qq[<tr><th scope="row"><code>@{[htescape ($_->[0])]}</code></th>];
    print STDOUT qq[<td><code>@{[htescape ($_->[1])]}</code></td></tr>];
  }

  print STDOUT qq[</tbody></table></div>];
} # print_http_header_section

sub print_source_string_section ($$) {
  require Encode;
  my $enc = Encode::find_encoding ($_[1]); ## TODO: charset name -> Perl name
  return unless $enc;

  my $s = \($enc->decode (${$_[0]}));
  my $i = 1;                             
  push @nav, ['#source-string' => 'Source'];
  print STDOUT qq[<div id="source-string" class="section">
<h2>Document Source</h2>
<ol lang="">\n];
  if (length $$s) {
    while ($$s =~ /\G([^\x0A]*?)\x0D?\x0A/gc) {
      print STDOUT qq[<li id="line-$i">], htescape $1, "</li>\n";
      $i++;
    }
    if ($$s =~ /\G([^\x0A]+)/gc) {
      print STDOUT qq[<li id="line-$i">], htescape $1, "</li>\n";
    }
  } else {
    print STDOUT q[<li id="line-1"></li>];
  }
  print STDOUT "</ol></div>";
} # print_input_string_section

sub print_document_tree ($) {
  my $node = shift;
  my $r = '<ol class="xoxo">';

  my @node = ($node);
  while (@node) {
    my $child = shift @node;
    unless (ref $child) {
      $r .= $child;
      next;
    }

    my $node_id = 'node-'.refaddr $child;
    my $nt = $child->node_type;
    if ($nt == $child->ELEMENT_NODE) {
      my $child_nsuri = $child->namespace_uri;
      $r .= qq[<li id="$node_id" class="tree-element"><code title="@{[defined $child_nsuri ? $child_nsuri : '']}">] . htescape ($child->tag_name) .
          '</code>'; ## ISSUE: case

      if ($child->has_attributes) {
        $r .= '<ul class="attributes">';
        for my $attr (sort {$a->[0] cmp $b->[0]} map { [$_->name, $_->value, $_->namespace_uri, 'node-'.refaddr $_] }
                      @{$child->attributes}) {
          $r .= qq[<li id="$attr->[3]" class="tree-attribute"><code title="@{[defined $_->[2] ? $_->[2] : '']}">] . htescape ($attr->[0]) . '</code> = '; ## ISSUE: case?
          $r .= '<q>' . htescape ($attr->[1]) . '</q></li>'; ## TODO: children
        }
        $r .= '</ul>';
      }

      if ($child->has_child_nodes) {
        $r .= '<ol class="children">';
        unshift @node, @{$child->child_nodes}, '</ol></li>';
      } else {
        $r .= '</li>';
      }
    } elsif ($nt == $child->TEXT_NODE) {
      $r .= qq'<li id="$node_id" class="tree-text"><q lang="">' . htescape ($child->data) . '</q></li>';
    } elsif ($nt == $child->CDATA_SECTION_NODE) {
      $r .= qq'<li id="$node_id" class="tree-cdata"><code>&lt;[CDATA[</code><q lang="">' . htescape ($child->data) . '</q><code>]]&gt;</code></li>';
    } elsif ($nt == $child->COMMENT_NODE) {
      $r .= qq'<li id="$node_id" class="tree-comment"><code>&lt;!--</code><q lang="">' . htescape ($child->data) . '</q><code>--&gt;</code></li>';
    } elsif ($nt == $child->DOCUMENT_NODE) {
      $r .= qq'<li id="$node_id" class="tree-document">Document';
      $r .= qq[<ul class="attributes">];
      $r .= qq[<li>@{[scalar get_text ('manakaiIsHTML:'.($child->manakai_is_html?1:0))]}</li>];
      $r .= qq[<li>@{[scalar get_text ('manakaiCompatMode:'.$child->manakai_compat_mode)]}</li>];
      unless ($child->manakai_is_html) {
        $r .= qq[<li>XML version = <code>@{[htescape ($child->xml_version)]}</code></li>];
        if (defined $child->xml_encoding) {
          $r .= qq[<li>XML encoding = <code>@{[htescape ($child->xml_encoding)]}</code></li>];
        } else {
          $r .= qq[<li>XML encoding = (null)</li>];
        }
        $r .= qq[<li>XML standalone = @{[$child->xml_standalone ? 'true' : 'false']}</li>];
      }
      $r .= qq[</ul>];
      if ($child->has_child_nodes) {
        $r .= '<ol class="children">';
        unshift @node, @{$child->child_nodes}, '</ol></li>';
      }
    } elsif ($nt == $child->DOCUMENT_TYPE_NODE) {
      $r .= qq'<li id="$node_id" class="tree-doctype"><code>&lt;!DOCTYPE&gt;</code><ul class="attributes">';
      $r .= qq[<li class="tree-doctype-name">Name = <q>@{[htescape ($child->name)]}</q></li>];
      $r .= qq[<li class="tree-doctype-publicid">Public identifier = <q>@{[htescape ($child->public_id)]}</q></li>];
      $r .= qq[<li class="tree-doctype-systemid">System identifier = <q>@{[htescape ($child->system_id)]}</q></li>];
      $r .= '</ul></li>';
    } elsif ($nt == $child->PROCESSING_INSTRUCTION_NODE) {
      $r .= qq'<li id="$node_id" class="tree-id"><code>&lt;?@{[htescape ($child->target)]}</code> <q>@{[htescape ($child->data)]}</q><code>?&gt;</code></li>';
    } else {
      $r .= qq'<li id="$node_id" class="tree-unknown">@{[$child->node_type]} @{[htescape ($child->node_name)]}</li>'; # error
    }
  }

  $r .= '</ol>';
  print STDOUT $r;
} # print_document_tree

sub get_node_path ($) {
  my $node = shift;
  my @r;
  while (defined $node) {
    my $rs;
    if ($node->node_type == 1) {
      $rs = $node->manakai_local_name;
      $node = $node->parent_node;
    } elsif ($node->node_type == 2) {
      $rs = '@' . $node->manakai_local_name;
      $node = $node->owner_element;
    } elsif ($node->node_type == 3) {
      $rs = '"' . $node->data . '"';
      $node = $node->parent_node;
    } elsif ($node->node_type == 9) {
      @r = ('') unless @r;
      $rs = '';
      $node = $node->parent_node;
    } else {
      $rs = '#' . $node->node_type;
      $node = $node->parent_node;
    }
    unshift @r, $rs;
  }
  return join '/', @r;
} # get_node_path

sub get_node_link ($) {
  return qq[<a href="#node-@{[refaddr $_[0]]}">] .
      htescape (get_node_path ($_[0])) . qq[</a>];
} # get_node_link

{
  my $Msg = {};

sub load_text_catalog ($) {
  my $lang = shift; # MUST be a canonical lang name
  open my $file, '<', "cc-msg.$lang.txt" or die "$0: cc-msg.$lang.txt: $!";
  while (<$file>) {
    if (s/^([^;]+);([^;]*);//) {
      my ($type, $cls, $msg) = ($1, $2, $_);
      $msg =~ tr/\x0D\x0A//d;
      $Msg->{$type} = [$cls, $msg];
    }
  }
} # load_text_catalog

sub get_text ($) {
  my ($type, $level, $node) = @_;
  $type = $level . ':' . $type if defined $level;
  my @arg;
  {
    if (defined $Msg->{$type}) {
      my $msg = $Msg->{$type}->[1];
      $msg =~ s{<var>\$([0-9]+)</var>}{
        defined $arg[$1] ? htescape ($arg[$1]) : '(undef)';
      }ge;
      $msg =~ s{<var>{\@([A-Za-z0-9:_.-]+)}</var>}{
        UNIVERSAL::can ($node, 'get_attribute_ns')
            ? htescape ($node->get_attribute_ns (undef, $1)) : ''
      }ge;
      $msg =~ s{<var>{\@}</var>}{
        UNIVERSAL::can ($node, 'value') ? htescape ($node->value) : ''
      }ge;
      return ($type, $Msg->{$type}->[0], $msg);
    } elsif ($type =~ s/:([^:]*)$//) {
      unshift @arg, $1;
      redo;
    }
  }
  return ($type, '', htescape ($_[0]));
} # get_text

}

sub get_input_document ($$) {
  my ($http, $dom) = @_;

  my $request_uri = $http->get_parameter ('uri');
  my $r = {};
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
    my $res = $ua->request ($req);
    ## TODO: 401 sets |is_success| true.
    if ($res->is_success or $http->get_parameter ('error-page')) {
      $r->{base_uri} = $res->base; ## NOTE: It does check |Content-Base|, |Content-Location|, and <base>. ## TODO: Use our own code!
      $r->{uri} = $res->request->uri;
      $r->{request_uri} = $request_uri;

      ## TODO: More strict parsing...
      my $ct = $res->header ('Content-Type');
      if (defined $ct and $ct =~ m#^([0-9A-Za-z._+-]+/[0-9A-Za-z._+-]+)#) {
        $r->{media_type} = lc $1;
      }
      if (defined $ct and $ct =~ /;\s*charset\s*=\s*"?(\S+)"?/i) {
        $r->{charset} = lc $1;
        $r->{charset} =~ tr/\\//d;
      }

      my $input_charset = $http->get_parameter ('charset');
      if (defined $input_charset and length $input_charset) {
        $r->{charset_overridden}
            = (not defined $r->{charset} or $r->{charset} ne $input_charset);
        $r->{charset} = $input_charset;
      } 

      $r->{s} = ''.$res->content;
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
    $r->{header_field} = [];
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
    } elsif ($r->{charset_overridden} and $r->{charset} eq 'us-ascii') {
      $r->{charset_overridden} = 0;
    }
  }

  if (length $r->{s} > 1000_000) {
    $r->{error_status_text} = 'Entity-body too large';
    delete $r->{s};
    return $r;
  }

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

Copyright 2007 Wakaba <w@suika.fam.cx>

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

## $Date: 2007/08/11 13:54:55 $

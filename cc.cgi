#!/usr/bin/perl
use strict;
use utf8;

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
  my $char_length = 0;
  my %time;

  print qq[
<div id="document-info" class="section">
<dl>
<dt>Request URI</dt>
    <dd><code class="URI" lang="">&lt;<a href="@{[htescape $input->{request_uri}]}">@{[htescape $input->{request_uri}]}</a>&gt;</code></dd>
<dt>Document URI</dt>
    <dd><code class="URI" lang="">&lt;<a href="@{[htescape $input->{uri}]}" id=anchor-document-uri>@{[htescape $input->{uri}]}</a>&gt;</code>
    <script>
      document.title = '<'
          + document.getElementById ('anchor-document-uri').href + '> \\u2014 '
          + document.title;
    </script></dd>
]; # no </dl> yet
  push @nav, ['#document-info' => 'Information'];

if (defined $input->{s}) {
  $char_length = length $input->{s};

  print STDOUT qq[
<dt>Base URI</dt>
    <dd><code class="URI" lang="">&lt;<a href="@{[htescape $input->{base_uri}]}">@{[htescape $input->{base_uri}]}</a>&gt;</code></dd>
<dt>Internet Media Type</dt>
    <dd><code class="MIME" lang="en">@{[htescape $input->{media_type}]}</code>
    @{[$input->{media_type_overridden} ? '<em>(overridden)</em>' : defined $input->{official_type} ? $input->{media_type} eq $input->{official_type} ? '' : '<em>(sniffed; official type is: <code class=MIME lang=en>'.htescape ($input->{official_type}).'</code>)' : '<em>(sniffed)</em>']}</dd>
<dt>Character Encoding</dt>
    <dd>@{[defined $input->{charset} ? '<code class="charset" lang="en">'.htescape ($input->{charset}).'</code>' : '(none)']}
    @{[$input->{charset_overridden} ? '<em>(overridden)</em>' : '']}</dd>
<dt>Length</dt>
    <dd>$char_length byte@{[$char_length == 1 ? '' : 's']}</dd>
</dl>
</div>
];

  my $result = {conforming_min => 1, conforming_max => 1};
  check_and_print ($input => $result);
  print_result_section ($result);
} else {
  print STDOUT qq[</dl></div>];
  print_result_input_error_section ($input);
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

  for (qw/decode parse parse_html parse_xml parse_manifest
          check check_manifest/) {
    next unless defined $time{$_};
    open my $file, '>>', ".cc-$_.txt" or die ".cc-$_.txt: $!";
    print $file $char_length, "\t", $time{$_}, "\n";
  }

exit;

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

sub check_and_print ($$) {
  my ($input, $result) = @_;
  $input->{id_prefix} = '';
  #$input->{nested} = 1/0;

  print_http_header_section ($input, $result);

  my $doc;
  my $el;
  my $manifest;

  if ($input->{media_type} eq 'text/html') {
    ($doc, $el) = print_syntax_error_html_section ($input, $result);
    print_source_string_section
        (\($input->{s}), $input->{charset} || $doc->input_encoding);
  } elsif ({
            'text/xml' => 1,
            'application/atom+xml' => 1,
            'application/rss+xml' => 1,
            'application/svg+xml' => 1,
            'application/xhtml+xml' => 1,
            'application/xml' => 1,
           }->{$input->{media_type}}) {
    ($doc, $el) = print_syntax_error_xml_section ($input, $result);
    print_source_string_section (\($input->{s}), $doc->input_encoding);
  } elsif ($input->{media_type} eq 'text/cache-manifest') {
## TODO: MUST be text/cache-manifest
    $manifest = print_syntax_error_manifest_section ($input, $result);
    print_source_string_section (\($input->{s}), 'utf-8');
  } else {
    ## TODO: Change HTTP status code??
    print_result_unknown_type_section ($input, $result);
  }

  if (defined $doc or defined $el) {
    print_structure_dump_dom_section ($input, $doc, $el);
    my $elements = print_structure_error_dom_section
        ($input, $doc, $el, $result);
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
  } elsif (defined $manifest) {
    print_structure_dump_manifest_section ($input, $manifest);
    print_structure_error_manifest_section ($input, $manifest, $result);
  }
} # check_and_print

sub print_http_header_section ($$) {
  my ($input, $result) = @_;
  return unless defined $input->{header_status_code} or
      defined $input->{header_status_text} or
      @{$input->{header_field}};
  
  push @nav, ['#source-header' => 'HTTP Header'] unless $input->{nested};
  print STDOUT qq[<div id="$input->{id_prefix}source-header" class="section">
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

sub print_syntax_error_html_section ($$) {
  my ($input, $result) = @_;
  
  require Encode;
  require Whatpm::HTML;
  
  print STDOUT qq[
<div id="$input->{id_prefix}parse-errors" class="section">
<h2>Parse Errors</h2>

<dl>];
  push @nav, ['#parse-errors' => 'Parse Error'] unless $input->{nested};

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
    print STDOUT qq[<dd class="$cls">], get_error_level_label (\%opt);
    print STDOUT qq[$msg</dd>\n];

    add_error ('syntax', \%opt => $result);
  };

  my $doc = $dom->create_document;
  my $el;
  my $inner_html_element = $http->get_parameter ('e');
  if (defined $inner_html_element and length $inner_html_element) {
    $input->{charset} ||= 'windows-1252'; ## TODO: for now.
    my $time1 = time;
    my $t = Encode::decode ($input->{charset}, $input->{s});
    $time{decode} = time - $time1;
    
    $el = $doc->create_element_ns
        ('http://www.w3.org/1999/xhtml', [undef, $inner_html_element]);
    $time1 = time;
    Whatpm::HTML->set_inner_html ($el, $t, $onerror);
    $time{parse} = time - $time1;
  } else {
    my $time1 = time;
    Whatpm::HTML->parse_byte_string
        ($input->{charset}, $input->{s} => $doc, $onerror);
    $time{parse_html} = time - $time1;
  }
  $doc->manakai_charset ($input->{official_charset})
      if defined $input->{official_charset};
  
  print STDOUT qq[</dl></div>];

  return ($doc, $el);
} # print_syntax_error_html_section

sub print_syntax_error_xml_section ($$) {
  my ($input, $result) = @_;
  
  require Message::DOM::XMLParserTemp;
  
  print STDOUT qq[
<div id="$input->{id_prefix}parse-errors" class="section">
<h2>Parse Errors</h2>

<dl>];
  push @nav, ['#parse-errors' => 'Parse Error'] unless $input->{prefix};

  my $onerror = sub {
    my $err = shift;
    my $line = $err->location->line_number;
    print STDOUT qq[<dt><a href="#line-$line">Line $line</a> column ];
    print STDOUT $err->location->column_number, "</dt><dd>";
    print STDOUT htescape $err->text, "</dd>\n";

    add_error ('syntax', {type => $err->text,
                level => [
                          $err->SEVERITY_FATAL_ERROR => 'm',
                          $err->SEVERITY_ERROR => 'm',
                          $err->SEVERITY_WARNING => 's',
                         ]->[$err->severity]} => $result);

    return 1;
  };

  my $time1 = time;
  open my $fh, '<', \($input->{s});
  my $doc = Message::DOM::XMLParserTemp->parse_byte_stream
      ($fh => $dom, $onerror, charset => $input->{charset});
  $time{parse_xml} = time - $time1;
  $doc->manakai_charset ($input->{official_charset})
      if defined $input->{official_charset};

  print STDOUT qq[</dl></div>];

  return ($doc, undef);
} # print_syntax_error_xml_section

sub print_syntax_error_manifest_section ($$) {
  my ($input, $result) = @_;

  require Whatpm::CacheManifest;

  print STDOUT qq[
<div id="$input->{id_prefix}parse-errors" class="section">
<h2>Parse Errors</h2>

<dl>];
  push @nav, ['#parse-errors' => 'Parse Error'] unless $input->{nested};

  my $onerror = sub {
    my (%opt) = @_;
    my ($type, $cls, $msg) = get_text ($opt{type}, $opt{level});
    print STDOUT qq[<dt class="$cls">], get_error_label ($input, \%opt),
        qq[</dt>];
    $type =~ tr/ /-/;
    $type =~ s/\|/%7C/g;
    $msg .= qq[ [<a href="../error-description#@{[htescape ($type)]}">Description</a>]];
    print STDOUT qq[<dd class="$cls">], get_error_level_label (\%opt);
    print STDOUT qq[$msg</dd>\n];

    add_error ('syntax', \%opt => $result);
  };

  my $time1 = time;
  my $manifest = Whatpm::CacheManifest->parse_byte_string
      ($input->{s}, $input->{uri}, $input->{base_uri}, $onerror);
  $time{parse_manifest} = time - $time1;

  print STDOUT qq[</dl></div>];

  return $manifest;
} # print_syntax_error_manifest_section

sub print_source_string_section ($$) {
  require Encode;
  my $enc = Encode::find_encoding ($_[1]); ## TODO: charset name -> Perl name
  return unless $enc;

  my $s = \($enc->decode (${$_[0]}));
  my $i = 1;                             
  push @nav, ['#source-string' => 'Source'] unless $input->{nested};
  print STDOUT qq[<div id="$input->{id_prefix}source-string" class="section">
<h2>Document Source</h2>
<ol lang="">\n];
  if (length $$s) {
    while ($$s =~ /\G([^\x0A]*?)\x0D?\x0A/gc) {
      print STDOUT qq[<li id="$input->{id_prefix}line-$i">], htescape $1,
          "</li>\n";
      $i++;
    }
    if ($$s =~ /\G([^\x0A]+)/gc) {
      print STDOUT qq[<li id="$input->{id_prefix}line-$i">], htescape $1,
          "</li>\n";
    }
  } else {
    print STDOUT q[<li id="$input->{id_prefix}line-1"></li>];
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

    my $node_id = $input->{id_prefix} . 'node-'.refaddr $child;
    my $nt = $child->node_type;
    if ($nt == $child->ELEMENT_NODE) {
      my $child_nsuri = $child->namespace_uri;
      $r .= qq[<li id="$node_id" class="tree-element"><code title="@{[defined $child_nsuri ? $child_nsuri : '']}">] . htescape ($child->tag_name) .
          '</code>'; ## ISSUE: case

      if ($child->has_attributes) {
        $r .= '<ul class="attributes">';
        for my $attr (sort {$a->[0] cmp $b->[0]} map { [$_->name, $_->value, $_->namespace_uri, 'node-'.refaddr $_] }
                      @{$child->attributes}) {
          $r .= qq[<li id="$input->{id_prefix}$attr->[3]" class="tree-attribute"><code title="@{[defined $attr->[2] ? htescape ($attr->[2]) : '']}">] . htescape ($attr->[0]) . '</code> = '; ## ISSUE: case?
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
      my $cp = $child->manakai_charset;
      if (defined $cp) {
        $r .= qq[<li><code>charset</code> parameter = <code>];
        $r .= htescape ($cp) . qq[</code></li>];
      }
      $r .= qq[<li><code>inputEncoding</code> = ];
      my $ie = $child->input_encoding;
      if (defined $ie) {
        $r .= qq[<code>@{[htescape ($ie)]}</code>];
        if ($child->manakai_has_bom) {
          $r .= qq[ (with <code class=charname><abbr>BOM</abbr></code>)];
        }
      } else {
        $r .= qq[(<code>null</code>)];
      }
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

sub print_structure_dump_dom_section ($$$) {
  my ($input, $doc, $el) = @_;

  print STDOUT qq[
<div id="$input->{id_prefix}document-tree" class="section">
<h2>Document Tree</h2>
];
  push @nav, ['#document-tree' => 'Tree'] unless $input->{nested};

  print_document_tree ($el || $doc);

  print STDOUT qq[</div>];
} # print_structure_dump_dom_section

sub print_structure_dump_manifest_section ($$) {
  my ($input, $manifest) = @_;

  print STDOUT qq[
<div id="$input->{id_prefix}dump-manifest" class="section">
<h2>Cache Manifest</h2>
];
  push @nav, ['#dump-manifest' => 'Caceh Manifest'] unless $input->{nested};

  print STDOUT qq[<dl><dt>Explicit entries</dt>];
  for my $uri (@{$manifest->[0]}) {
    my $euri = htescape ($uri);
    print STDOUT qq[<dd><code class=uri>&lt;<a href="$euri">$euri</a>></code></dd>];
  }

  print STDOUT qq[<dt>Fallback entries</dt><dd>
      <table><thead><tr><th scope=row>Oppotunistic Caching Namespace</th>
      <th scope=row>Fallback Entry</tr><tbody>];
  for my $uri (sort {$a cmp $b} keys %{$manifest->[1]}) {
    my $euri = htescape ($uri);
    my $euri2 = htescape ($manifest->[1]->{$uri});
    print STDOUT qq[<tr><td><code class=uri>&lt;<a href="$euri">$euri</a>></code></td>
        <td><code class=uri>&lt;<a href="$euri2">$euri2</a>></code></td>];
  }

  print STDOUT qq[</table><dt>Online whitelist</dt>];
  for my $uri (@{$manifest->[2]}) {
    my $euri = htescape ($uri);
    print STDOUT qq[<dd><code class=uri>&lt;<a href="$euri">$euri</a>></code></dd>];
  }

  print STDOUT qq[</dl></div>];
} # print_structure_dump_manifest_section

sub print_structure_error_dom_section ($$$$) {
  my ($input, $doc, $el, $result) = @_;

  print STDOUT qq[<div id="$input->{id_prefix}document-errors" class="section">
<h2>Document Errors</h2>

<dl>];
  push @nav, ['#document-errors' => 'Document Error'] unless $input->{nested};

  require Whatpm::ContentChecker;
  my $onerror = sub {
    my %opt = @_;
    my ($type, $cls, $msg) = get_text ($opt{type}, $opt{level}, $opt{node});
    $type =~ tr/ /-/;
    $type =~ s/\|/%7C/g;
    $msg .= qq[ [<a href="../error-description#@{[htescape ($type)]}">Description</a>]];
    print STDOUT qq[<dt class="$cls">] . get_error_label ($input, \%opt) .
        qq[</dt>\n<dd class="$cls">], get_error_level_label (\%opt);
    print STDOUT $msg, "</dd>\n";
    add_error ('structure', \%opt => $result);
  };

  my $elements;
  my $time1 = time;
  if ($el) {
    $elements = Whatpm::ContentChecker->check_element ($el, $onerror);
  } else {
    $elements = Whatpm::ContentChecker->check_document ($doc, $onerror);
  }
  $time{check} = time - $time1;

  print STDOUT qq[</dl></div>];

  return $elements;
} # print_structure_error_dom_section

sub print_structure_error_manifest_section ($$$) {
  my ($input, $manifest, $result) = @_;

  print STDOUT qq[<div id="$input->{id_prefix}document-errors" class="section">
<h2>Document Errors</h2>

<dl>];
  push @nav, ['#document-errors' => 'Document Error'] unless $input->{nested};

  require Whatpm::CacheManifest;
  Whatpm::CacheManifest->check_manifest ($manifest, sub {
    my %opt = @_;
    my ($type, $cls, $msg) = get_text ($opt{type}, $opt{level}, $opt{node});
    $type =~ tr/ /-/;
    $type =~ s/\|/%7C/g;
    $msg .= qq[ [<a href="../error-description#@{[htescape ($type)]}">Description</a>]];
    print STDOUT qq[<dt class="$cls">] . get_error_label ($input, \%opt) .
        qq[</dt>\n<dd class="$cls">], $msg, "</dd>\n";
    add_error ('structure', \%opt => $result);
  });

  print STDOUT qq[</div>];
} # print_structure_error_manifest_section

sub print_table_section ($$) {
  my ($input, $tables) = @_;
  
  push @nav, ['#tables' => 'Tables'] unless $input->{nested};
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
  for my $table_el (@$tables) {
    $i++;
    print STDOUT qq[<div class="section" id="$input->{id_prefix}table-$i"><h3>] .
        get_node_link ($input, $table_el) . q[</h3>];

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
    print STDOUT qq[, document.getElementById ('$input->{id_prefix}table-$i')];
    print STDOUT qq[, '$input->{id_prefix}');</script>];
  }
  
  print STDOUT qq[</div>];
} # print_table_section

sub print_listing_section ($$$) {
  my ($opt, $input, $ids) = @_;
  
  push @nav, ['#' . $opt->{id} => $opt->{label}] unless $input->{nested};
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

sub print_result_section ($) {
  my $result = shift;

  print STDOUT qq[
<div id="result-summary" class="section">
<h2>Result</h2>];

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
      print qq[<td class="@{[$result->{$_->[1]}->{must} ? 'FAIL' : $result->{$_->[1]}->{should} ? 'SEE-RESULT' : '']}">&#x2212;&#x221E;..$result->{$_->[1]}->{score_max}</td>];
    } elsif ($result->{$_->[1]}->{score_min} != $result->{$_->[1]}->{score_max}) {
      print qq[<td class="@{[$result->{$_->[1]}->{must} ? 'FAIL' : 'SEE-RESULT']}">$result->{$_->[1]}->{score_min}..$result->{$_->[1]}->{score_max}</td></tr>];
    } else {
      print qq[<td class="@{[$result->{$_->[1]}->{must} ? 'FAIL' : '']}">$result->{$_->[1]}->{score_min}</td></tr>];
    }
  }

  $score_max += $score_base;

  print STDOUT qq[
<tr class=uncertain><th scope=row>Semantics</th><td>0?</td><td>0?</td><td>0?</td><td>&#x2212;&#x221E;..$score_base</td></tr>
</tbody>
<tfoot><tr class=uncertain><th scope=row>Total</th>
<td class="@{[$must_error ? 'FAIL' : '']}">$must_error?</td>
<td class="@{[$should_error ? 'SEE-RESULT' : '']}">$should_error?</td>
<td>$warning?</td>
<td class="@{[$must_error ? 'FAIL' : $should_error ? 'SEE-RESULT' : '']}"><strong>&#x2212;&#x221E;..$score_max</strong></td></tr></tfoot>
</table>

<p><strong>Important</strong>: This conformance checking service
is <em>under development</em>.  The result above might be <em>wrong</em>.</p>
</div>];
  push @nav, ['#result-summary' => 'Result'];
} # print_result_section

sub print_result_unknown_type_section ($$) {
  my ($input, $result) = @_;

  my $euri = htescape ($input->{uri});
  print STDOUT qq[
<div id="parse-errors" class="section">
<h2>Errors</h2>

<dl>
<dt class=unsupported><code>&lt;<a href="$euri">$euri</a>&gt;</code></dt>
    <dd class=unsupported><strong><a href="../error-description#level-u">Not
        supported</a></strong>:
    Media type
    <code class="MIME" lang="en">@{[htescape $input->{media_type}]}</code>
    is not supported.</dd>
</dl>
</div>
];
  push @nav, ['#parse-errors' => 'Errors'];
  add_error (char => {level => 'u'} => $result);
  add_error (syntax => {level => 'u'} => $result);
  add_error (structure => {level => 'u'} => $result);
} # print_result_unknown_type_section

sub print_result_input_error_section ($) {
  my $input = shift;
  print STDOUT qq[<div class="section" id="result-summary">
<p><em><strong>Input Error</strong>: @{[htescape ($input->{error_status_text})]}</em></p>
</div>];
  push @nav, ['#result-summary' => 'Result'];
} # print_result_input_error_section

sub get_error_label ($$) {
  my ($input, $err) = @_;

  my $r = '';

  if (defined $err->{line}) {
    if ($err->{column} > 0) {
      $r = qq[<a href="#line-$err->{line}">Line $err->{line}</a> column $err->{column}];
    } else {
      $err->{line} = $err->{line} - 1 || 1;
      $r = qq[<a href="#line-$err->{line}">Line $err->{line}</a>];
    }
  }

  if (defined $err->{node}) {
    $r .= ' ' if length $r;
    $r = get_node_link ($input, $err->{node});
  }

  if (defined $err->{index}) {
    $r .= ' ' if length $r;
    $r .= 'Index ' . (0+$err->{index});
  }

  if (defined $err->{value}) {
    $r .= ' ' if length $r;
    $r .= '<q><code>' . htescape ($err->{value}) . '</code></q>';
  }

  return $r;
} # get_error_label

sub get_error_level_label ($) {
  my $err = shift;

  my $r = '';

  if (not defined $err->{level} or $err->{level} eq 'm') {
    $r = qq[<strong><a href="../error-description#level-m"><em class=rfc2119>MUST</em>‐level
        error</a></strong>: ];
  } elsif ($err->{level} eq 's') {
    $r = qq[<strong><a href="../error-description#level-s"><em class=rfc2119>SHOULD</em>‐level
        error</a></strong>: ];
  } elsif ($err->{level} eq 'w') {
    $r = qq[<strong><a href="../error-description#level-w">Warning</a></strong>:
        ];
  } elsif ($err->{level} eq 'u' or $err->{level} eq 'unsupported') {
    $r = qq[<strong><a href="../error-description#level-u">Not
        supported</a></strong>: ];
  } else {
    my $elevel = htescape ($err->{level});
    $r = qq[<strong><a href="../error-description#level-$elevel">$elevel</a></strong>:
        ];
  }

  return $r;
} # get_error_level_label

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

sub get_node_link ($$) {
  return qq[<a href="#$_[0]->{id_prefix}node-@{[refaddr $_[1]]}">] .
      htescape (get_node_path ($_[1])) . qq[</a>];
} # get_node_link

{
  my $Msg = {};

sub load_text_catalog ($) {
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

sub get_text ($) {
  my ($type, $level, $node) = @_;
  $type = $level . ':' . $type if defined $level;
  $level = 'm' unless defined $level;
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
      $msg =~ s{<var>{local-name}</var>}{
        UNIVERSAL::can ($node, 'manakai_local_name')
          ? htescape ($node->manakai_local_name) : ''
      }ge;
      $msg =~ s{<var>{element-local-name}</var>}{
        (UNIVERSAL::can ($node, 'owner_element') and
         $node->owner_element)
          ? htescape ($node->owner_element->manakai_local_name)
          : ''
      }ge;
      return ($type, 'level-' . $level . ' ' . $Msg->{$type}->[0], $msg);
    } elsif ($type =~ s/:([^:]*)$//) {
      unshift @arg, $1;
      redo;
    }
  }
  return ($type, 'level-'.$level, htescape ($_[0]));
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

## $Date: 2008/02/10 02:42:01 $

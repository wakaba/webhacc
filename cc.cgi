#!/usr/bin/perl
use strict;

use lib qw[/home/httpd/html/www/markup/html/whatpm
           /home/wakaba/work/manakai/lib
           /home/wakaba/public_html/-temp/wiki/lib];
use CGI::Carp qw[fatalsToBrowser];
use Scalar::Util qw[refaddr];

use SuikaWiki::Input::HTTP; ## TODO: Use some better CGI module

sub htescape ($) {
  my $s = $_[0];
  $s =~ s/&/&amp;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  $s =~ s/"/&quot;/g;
  $s =~ s!([\x00-\x09\x0B-\x1F\x7F-\x80])!sprintf '<var>U+%04X</var>', ord $1!ge;
  return $s;
} # htescape

my $http = SuikaWiki::Input::HTTP->new;

## TODO: _charset_

  my $input_format = $http->parameter ('i') || 'text/html';
  my $inner_html_element = $http->parameter ('e');
  my $input_uri = 'thismessage:/';

  my $s = $http->parameter ('s');
  if (length $s > 1000_000) {
    print STDOUT "Status: 400 Document Too Long\nContent-Type: text/plain; charset=us-ascii\n\nToo long";
    exit;
  }

  print STDOUT qq[Content-Type: text/html; charset=utf-8

<!DOCTYPE html>
<html lang="en">
<head>
<title>Web Document Conformance Checker (BETA)</title>
<link rel="stylesheet" href="/www/style/html/xhtml">
<style>
  q {
    white-space: pre;
    white-space: -moz-pre-wrap;
    white-space: pre-wrap;
  }
</style>
</head>
<body>
<h1>Web Document Conformance Checker (<em>beta</em>)</h1>

<dl>
<dt>Document URI</dt>
    <dd><code class="URI" lang="">&lt;<a href="@{[htescape $input_uri]}">@{[htescape $input_uri]}</a>&gt;</code></dd>
<dt>Internet Media Type</dt>
    <dd><code class="MIME" lang="en">@{[htescape $input_format]}</code></dd>
]; # no </dl> yet

  require Message::DOM::DOMImplementation;
  my $dom = Message::DOM::DOMImplementation->____new;
  my $doc;
  my $el;

  if ($input_format eq 'text/html') {
    require Encode;
    require Whatpm::HTML;
    
    $s = Encode::decode ('utf-8', $s);

    print STDOUT qq[
<dt>Character Encoding</dt>
    <dd>(none)</dd>
</dl>

<div id="source-string" class="section">
];
    print_source_string (\$s);
    print STDOUT qq[
</div>

<div id="parse-errors" class="section">
<h2>Parse Errors</h2>

<ul>
];

  my $onerror = sub {
    my (%opt) = @_;
    if ($opt{column} > 0) {
      print STDOUT qq[<li><a href="#line-$opt{line}">Line $opt{line}</a> column $opt{column}: ];
    } else {
      $opt{line}--;
      print STDOUT qq[<li><a href="#line-$opt{line}">Line $opt{line}</a>: ];
    }
    print STDOUT qq[@{[htescape $opt{type}]}</li>\n];
  };

  $doc = $dom->create_document;
  if (defined $inner_html_element and length $inner_html_element) {
    $el = $doc->create_element_ns
        ('http://www.w3.org/1999/xhtml', [undef, $inner_html_element]);
    Whatpm::HTML->set_inner_html ($el, $s, $onerror);
  } else {
    Whatpm::HTML->parse_string ($s => $doc, $onerror);
  }

  print STDOUT qq[
</ul>
</div>
];
  } elsif ($input_format eq 'application/xhtml+xml') {
    require Message::DOM::XMLParserTemp;
    require Encode;
    
    my $t = Encode::decode ('utf-8', $s);

    print STDOUT qq[
<dt>Character Encoding</dt>
    <dd>(none)</dd>
</dl>

<div id="source-string" class="section">
];
    print_source_string (\$t);
    print STDOUT qq[
</div>

<div id="parse-errors" class="section">
<h2>Parse Errors</h2>

<ul>
];

  my $onerror = sub {
    my $err = shift;
    my $line = $err->location->line_number;
    print STDOUT qq[<li><a href="#line-$line">Line $line</a> column ];
    print STDOUT $err->location->column_number, ": ";
    print STDOUT htescape $err->text, "</li>\n";
    return 1;
  };

  open my $fh, '<', \$s;
  $doc = Message::DOM::XMLParserTemp->parse_byte_stream
      ($fh => $dom, $onerror, charset => 'utf-8');

    print STDOUT qq[
</ul>
</div>
];
  } else {
    print STDOUT qq[
</dl>

<p><em>Media type <code class="MIME" lang="en">@{[htescape $input_format]}</code> is not supported!</em></p>
];
  }


  if (defined $doc or defined $el) {
    print STDOUT qq[
<div id="document-tree" class="section">
<h2>Document Tree</h2>
];

    print_document_tree ($el || $doc);

    print STDOUT qq[
</div>

<div id="document-errors" class="section">
<h2>Document Errors</h2>

<ul>
];

    require Whatpm::ContentChecker;
    my $onerror = sub {
      my %opt = @_;
      print STDOUT qq[<li><a href="#node-@{[refaddr $opt{node}]}">],
          htescape get_node_path ($opt{node}),
          "</a>: ", htescape $opt{type}, "</li>\n";
    };

    if ($el) {
      Whatpm::ContentChecker->check_element ($el, $onerror);
    } else {
      Whatpm::ContentChecker->check_document ($doc, $onerror);
    }

    print STDOUT qq[
</ul>
</div>
];
  }

  ## TODO: Show result
  print STDOUT qq[
</body>
</html>
];

exit;

sub print_source_string ($) {
  my $s = $_[0];
  my $i = 1;
  print STDOUT qq[<ol lang="">\n];
  while ($$s =~ /\G([^\x0A]*?)\x0D?\x0A/gc) {
    print STDOUT qq[<li id="line-$i">], htescape $1, "</li>\n";
    $i++;
  }
  if ($$s =~ /\G([^\x0A]+)/gc) {
    print STDOUT qq[<li id="line-$i">], htescape $1, "</li>\n";
  }
  print STDOUT "</ol>";
} # print_input_string

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
      $r .= qq'<li id="$node_id"><code>' . htescape ($child->tag_name) .
          '</code>'; ## ISSUE: case

      if ($child->has_attributes) {
        $r .= '<ul class="attributes">';
        for my $attr (sort {$a->[0] cmp $b->[0]} map { [$_->name, $_->value, 'node-'.refaddr $_] }
                      @{$child->attributes}) {
          $r .= qq'<li id="$attr->[2]"><code>' . htescape ($attr->[0]) . '</code> = '; ## ISSUE: case?
          $r .= '<q>' . htescape ($attr->[1]) . '</q></li>'; ## TODO: children
        }
        $r .= '</ul>';
      }

      if ($node->has_child_nodes) {
        $r .= '<ol class="children">';
        unshift @node, @{$child->child_nodes}, '</ol>';
      }
    } elsif ($nt == $child->TEXT_NODE) {
      $r .= qq'<li id="$node_id"><q>' . htescape ($child->data) . '</q></li>';
    } elsif ($nt == $child->CDATA_SECTION_NODE) {
      $r .= qq'<li id="$node_id"><code>&lt;[CDATA[</code><q>' . htescape ($child->data) . '</q><code>]]&gt;</code></li>';
    } elsif ($nt == $child->COMMENT_NODE) {
      $r .= qq'<li id="$node_id"><code>&lt;!--</code><q>' . htescape ($child->data) . '</q><code>--&gt;</code></li>';
    } elsif ($nt == $child->DOCUMENT_NODE) {
      $r .= qq'<li id="$node_id">Document</li>';
      if ($child->has_child_nodes) {
        $r .= '<ol>';
        unshift @node, @{$child->child_nodes}, '</ol>';
      }
    } elsif ($nt == $child->DOCUMENT_TYPE_NODE) {
      $r .= qq'<li id="$node_id"><code>&lt;!DOCTYPE&gt;</code><ul>';
      $r .= '<li>Name = <q>@{[htescape ($child->name)]}</q></li>';
      $r .= '<li>Public identifier = <q>@{[htescape ($child->public_id)]}</q></li>';
      $r .= '<li>System identifier = <q>@{[htescape ($child->system_id)]}</q></li>';
      $r .= '</ul></li>';
    } elsif ($nt == $child->PROCESSING_INSTRUCTION_NODE) {
      $r .= qq'<li id="$node_id"><code>&lt;?@{[htescape ($child->target)]}?&gt;</code>';
      $r .= '<ul><li>@{[htescape ($child->data)]}</li></ul></li>';
    } else {
      $r .= qq'<li id="$node_id">@{[$child->node_type]} @{[htescape ($child->node_name)]}</li>'; # error
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

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

Copyright 2007 Wakaba <w@suika.fam.cx>

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

## $Date: 2007/06/27 12:35:24 $

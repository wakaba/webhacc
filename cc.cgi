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
<h1>Web Document Conformance Checker (<em>beta</em>)</h1>

<div id="document-info" class="section">
<dl>
<dt>Document URI</dt>
    <dd><code class="URI" lang="">&lt;<a href="@{[htescape $input_uri]}">@{[htescape $input_uri]}</a>&gt;</code></dd>
<dt>Internet Media Type</dt>
    <dd><code class="MIME" lang="en">@{[htescape $input_format]}</code></dd>
]; # no </dl> yet
  push @nav, ['#document-info' => 'Information'];

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
</div>

<div id="source-string" class="section">
<h2>Document Source</h2>
];
    push @nav, ['#source-string' => 'Source'];
    print_source_string (\$s);
    print STDOUT qq[
</div>

<div id="parse-errors" class="section">
<h2>Parse Errors</h2>

<dl>
];
  push @nav, ['#parse-errors' => 'Parse Error'];

  my $onerror = sub {
    my (%opt) = @_;
    my ($cls, $msg) = get_text ($opt{type}, $opt{level});
    if ($opt{column} > 0) {
      print STDOUT qq[<dt class="$cls"><a href="#line-$opt{line}">Line $opt{line}</a> column $opt{column}</dt>\n];
    } else {
      $opt{line} = $opt{line} - 1 || 1;
      print STDOUT qq[<dt class="$cls"><a href="#line-$opt{line}">Line $opt{line}</a></dt>\n];
    }
    print STDOUT qq[<dd class="$cls">$msg</dd>\n];
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
</dl>
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
</div>

<div id="source-string" class="section">
<h2>Document Source</h2>
];
    push @nav, ['#source-string' => 'Source'];
    print_source_string (\$t);
    print STDOUT qq[
</div>

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

  open my $fh, '<', \$s;
  $doc = Message::DOM::XMLParserTemp->parse_byte_stream
      ($fh => $dom, $onerror, charset => 'utf-8');

    print STDOUT qq[</dl>
</div>
];
  } else {
    print STDOUT qq[
</dl>
</div>

<div id="result-summary" class="section">
<p><em>Media type <code class="MIME" lang="en">@{[htescape $input_format]}</code> is not supported!</em></p>
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
      my ($cls, $msg) = get_text ($opt{type}, $opt{level});
      print STDOUT qq[<dt class="$cls">] . get_node_link ($opt{node}) .
          qq[</dt>\n<dd class="$cls">], $msg, "</dd>\n";
    };

    my $elements;
    if ($el) {
      $elements = Whatpm::ContentChecker->check_element ($el, $onerror);
    } else {
      $elements = Whatpm::ContentChecker->check_document ($doc, $onerror);
    }

    print STDOUT qq[</dl>
</div>
];

    if (@{$elements->{table}}) {
      require JSON;

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
            }
          }
        }
        
        print STDOUT '</div><script type="text/javascript">tableToCanvas (';
        print STDOUT JSON::objToJson ($table);
        print STDOUT qq[, document.getElementById ('table-$i'));</script>];
      }
    
      print STDOUT qq[</div>];
    }

    if (keys %{$elements->{term}}) {
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
  }

  ## TODO: Show result

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

exit;

sub print_source_string ($) {
  my $s = $_[0];
  my $i = 1;
  print STDOUT qq[<ol lang="">\n];
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
  my ($type, $level) = @_;
  $type = $level . ':' . $type if defined $level;
  my @arg;
  {
    if (defined $Msg->{$type}) {
      my $msg = $Msg->{$type}->[1];
      $msg =~ s/\$([0-9]+)/defined $arg[$1] ? htescape ($arg[$1]) : '(undef)'/ge;
      return ($Msg->{$type}->[0], $msg);
    } elsif ($type =~ s/:([^:]*)$//) {
      unshift @arg, $1;
      redo;
    }
  }
  return ('', htescape ($_[0]));
} # get_text

}

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

Copyright 2007 Wakaba <w@suika.fam.cx>

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

## $Date: 2007/07/01 06:21:46 $

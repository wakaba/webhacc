#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use CGI::Carp qw[fatalsToBrowser];
use Time::HiRes qw/time/;

use Message::CGI::HTTP;
my $http = Message::CGI::HTTP->new;

## TODO: _charset_

my @mode = split m#[/+]#, scalar $http->get_meta_variable ('PATH_INFO'), -1;
shift @mode if @mode and $mode[0] == '';
## TODO: decode unreserved characters

  my $s = $http->get_parameter ('s');
  if (length $s > 1000_000) {
    print STDOUT "Status: 400 Document Too Long\nContent-Type: text/plain; charset=us-ascii\n\nToo long";
    exit;
  }
  my $char_length = length $s;
  my %time;
  my $time1;
  my $time2;

  require Message::DOM::DOMImplementation;
  my $dom = Message::DOM::DOMImplementation->new;
#  $| = 1;
  my $doc;
  my $el;


if (@mode == 3 and $mode[0] eq 'html' and
    ($mode[2] eq 'html' or $mode[2] eq 'test' or $mode[2] eq 'xml')) {
  print STDOUT "Content-Type: text/plain; charset=utf-8\n\n";

  require Encode;
  require Whatpm::HTML;

  $time1 = time;
  $s = Encode::decode ('utf-8', $s);
  $time2 = time;
  $time{decode} = $time2 - $time1;
  

  print STDOUT "#errors\n";

  my $onerror = sub {
    my (%opt) = @_;
    print STDOUT "$opt{line},$opt{column},$opt{type};$opt{level};$opt{value}\n";
  };

  $doc = $dom->create_document;
  $doc->manakai_is_html (1);
  $time1 = time;
  if (length $mode[1]) {
    $el = $doc->create_element_ns
        ('http://www.w3.org/1999/xhtml', [undef, $mode[1]]);
    Whatpm::HTML->set_inner_html ($el, $s, $onerror);
  } else {
    Whatpm::HTML->parse_string ($s => $doc, $onerror);
  }
  $time2 = time;
  $time{parse} = $time2 - $time1;

  print "#document\n";

  my $out;
  if ($mode[2] eq 'html') {
    $time1 = time;
    $out = \( ($el or $doc)->inner_html );
    $time2 = time;
    $time{serialize_html} = $time2 - $time1;
  } elsif ($mode[2] eq 'xml') {
    $doc->manakai_is_html (0);
    $time1 = time;
    $out = \( ($el or $doc)->inner_html );
    $time2 = time;
    $time{serialize_xml} = $time2 - $time1;
    $doc->manakai_is_html (1);
  } else { # test
    require Whatpm::HTML::Dumper;
    $time1 = time;
    $out = \Whatpm::HTML::Dumper::dumptree ($el || $doc);
    $time2 = time;
    $time{serialize_test} = $time2 - $time1;
  }
  print STDOUT Encode::encode ('utf-8', $$out);
  print STDOUT "\n";
} elsif (@mode == 3 and $mode[0] eq 'xml1' and
    ($mode[2] eq 'html' or $mode[2] eq 'test' or $mode[2] eq 'xml')) {
  print STDOUT "Content-Type: text/plain; charset=utf-8\n\n";

  require Encode;
  require Whatpm::XML::Parser;

  $time1 = time;
  $s = Encode::decode ('utf-8', $s);
  $time2 = time;
  $time{decode} = $time2 - $time1;
  
  print STDOUT "#errors\n";

  my $onerror = sub {
    my (%opt) = @_;
    print STDOUT "$opt{line},$opt{column},$opt{type};$opt{level};$opt{value}\n";
  };

  $doc = $dom->create_document;
  $time1 = time;
## TODO:
  #if (length $mode[1]) {
  #  $el = $doc->create_element_ns
  #      ('http://www.w3.org/1999/xhtml', [undef, $mode[1]]);
  #  #Whatpm::HTML->set_inner_html ($el, $s, $onerror);
  #} else {
    Whatpm::XML::Parser->parse_char_string ($s => $doc, $onerror);
  #}
  $time2 = time;
  $time{parse_xml1} = $time2 - $time1;

  print "#document\n";

  my $out;
  if ($mode[2] eq 'html') {
    $doc->manakai_is_html (1);
    $time1 = time;
    $out = \( ($el or $doc)->inner_html );
    $time2 = time;
    $time{serialize_html} = $time2 - $time1;
    $doc->manakai_is_html (0);
  } elsif ($mode[2] eq 'xml') {
    $time1 = time;
    $out = \( ($el or $doc)->inner_html );
    $time2 = time;
    $time{serialize_xml} = $time2 - $time1;
  } else { # test
    require Whatpm::HTML::Dumper;
    $time1 = time;
    $out = \Whatpm::HTML::Dumper::dumptree ($el || $doc);
    $time2 = time;
    $time{serialize_test} = $time2 - $time1;
  }
  print STDOUT Encode::encode ('utf-8', $$out);
  print STDOUT "\n";
} elsif (@mode == 3 and $mode[0] eq 'xhtml' and
         ($mode[2] eq 'html' or $mode[2] eq 'test' or $mode[2] eq 'xml')) {
  print STDOUT "Content-Type: text/plain; charset=utf-8\n\n";

  require Message::DOM::XMLParserTemp;
  print STDOUT "#errors\n";

  my $onerror = sub {
    my $err = shift;
    print STDOUT $err->location->line_number, ",";
    print STDOUT $err->location->column_number, ",";
    print STDOUT $err->text, "\n";
    return 1;
  };

  open my $fh, '<', \$s;
  my $time1 = time;
  $doc = Message::DOM::XMLParserTemp->parse_byte_stream
      ($fh => $dom, $onerror, charset => 'utf-8');
  my $time2 = time;
  $time{parse_xml} = $time2 - $time1;

  print "#document\n";

  my $out;
  if ($mode[2] eq 'html') {
    $doc->manakai_is_html (0);
    $time1 = time;
    $out = \( $doc->inner_html ); ## TODO: $el case
    $time2 = time;
    $time{serialize_html} = $time2 - $time1;
    $doc->manakai_is_html (1);
  } elsif ($mode[2] eq 'xml') {
    $time1 = time;
    $out = \( $doc->inner_html ); ## TODO: $el case
    $time2 = time;
    $time{serialize_xml} = $time2 - $time1;
  } else { # test
    require Whatpm::HTML::Dumper;
    $time1 = time;
    $out = \Whatpm::HTML::Dumper::dumptree ($el || $doc);
    $time2 = time;
    $time{serialize_test} = $time2 - $time1;
  }
  print STDOUT Encode::encode ('utf-8', $$out);
  print STDOUT "\n";
} elsif (@mode == 3 and $mode[0] eq 'swml' and $mode[1] eq '' and
         ($mode[2] eq 'html' or $mode[2] eq 'test' or $mode[2] eq 'xml')) {
  print STDOUT "Content-Type: text/plain; charset=utf-8\n\n";

  require Encode;
  $time1 = time;
  $s = Encode::decode ('utf-8', $s);
  $time2 = time;
  $time{decode} = $time2 - $time1;

  require Whatpm::SWML::Parser;
  $doc = $dom->create_document;
  my $p = Whatpm::SWML::Parser->new;
  $p->parse_char_string ($s => $doc);

  print "#document\n";

  my $out;
  if ($mode[2] eq 'html') {
    $doc->manakai_is_html (0);
    $time1 = time;
    $out = \( $doc->inner_html );
    $time2 = time;
    $time{serialize_html} = $time2 - $time1;
    $doc->manakai_is_html (1);
  } elsif ($mode[2] eq 'xml') {
    $time1 = time;
    $out = \( $doc->inner_html );
    $time2 = time;
    $time{serialize_xml} = $time2 - $time1;
  } else { # test
    require Whatpm::HTML::Dumper;
    $time1 = time;
    $out = \Whatpm::HTML::Dumper::dumptree ($el || $doc);
    $time2 = time;
    $time{serialize_test} = $time2 - $time1;
  }
  print STDOUT Encode::encode ('utf-8', $$out);
  print STDOUT "\n";
} elsif (@mode == 3 and $mode[0] eq 'h2h' and $mode[1] eq '' and
         ($mode[2] eq 'html' or $mode[2] eq 'test' or $mode[2] eq 'xml')) {
  print STDOUT "Content-Type: text/plain; charset=utf-8\n\n";

  require Encode;
  $time1 = time;
  $s = Encode::decode ('utf-8', $s);
  $time2 = time;
  $time{decode} = $time2 - $time1;

  require Whatpm::H2H;
  $doc = $dom->create_document;
  Whatpm::H2H->parse_string ($s => $doc);

  print "#document\n";

  my $out;
  if ($mode[2] eq 'html') {
    $doc->manakai_is_html (0);
    $time1 = time;
    $out = \( $doc->inner_html );
    $time2 = time;
    $time{serialize_html} = $time2 - $time1;
    $doc->manakai_is_html (1);
  } elsif ($mode[2] eq 'xml') {
    $time1 = time;
    $out = \( $doc->inner_html );
    $time2 = time;
    $time{serialize_xml} = $time2 - $time1;
  } else { # test
    require Whatpm::HTML::Dumper;
    $time1 = time;
    $out = \Whatpm::HTML::Dumper::dumptree ($el || $doc);
    $time2 = time;
    $time{serialize_test} = $time2 - $time1;
  }
  print STDOUT Encode::encode ('utf-8', $$out);
  print STDOUT "\n";
} else {
  print STDOUT "Status: 404 Not Found\nContent-Type: text/plain; charset=us-ascii\n\n404";
  exit;
}

  if ($http->get_parameter ('dom5')) {
    require Whatpm::ContentChecker;
    my $onerror = sub {
      my %opt = @_;
      print STDOUT get_node_path ($opt{node}) . ';' . $opt{type} . "\n";
    };
    print STDOUT "#domerrors\n";
    $time1 = time;
    if ($el) {
      Whatpm::ContentChecker->check_element ($el, $onerror);
    } else {
      Whatpm::ContentChecker->check_document ($doc, $onerror);
    }
    $time2 = time;
    $time{check} = $time2 - $time1;
  }

  print STDOUT "#log\n";
  for (qw/decode parse parse_xml parse_xml1
          serialize_html serialize_xml serialize_test
          check/) {
    next unless defined $time{$_};
    print STDOUT {
      decode => 'bytes->chars',
      parse => 'html5(chars)->dom5',
      parse_xml => 'xml(chars)->dom5',
      parse_xml1 => 'xml1(chars)->dom5',
      serialize_html => 'dom5->html5(char)',
      serialize_xml => 'dom5->xml1(char)',
      serialize_test => 'dom5->test(char)',
      check => 'dom5 check',
    }->{$_};
    print STDOUT "\t", $time{$_}, "s\n";
    open my $file, '>>', ".manakai-$_.txt" or die ".manakai-$_.txt: $!";
    print $file $char_length, "\t", $time{$_}, "\n";
  }

exit;

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

Wakaba <wakaba@suikawiki.org>.

=head1 LICENSE

Copyright 2007-2008 Wakaba <wakaba@suikawiki.org>

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

## $Date: 2008/12/11 03:22:57 $

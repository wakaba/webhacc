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

my $mode = $http->get_meta_variable ('PATH_INFO');
## TODO: decode unreserved characters

if ($mode eq '/html' or $mode eq '/test') {
  require Encode;
  require Whatpm::HTML;
  require Whatpm::NanoDOM;

  my $s = $http->get_parameter ('s');
  if (length $s > 1000_000) {
    print STDOUT "Status: 400 Document Too Long\nContent-Type: text/plain; charset=us-ascii\n\nToo long";
    exit;
  }

  my $time1 = time;
  $s = Encode::decode ('utf-8', $s);
  my $time2 = time;
  my %time = (decode => $time2 - $time1);
  my $char_length = length $s;
  
  print STDOUT "Content-Type: text/plain; charset=utf-8\n\n";

  print STDOUT "#errors\n";

  my $onerror = sub {
    my (%opt) = @_;
    print STDOUT "$opt{line},$opt{column},$opt{type}\n";
  };

  $time1 = time;
  my $doc = Whatpm::HTML->parse_string
      ($s => Whatpm::NanoDOM::Document->new, $onerror);
  $time2 = time;
  $time{parse} = $time2 - $time1;

  print "#document\n";

  my $out;
  $time1 = time;
  if ($mode eq '/html') {
    require Whatpm::HTML::Serializer;
    $out = Whatpm::HTML::Serializer->get_inner_html ($doc);
  } else { # test
    $out = test_serialize ($doc);
  }
  $time2 = time;
  $time{serialize} = $time2 - $time1;
  print STDOUT Encode::encode ('utf-8', $$out);
  print STDOUT "\n";

  if ($http->get_parameter ('dom5')) {
    require Whatpm::ContentChecker;
    print STDOUT "#domerrors\n";
    $time1 = time;
    Whatpm::ContentChecker->check_document ($doc, sub {
      my %opt = @_;
      print STDOUT get_node_path ($opt{node}) . ';' . $opt{type} . "\n";
    });
    $time2 = time;
    $time{check} = $time2 - $time1;
  }

  print STDOUT "#log\n";
  print STDOUT "byte->char\t", $time{decode}, "s\n";
  print STDOUT "html5->dom5\t", $time{parse}, "s\n";
  print STDOUT "dom5->serialize\t", $time{serialize}, "s\n";
  print STDOUT "dom5 check\t", $time{check}, "s\n" if defined $time{check};
  for (qw/decode parse serialize check/) {
    next unless defined $time{$_};
    open my $file, '>>', ".$_.txt" or die ".$_.txt: $!";
    print $file $char_length, "\t", $time{$_}, "\n";
  }
} else {
  print STDOUT "Status: 404 Not Found\nContent-Type: text/plain; charset=us-ascii\n\n404";
}

exit;

sub test_serialize ($) {
  my $node = shift;
  my $r = '';

  my @node = map { [$_, ''] } @{$node->child_nodes};
  while (@node) {
    my $child = shift @node;
    my $nt = $child->[0]->node_type;
    if ($nt == $child->[0]->ELEMENT_NODE) {
      $r .= '| ' . $child->[1] . '<' . $child->[0]->tag_name . ">\x0A"; ## ISSUE: case?

      for my $attr (sort {$a->[0] cmp $b->[0]} map { [$_->name, $_->value] }
                    @{$child->[0]->attributes}) {
        $r .= '| ' . $child->[1] . '  ' . $attr->[0] . '="'; ## ISSUE: case?
        $r .= $attr->[1] . '"' . "\x0A";
      }
      
      unshift @node,
        map { [$_, $child->[1] . '  '] } @{$child->[0]->child_nodes};
    } elsif ($nt == $child->[0]->TEXT_NODE) {
      $r .= '| ' . $child->[1] . '"' . $child->[0]->data . '"' . "\x0A";
    } elsif ($nt == $child->[0]->COMMENT_NODE) {
      $r .= '| ' . $child->[1] . '<!-- ' . $child->[0]->data . " -->\x0A";
    } elsif ($nt == $child->[0]->DOCUMENT_TYPE_NODE) {
      $r .= '| ' . $child->[1] . '<!DOCTYPE ' . $child->[0]->name . ">\x0A";
    } else {
      $r .= '| ' . $child->[1] . $child->[0]->node_type . "\x0A"; # error
    }
  }
  
  return \$r;
} # test_serialize

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

Copyright 2007 Wakaba <wakaba@suikawiki.org>

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

## $Date: 2007/11/11 04:18:27 $

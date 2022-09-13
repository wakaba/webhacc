#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use CGI::Carp qw[fatalsToBrowser];

use Message::CGI::HTTP;

my $http = Message::CGI::HTTP->new;

## TODO: _charset_

my $mode = $http->get_meta_variable ('PATH_INFO');
## TODO: decode unreserved characters

if ($mode eq '/table') {
  require Encode;
  require Whatpm::HTML;
  require Whatpm::NanoDOM;

  my $s = $http->get_parameter ('s');
  if (length $s > 1000_000) {
    print STDOUT "Status: 400 Document Too Long\nContent-Type: text/plain; charset=us-ascii\n\nToo long";
    exit;
  }

  $s = Encode::decode ('utf-8', $s);
  my $doc = Whatpm::HTML->parse_string
      ($s => Whatpm::NanoDOM::Document->new);

  my @table_el;
  my @node = @{$doc->child_nodes};
  while (@node) {
    my $node = shift @node;
    if ($node->node_type == 1) {
      if ($node->namespace_uri eq q<http://www.w3.org/1999/xhtml> and
          $node->manakai_local_name eq 'table') {
        push @table_el, $node;
      }
    }
    push @node, @{$node->child_nodes};
  }
  
  print STDOUT "Content-Type: text/html; charset=utf-8\n\n";
  
  use JSON;
  require Whatpm::HTML::Table;

  print STDOUT '<!DOCTYPE html>
<html lang="en">
<head>
<title>HTML5 Table Structure Viewer</title>
<!--[if IE]><script type="text/javascript" src="../excanvas.js"></script><![endif]-->
<script src="../table-script.js" type="text/javascript"></script>
</head>
<body>
<noscript><p>How great if there were no script at all!</p></noscript>
';

  my $i = 0;
  for my $table_el (@table_el) {
    $i++; print STDOUT "<h1>Table $i</h1>\n";

    my $table = Whatpm::HTML::Table->form_table ($table_el);
    Whatpm::HTML::Table->assign_header ($table);

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
          $_->{id} = ''.$_->{element} if defined $_->{element};
          delete $_->{element};
          $_->{is_header} = $_->{is_header} ? 1 : 0;
        }
      }
    }

    print STDOUT '<script type="text/javascript"> 
  tableToCanvas (
';
    print STDOUT objToJson ($table);
    print STDOUT ', document.body, "");
</script>';
  }

  print STDOUT '</body></html>';
} else {
  print STDOUT "Status: 404 Not Found\nContent-Type: text/plain; charset=us-ascii\n\n404";
}

exit;

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

Copyright 2007-2010 Wakaba <w@suika.fam.cx>

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

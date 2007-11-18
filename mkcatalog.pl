#!/usr/bin/perl
use strict;
use encoding 'us-ascii', STDOUT => 'utf-8';

use lib qw[/home/httpd/html/www/markup/html/whatpm
           /home/wakaba/work/manakai2/lib];

my $HTML_NS = q<http://www.w3.org/1999/xhtml>;
my $SRC_NS = q<http://suika.fam.cx/~wakaba/archive/2007/wdcc-desc/>;
my $XML_NS = q<http://www.w3.org/XML/1998/namespace>;

require Message::DOM::DOMImplementation;
my $dom = Message::DOM::DOMImplementation->new;

my $doc;
{
  my $source_file_name = shift or die "$0: No source file specified\n";
  open my $source_file, '<', $source_file_name
      or die "$0: $source_file_name: $!";
  require Message::DOM::XMLParserTemp;
  $doc = Message::DOM::XMLParserTemp->parse_byte_stream
      ($source_file => $dom, undef, charset => 'utf-8');
  $doc->manakai_is_html (1);
}

my $target_lang = 'en';
my @node = (@{$doc->child_nodes});
while (@node) {
  my $node = shift @node;
  if ($node->node_type == $node->ELEMENT_NODE) {
    if ($node->namespace_uri eq $HTML_NS) {
      unshift @node, @{$node->child_nodes};
    } elsif ($node->namespace_uri eq $SRC_NS) {
      if ($node->manakai_local_name eq 'item') {
        my $message;
        for (@{$node->child_nodes}) {
          if ($_->node_type == $_->ELEMENT_NODE and
              $_->namespace_uri eq $SRC_NS) {
            if ($_->manakai_local_name eq 'message') {
              if ($_->get_attribute_ns ($XML_NS, 'lang') eq $target_lang) {
                $message = $_;
                next;
              } else {
                $message ||= $_;
              }
            }
          }
        }

        my $entry = [];
        push @$entry, $node->get_attribute_ns (undef, 'name');
        my $level = $node->get_attribute_ns (undef, 'level');
        $entry->[-1] = $level . ':' . $entry->[-1] if defined $level;
        push @$entry, $node->get_attribute_ns (undef, 'class');
        push @$entry, $message->inner_html;
        s/\s+/ /g for @$entry;
        print join ';', @$entry;
        print "\n";
      } elsif ($node->manakai_local_name eq 'catalog') {
        print $node->text_content, "\n";
      } else {
        warn "$0: ", $node->manakai_local_name, " is not supported\n";
      }
    }
  }
}

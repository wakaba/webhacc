#!/usr/bin/perl
use strict;
use warnings;
use encoding 'us-ascii', STDOUT => 'utf-8';
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules')->subdir ('*')->subdir ('lib');
use Encode;

my $HTML_NS = q<http://www.w3.org/1999/xhtml>;
my $SRC_NS = q<http://suika.fam.cx/~wakaba/archive/2007/wdcc-desc/>;
my $XML_NS = q<http://www.w3.org/XML/1998/namespace>;

require Message::DOM::DOMImplementation;
my $dom = Message::DOM::DOMImplementation->new;

my $doc = $dom->create_document;
{
  my $source_file_name = shift or die "$0: No source file specified\n";
  open my $source_file, '<', $source_file_name
      or die "$0: $source_file_name: $!";
  local $/ = undef;
  $doc->inner_html (decode 'utf-8', <$source_file>);
  $doc->manakai_is_html (1);
}

my $target_lang = shift || 'en';
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
        $_ = defined $_ ? $_ : '' for @$entry;
        s/\s+/ /g for @$entry;
        print join ';', @$entry;
        print "\n";
      } elsif ($node->manakai_local_name eq 'cat') {
        my $name = $node->get_attribute_ns (undef, 'name');
        my $text;
        for my $el (@{$node->child_nodes}) {
          next unless $el->node_type == $el->ELEMENT_NODE;
          next unless $el->manakai_local_name eq 'text';
          my $ns = $el->namespace_uri;
          next unless defined $ns and $ns eq $SRC_NS;
          
          my $lang = $el->get_attribute_ns ($XML_NS, 'lang');
          $text = $el->inner_html;
          if ($lang eq $target_lang) {
            last;
          }          
        }
        if (defined $text) {
          my $entry = [$name, '', $text];
          s/\s+/ /g for @$entry;
          print join ';', @$entry;
          print "\n";
        }
      } else {
        warn "$0: ", $node->manakai_local_name, " is not supported\n";
      }
    }
  }
}

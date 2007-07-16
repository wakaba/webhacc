#!/usr/bin/perl
use strict;
use encoding 'us-ascii', STDOUT => 'utf-8';

use lib qw[/home/httpd/html/www/markup/html/whatpm
           /home/wakaba/work/manakai/lib
           /home/wakaba/public_html/-temp/wiki/lib];

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
      if ($node->manakai_local_name eq 'title') {
        unless ($node->get_attribute_ns ($XML_NS, 'lang') eq $target_lang) {
          $node->parent_node->remove_child ($node);
        }
      } else {
        unshift @node, @{$node->child_nodes};
      }
    } elsif ($node->namespace_uri eq $SRC_NS) {
      if ($node->manakai_local_name eq 'item') {
        my $message;
        my $desc;
        for (@{$node->child_nodes}) {
          if ($_->node_type == $_->ELEMENT_NODE and
              $_->namespace_uri eq $SRC_NS) {
            if ($_->manakai_local_name eq 'desc') {
              if ($_->get_attribute_ns ($XML_NS, 'lang') eq $target_lang) {
                $desc = $_;
                next;
              } else {
                $desc ||= $_;
              }
            } elsif ($_->manakai_local_name eq 'message') {
              if ($_->get_attribute_ns ($XML_NS, 'lang') eq $target_lang) {
                $message = $_;
                next;
              } else {
                $message ||= $_;
              }
            }
          }
        }

        my $name = $node->get_attribute_ns (undef, 'name');
        $name =~ tr/ /-/;
        my $level = $node->get_attribute_ns (undef, 'level');
        $name = $level . ':' . $name if defined $level;
        my $section = $doc->create_element_ns ($HTML_NS, 'div');
        $section->set_attribute_ns
            (undef, class => 'section ' .
                 $node->get_attribute_ns (undef, 'class'));
        $section->set_attribute_ns (undef, id => $name);

        my @message_child = @{$message->child_nodes};
        my $msg = $section->append_child
            ($doc->create_element_ns ($HTML_NS, 'h3'));
        $msg->append_child ($_) for @message_child;

        if ($desc) {
          my @desc_child = @{$desc->child_nodes};
          $section->append_child ($_) for @desc_child;
        }

        $node->parent_node->insert_before ($section, $node);
        $node->parent_node->remove_child ($node); ## TODO: replace_child is not yet implemented
      } elsif ($node->manakai_local_name eq 'catalog') {
        $node->parent_node->remove_child ($node); 
      } else {
        warn "$0: ", $node->manakai_local_name, " is not supported\n";
      }
    }
  }
}
$doc->document_element->set_attribute_ns (undef, lang => $target_lang);

print $doc->inner_html;

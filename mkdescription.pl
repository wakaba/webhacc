#!/usr/bin/perl
use strict;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules')->subdir ('*')->subdir ('lib');
use Encode;

binmode STDOUT, qw(:encoding(utf-8));

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
my $title;
my $title_parent;
while (@node) {
  my $node = shift @node;
  if ($node->node_type == $node->ELEMENT_NODE) {
    if ($node->namespace_uri eq $HTML_NS) {
      if ($node->manakai_local_name eq 'title') {
        $title_parent = $node->parent_node;
        if ($node->get_attribute_ns ($XML_NS, 'lang') eq $target_lang) {
          $title = $node;
        } else {
          $title ||= $node;
          $node->parent_node->remove_child ($node);
        }
      } else {
        unshift @node, @{$node->child_nodes};
      }
    } elsif ($node->namespace_uri eq $SRC_NS) {
      my $ln = $node->manakai_local_name;
      if ($ln eq 'item' or $ln eq 'cat') {
        my $message;
        my $desc;
        my $text;
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
            } elsif ($_->manakai_local_name eq 'text') {
              if ($_->get_attribute_ns ($XML_NS, 'lang') eq $target_lang) {
                $text = $_;
                next;
              } else {
                $text ||= $_;
              }
            }
          }
        }

        if ($ln eq 'item' or $desc) {
          my $name = $node->get_attribute_ns (undef, 'name');
          $name =~ tr/ /-/;
          
          my $section = $doc->create_element_ns ($HTML_NS, 'div');
          $section->set_attribute_ns (undef, class => 'section');
          $section->set_attribute_ns (undef, id => $name);
          
          my $msg = $section->append_child
              ($doc->create_element_ns ($HTML_NS, 'h3'));
          if ($ln eq 'item' and $message) {
            my @message_child = @{$message->child_nodes};
            $msg->append_child ($_) for @message_child;
          } elsif ($ln eq 'cat' and $text) {
            $msg->append_child ($_) for @{$text->child_nodes};
          }
          
          if ($desc) {
            my @desc_child = @{$desc->child_nodes};
            $section->append_child ($_) for @desc_child;
          }
          
          $node->parent_node->insert_before ($section, $node);
        }
        $node->parent_node->remove_child ($node);
      } else {
        warn "$0: ", $node->manakai_local_name, " is not supported\n";
      }
    }
  }
}
$doc->document_element->set_attribute_ns (undef, lang => $target_lang);
$title_parent->append_child ($title) if $title;

print $doc->inner_html;

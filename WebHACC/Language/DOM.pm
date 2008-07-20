package WebHACC::Language::DOM;
use strict;
require WebHACC::Language::Base;
push our @ISA, 'WebHACC::Language::Base';

use Scalar::Util qw[refaddr];

sub generate_structure_dump_section ($) {
  my $self = shift;
  
  my $out = $self->output;

  $out->start_section (id => 'document-tree', title => 'Document Tree',
                       short_title => 'Tree');

  $out->start_tag ('ol', class => 'xoxo');

  my @node = ($self->{structure});
  while (@node) {
    my $child = shift @node;
    unless (ref $child) {
      $out->html ($child);
      next;
    }

    my $node_id = 'node-'.refaddr $child;
    my $nt = $child->node_type;
    if ($nt == $child->ELEMENT_NODE) {
      my $child_nsuri = $child->namespace_uri;
      $out->start_tag ('li', id => $node_id, class => 'tree-element');
      $out->start_tag ('code',
                       title => defined $child_nsuri ? $child_nsuri : '');
      $out->text ($child->tag_name); ## TODO: case
      $out->end_tag ('code');

      if ($child->has_attributes) {
        $out->start_tag ('ul', class => 'attributes');
        for my $attr (sort {$a->[0] cmp $b->[0]} map { [$_->name, $_->value, $_->namespace_uri, 'node-'.refaddr $_] }
                      @{$child->attributes}) {
          $out->start_tag ('li', id => $attr->[3], class => 'tree-attribute');
          $out->start_tag ('code',
                           title => defined $attr->[2] ? $attr->[2] : '');
          $out->html ($attr->[0]); ## ISSUE: case
          $out->end_tag ('code');
          $out->text (' = ');
          $out->start_tag ('q');
          $out->text ($attr->[1]); ## TODO: children
          $out->end_tag ('q');
        }
        $out->end_tag ('ul');
      }

      if ($child->has_child_nodes) {
        $out->start_tag ('ol', class => 'children');
        unshift @node, @{$child->child_nodes}, '</ol></li>';
      }
    } elsif ($nt == $child->TEXT_NODE) {
      $out->start_tag ('li', id => $node_id, class => 'tree-text');
      $out->start_tag ('q', lang => '');
      $out->text ($child->data);
      $out->end_tag ('q');
    } elsif ($nt == $child->CDATA_SECTION_NODE) {
      $out->start_tag ('li', id => $node_id, class => 'tree-cdata');
      $out->start_tag ('code');
      $out->text ('<![CDATA[');
      $out->end_tag ('code');
      $out->start_tag ('q', lang => '');
      $out->text ($child->data);
      $out->end_tag ('q');
      $out->start_tag ('code');
      $out->text (']]>');
      $out->end_tag ('code');
    } elsif ($nt == $child->COMMENT_NODE) {
      $out->start_tag ('li', id => $node_id, class => 'tree-cdata');
      $out->start_tag ('code');
      $out->text ('<!--');
      $out->end_tag ('code');
      $out->start_tag ('q', lang => '');
      $out->text ($child->data);
      $out->end_tag ('q');
      $out->start_tag ('code');
      $out->text ('-->');
      $out->end_tag ('code');
    } elsif ($nt == $child->DOCUMENT_NODE) {
      $out->start_tag ('li', id => $node_id, class => 'tree-document');
      $out->text ('Document');
      $out->start_tag ('ul', class => 'attributes');
      my $cp = $child->manakai_charset;
      if (defined $cp) {
        $out->html (qq[<li><code>charset</code> parameter = <code>]);
        $out->text ($cp);
        $out->html ('</code>');
      }
      $out->html (qq[<li><code>inputEncoding</code> = ]);
      my $ie = $child->input_encoding;
      if (defined $ie) {
        $out->code ($ie);
        if ($child->manakai_has_bom) {
          $out->html (qq[ (with <code class=charname><abbr>BOM</abbr></code>)]);
        }
      } else {
        $out->html (qq[(<code>null</code>)]);
      }
      $out->html (qq[<li>@{[scalar main::get_text ('manakaiIsHTML:'.($child->manakai_is_html?1:0))]}</li>]);
      $out->html (qq[<li>@{[scalar main::get_text ('manakaiCompatMode:'.$child->manakai_compat_mode)]}</li>]);
      unless ($child->manakai_is_html) {
        $out->html (qq[<li>XML version = ]);
        $out->code ($child->xml_version);
        if (defined $child->xml_encoding) {
          $out->html (qq[<li>XML encoding = ]);
          $out->code ($child->xml_encoding);
        } else {
          $out->html (qq[<li>XML encoding = (null)</li>]);
        }
        $out->html (qq[<li>XML standalone = @{[$child->xml_standalone ? 'true' : 'false']}</li>]);
      }
      $out->end_tag ('ul');
      if ($child->has_child_nodes) {
        $out->start_tag ('ol', class => 'children');
        unshift @node, @{$child->child_nodes}, '</ol></li>';
      }
    } elsif ($nt == $child->DOCUMENT_TYPE_NODE) {
      $out->start_tag ('li', id => $node_id, class => 'tree-doctype');
      $out->code ('<!DOCTYPE>');
      $out->start_tag ('ul', class => 'attributes');

      $out->start_tag ('li', class => 'tree-doctype-name');
      $out->text ('Name = ');
      $out->code ($child->name);

      $out->start_tag ('li', class => 'tree-doctype-publicid');
      $out->text ('Public identifier = ');
      $out->code ($child->public_id);

      $out->start_tag ('li', class => 'tree-doctype-systemid');
      $out->text ('System identifier = ');
      $out->code ($child->system_id);

      $out->end_tag ('ul');
    } elsif ($nt == $child->PROCESSING_INSTRUCTION_NODE) {
      $out->start_tag ('li', id => $node_id, class => 'tree-id');
      $out->code ('<?');
      $out->code ($child->target);
      $out->text (' ');
      $out->code ($child->data);
      $out->code ('?>');
    } else { # error
      $out->start_tag ('li', id => $node_id, class => 'tree-unknown');
      $out->text ($child->node_type . ' ' . $child->node_name);
    }
  }
  $out->end_tag ('ol');

  $out->end_section;
} # generate_structure_dump_section

sub generate_structure_error_section ($) {
  my $self = shift;
  
  my $out = $self->output;
  $out->start_section (id => 'document-errors', title => 'Document Errors');
  $out->start_tag ('dl', class => 'document-errors-list');

  my $input = $self->input;
  my $result = $self->result;

  require Whatpm::ContentChecker;
  my $onerror = sub {
    my %opt = @_;
    my ($type, $cls, $msg) = main::get_text ($opt{type}, $opt{level}, $opt{node});
    $type =~ tr/ /-/;
    $type =~ s/\|/%7C/g;
    $out->html (qq[<dt class="$cls">] . $result->get_error_label ($input, \%opt));
    $out->html (qq[<dd class="$cls">] . $result->get_error_level_label (\%opt));
    $out->html ($msg);
    $out->text (' [');
    $out->link ('Description', url => '../error-description#' . $type);
    $out->text (']');
    main::add_error ('structure', \%opt => $result);
  };

  my $onsubdoc = $self->onsubdoc;
  if ($self->{structure}->node_type == $self->{structure}->ELEMENT_NODE) {
    $self->{add_info} = Whatpm::ContentChecker->check_element
        ($self->{structure}, $onerror, $onsubdoc);
  } else {
    $self->{add_info} = Whatpm::ContentChecker->check_document
        ($self->{structure}, $onerror, $onsubdoc);
  }

  $out->end_tag ('dl');
  $out->html (qq[<script>
    addSourceToParseErrorList ('@{[$input->id_prefix]}', 'document-errors-list');
  </script>]);
  $out->end_section;
} # generate_structure_error_section

1;

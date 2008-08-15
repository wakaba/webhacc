package WebHACC::Language::DOM;
use strict;
require WebHACC::Language::Base;
push our @ISA, 'WebHACC::Language::Base';

use Scalar::Util qw[refaddr];

sub generate_structure_dump_section ($) {
  my $self = shift;
  
  my $out = $self->output;

  $out->start_section (role => 'tree');

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
      $out->nl_text ('Document');

      $out->start_tag ('ul', class => 'attributes');
      
      my $cp = $child->manakai_charset;
      if (defined $cp) {
        $out->start_tag ('li');
        $out->nl_text ('manakaiCharset');
        $out->text (' = ');
        $out->code ($cp);
      }
      
      $out->start_tag ('li');
      $out->nl_text ('inputEncoding');
      $out->text (' = ');
      my $ie = $child->input_encoding;
      if (defined $ie) {
        $out->code ($ie);
        if ($child->manakai_has_bom) {
          $out->nl_text ('... with BOM');
        }
      } else {
        $out->html (qq[(<code>null</code>)]);
      }

      $out->start_tag ('li');
      $out->nl_text ('manakaiIsHTML:'.($child->manakai_is_html?1:0));

      $out->start_tag ('li');
      $out->nl_text ('manakaiCompatMode:'.$child->manakai_compat_mode);

      unless ($child->manakai_is_html) {
        $out->start_tag ('li');
        $out->nl_text ('xmlVersion');
        $out->text (' = ');
        $out->code ($child->xml_version);
        
        $out->start_tag ('li');
        $out->nl_text ('xmlEncoding');
        $out->text (' = ');
        if (defined $child->xml_encoding) {
          $out->code ($child->xml_encoding);
        } else {
          $out->html ('(<code>null</code>)');
        }

        $out->start_tag ('li');
        $out->nl_text ('xmlStandalone');
        $out->text (' = ');
        $out->code ($child->xml_standalone ? 'true' : 'false');
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
  $out->start_section (role => 'structure-errors');
  $out->start_error_list (role => 'structure-errors');
  $self->result->layer_applicable ('structure');

  my $input = $self->input;
  my $result = $self->result;

  require Whatpm::ContentChecker;
  my $onerror = sub {
    $result->add_error (layer => 'structure', @_);
  };

  my $onsubdoc = $self->onsubdoc;
  if ($self->{structure}->node_type == $self->{structure}->ELEMENT_NODE) {
    $self->{add_info} = Whatpm::ContentChecker->check_element
        ($self->{structure}, $onerror, $onsubdoc);
  } else {
    $self->{add_info} = Whatpm::ContentChecker->check_document
        ($self->{structure}, $onerror, $onsubdoc);
  }

  $out->end_error_list (role => 'structure-errors');
  $out->end_section;

  $self->result->layer_uncertain ('semantics');
} # generate_structure_error_section

sub generate_additional_sections ($) {
  my $self = shift;
  $self->SUPER::generate_additional_sections;

  $self->generate_table_section;

  $self->generate_listing_section (
      key => 'id', id => 'identifiers',
      short_title => 'IDs', title => 'Identifiers',
  );
  $self->generate_listing_section (
      key => 'term', id => 'terms',
      short_title => 'Terms', title => 'Terms',
  );
  $self->generate_listing_section (
      key => 'class', id => 'classes',
      short_title => 'Classes', title => 'Classes',
  );

  $self->generate_rdf_section;
} # generate_additional_sections

sub generate_table_section ($) {
  my $self = shift;

  my $tables = $self->{add_info}->{table} || [];
  return unless @$tables;

  my $out = $self->output;
  $out->start_section (id => 'tables', short_title => 'Tables',
                       title => 'Tables Section');

  $out->html (q[<!--[if IE]><script type="text/javascript" src="../excanvas.js"></script><![endif]-->
<script src="../table-script.js" type="text/javascript"></script>
<noscript>
<p><em>Structure of tables are visualized here if scripting is enabled.</em></p>
</noscript>]);
  
  require JSON;
  
  my $i = 0;
  for my $table (@$tables) {
    $i++;
    my $index = $out->input->full_subdocument_index;
    $index = $index ? $index . '.' . $i : $i;
    $out->start_section (id => 'table-' . $i,
                         title => 'Table #',
                         text => $index);

    $out->start_tag ('dl');
    $out->dt ('Table Element');
    $out->start_tag ('dd');
    $out->node_link ($table->{element});
    $out->end_tag ('dl');
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
          $_->{id} = refaddr $_->{element} if defined $_->{element};
          delete $_->{element};
          $_->{is_header} = $_->{is_header} ? 1 : 0;
        }
      }
    }

    my $id_prefix = $self->input->id_prefix;
    $out->script (q[tableToCanvas (] .
        JSON::objToJson ($table) .
        q[, document.getElementById ('] . $id_prefix . 'table-' . $i . q[')] .
        q[, '] . $id_prefix . q[');]);

    $out->end_section;
  }

  $out->end_section;
} # generate_table_section

sub generate_listing_section ($%) {
  my $self = shift;
  my %opt = @_;

  my $list = $self->{add_info}->{$opt{key}} || {};
  return unless keys %$list;

  my $out = $self->output;

  $out->start_section (id => $opt{id},
                       title => $opt{title},
                       short_title => $opt{short_title});
  $out->start_tag ('dl');

  for my $id (sort {$a cmp $b} keys %$list) {
    $out->start_tag ('dt');
    $out->code ($id);
    for (@{$list->{$id}}) {
      $out->start_tag ('dd');
      $out->node_link ($_);
    }
  }

  $out->end_tag ('dl');
  $out->end_section;
} # generate_listing_section

my $generate_rdf_resource_html = sub ($$) {
  my ($resource, $out) = @_;

  if (defined $resource->{uri}) {
    $out->url ($resource->{uri});
  } elsif (defined $resource->{bnodeid}) {
    $out->text ('_:' . $resource->{bnodeid});
  } elsif ($resource->{nodes}) {
    $out->text ('(rdf:XMLLiteral)');
  } elsif (defined $resource->{value}) {
    $out->start_tag ('q',
                     lang => defined $resource->{language}
                         ? $resource->{language} : '');
    $out->text ($resource->{value});
    $out->end_tag ('q');

    if (defined $resource->{datatype}) {
      $out->text ('^^');
      $out->url ($resource->{datatype});
    } elsif (length $resource->{language}) {
      $out->text ('@' . $resource->{language});
    }
  } else {
    $out->text ('??'); ## NOTE: An error of the implementation.
  }
}; # $generate_rdf_resource_html

## TODO: Should we move this method to another module,
## such as Base or RDF?
sub generate_rdf_section ($) {
  my $self = shift;

  my $list = $self->{add_info}->{rdf} || [];
  return unless @$list;

  my $out = $self->output;
  $out->start_section (id => 'rdf', short_title => 'RDF',
                       title => 'RDF Triples');
  $out->start_tag ('dl');

  my $i = 0;
  for my $rdf (@$list) {
    $out->start_tag ('dt', id => 'rdf-' . $i++);
    $out->node_link ($rdf->[0]);
    $out->start_tag ('dd');
    $out->start_tag ('dl');
    for my $triple (@{$rdf->[1]}) {
      $out->start_tag ('dt');
      $out->node_link ($triple->[0]);
      $out->start_tag ('dd');
      $out->nl_text ('Subject');
      $out->text (': ');
      $generate_rdf_resource_html->($triple->[1] => $out);
      $out->start_tag ('dd');
      $out->nl_text ('Predicate');
      $out->text (': ');
      $generate_rdf_resource_html->($triple->[2] => $out);
      $out->start_tag ('dd');
      $out->nl_text ('Object');
      $out->text (': ');
      $generate_rdf_resource_html->($triple->[3] => $out);
    }
    $out->end_tag ('dl');
  }
  $out->end_tag ('dl');
  $out->end_section;
} # generate_rdf_section

1;

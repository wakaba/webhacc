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
  $out->start_section (role => 'structure-errors');
  $out->start_error_list (role => 'structure-errors');

  my $input = $self->input;
  my $result = $self->result;

  require Whatpm::ContentChecker;
  my $onerror = sub {
    $result->add_error (@_, layer => 'structure');
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
} # generate_structure_error_section

sub generate_additional_sections ($) {
  my $self = shift;
  $self->SUPER::generate_additional_sections;
  $self->generate_table_section;
} # generate_additional_sections

sub generate_table_section ($) {
  my $self = shift;

  my $tables = $self->{add_info}->{table} || [];
  return unless @$tables;

  my $out = $self->output;
  $out->start_section (id => 'tables', title => 'Tables');

  $out->html (q[<!--[if IE]><script type="text/javascript" src="../excanvas.js"></script><![endif]-->
<script src="../table-script.js" type="text/javascript"></script>
<noscript>
<p><em>Structure of tables are visualized here if scripting is enabled.</em></p>
</noscript>]);
  
  require JSON;
  
  my $i = 0;
  for my $table (@$tables) {
    $i++;
    $out->start_section (id => 'table-' . $i,
                         title => 'Table #' . $i);

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
} # print_table_section

sub print_listing_section ($$$) {
  my ($opt, $input, $ids) = @_;
  
#  push @nav, ['#' . $input->{id_prefix} . $opt->{id} => $opt->{label}]
#      unless $input->{nested};
  print STDOUT qq[
<div id="$input->{id_prefix}$opt->{id}" class="section">
<h2>$opt->{heading}</h2>

<dl>
];
  for my $id (sort {$a cmp $b} keys %$ids) {
    print STDOUT qq[<dt><code>@{[htescape $id]}</code></dt>];
    for (@{$ids->{$id}}) {
      print STDOUT qq[<dd>].get_node_link ($input, $_).qq[</dd>];
    }
  }
  print STDOUT qq[</dl></div>];
} # print_listing_section


sub print_rdf_section ($$$) {
  my ($input, $rdfs) = @_;
  
#  push @nav, ['#' . $input->{id_prefix} . 'rdf' => 'RDF']
#      unless $input->{nested};
  print STDOUT qq[
<div id="$input->{id_prefix}rdf" class="section">
<h2>RDF Triples</h2>

<dl>];
  my $i = 0;
  for my $rdf (@$rdfs) {
    print STDOUT qq[<dt id="$input->{id_prefix}rdf-@{[$i++]}">];
    print STDOUT get_node_link ($input, $rdf->[0]);
    print STDOUT qq[<dd><dl>];
    for my $triple (@{$rdf->[1]}) {
      print STDOUT '<dt>' . get_node_link ($input, $triple->[0]) . '<dd>';
      print STDOUT get_rdf_resource_html ($triple->[1]);
      print STDOUT ' ';
      print STDOUT get_rdf_resource_html ($triple->[2]);
      print STDOUT ' ';
      print STDOUT get_rdf_resource_html ($triple->[3]);
    }
    print STDOUT qq[</dl>];
  }
  print STDOUT qq[</dl></div>];
} # print_rdf_section

sub get_rdf_resource_html ($) {
  my $resource = shift;
  if (defined $resource->{uri}) {
    my $euri = htescape ($resource->{uri});
    return '<code class=uri>&lt;<a href="' . $euri . '">' . $euri .
        '</a>></code>';
  } elsif (defined $resource->{bnodeid}) {
    return htescape ('_:' . $resource->{bnodeid});
  } elsif ($resource->{nodes}) {
    return '(rdf:XMLLiteral)';
  } elsif (defined $resource->{value}) {
    my $elang = htescape (defined $resource->{language}
                              ? $resource->{language} : '');
    my $r = qq[<q lang="$elang">] . htescape ($resource->{value}) . '</q>';
    if (defined $resource->{datatype}) {
      my $euri = htescape ($resource->{datatype});
      $r .= '^^<code class=uri>&lt;<a href="' . $euri . '">' . $euri .
          '</a>></code>';
    } elsif (length $resource->{language}) {
      $r .= '@' . htescape ($resource->{language});
    }
    return $r;
  } else {
    return '??';
  }
} # get_rdf_resource_html

1;

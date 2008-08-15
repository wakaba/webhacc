package WebHACC::Result;
use strict;

sub new ($) {
  return bless {
    global_status => 'conforming',
        # or, 'should-error', 'non-conforming', 'uncertain'
    subdoc_results => [],
  }, shift;
} # new

sub output ($;$) {
  if (@_ > 1) {
    if (defined $_[1]) {
      $_[0]->{output} = $_[1];
    } else {
      delete $_[0]->{output};
    }
  }

  return $_[0]->{output};
} # output

sub parent_result ($;$) {
  if (@_ > 1) {
    if (defined $_[1]) {
      $_[0]->{parent_result} = $_[1];
    } else {
      delete $_[0]->{parent_result};
    }
  }

  return $_[0]->{parent_result};
} # parent_result

sub layer_applicable ($$) {
  my $self = shift;
  my $layer = shift;
  $self->{layers}->{$layer}->{applicable} = 1;
} # layer_applicable

sub layer_uncertain ($$) {
  my $self = shift;
  my $layer = shift;
  $self->{layers}->{$layer}->{uncertain} ||= 1;
  $self->{layers}->{$layer}->{applicable} = 1;
  $self->{global_status} = 'uncertain'
      unless $self->{global_status} eq 'non-conforming';
} # layer_uncertain

sub add_error ($%) {
  my ($self, %opt) = @_;

  my $out = $self->output;
  $out->has_error (1);

  my $error_level = $opt{level};
  if (not defined $error_level) {
    $error_level = 'm'; ## NOTE: Unknown - an error of the implementation
  } elsif ({
    m => 1, s => 1, w => 1, i => 1, u => 1,
  }->{$error_level}) {
    #
  } else {
    $error_level = 'm'; ## NOTE: Unknown - an error of the implementation
  }

  my $error_layer = $opt{layer};
  if (not defined $error_layer) {
    $error_layer = 'syntax'; ## NOTE: Unknown - an error of the implementation
  } elsif ({
    transfer => 1,
    encode => 1,
    charset => 1,
    syntax => 1,
    structure => 1,
    semantics => 1,
  }->{$error_layer}) {
    #
  } else {
    $error_layer = 'syntax'; ## NOTE: Unknown - an error of the implementation
  }

  my $class = qq[level-$error_level layer-$error_layer];
 
  ## Line & column numbers (prepare values)

  my $line;
  my $column;
    
  if (defined $opt{node}) {
    $line = $opt{node}->get_user_data ('manakai_source_line');
    if (defined $line) {
      $column = $opt{node}->get_user_data ('manakai_source_column');
    } elsif ($opt{node}->isa ('Message::IF::Node')) {
      if ($opt{node}->node_type == $opt{node}->ATTRIBUTE_NODE) {
        my $owner = $opt{node}->owner_element;
        if ($owner) {
          $line = $owner->get_user_data ('manakai_source_line');
          $column = $owner->get_user_data ('manakai_source_column');
        }
      } else {
        my $parent = $opt{node}->parent_node;
        if ($parent) {
          $line = $parent->get_user_data ('manakai_source_line');
          $column = $parent->get_user_data ('manakai_source_column');
        }
      }
    }
  }
  unless (defined $line) {
    if (defined $opt{token} and defined $opt{token}->{line}) {
      $line = $opt{token}->{line};
      $column = $opt{token}->{column};
    } elsif (defined $opt{line}) {
      $line = $opt{line};
      $column = $opt{column};
    }
  }
  $line = $line - 1 || 1
      if defined $line and not (defined $column and $column > 0);

  $out->start_tag ('dt', class => $class,
                   'data-type' => $opt{type},
                   'data-level' => $error_level,
                   'data-layer' => $error_layer,
                   ($line ? ('data-line' => $line) : ()),
                   ($column ? ('data-column' => $column) : ()));
  my $has_location;

  ## URL
  
  if (defined $opt{url}) {
    $out->url ($opt{url});
    $has_location = 1;
  }

  ## Line & column numbers (real output)
 
  if (defined $line) {
    if (defined $column and $column > 0) {
      $out->xref ('Line #', text => $line, target => 'line-' . $line);
      $out->text (' ');
      $out->nl_text ('column #', text => $column);
    } else {
      $out->xref ('Line #', text => $line, target => 'line-' . $line);
    }
    $has_location = 1;
  }

  ## Node path

  if (defined $opt{node}) {
    $out->html (' ');
    $out->node_link ($opt{node});
    $has_location = 1;
  }

  if (defined $opt{index}) {
    if ($opt{index_has_link}) {
      $out->html (' ');
      $out->xref ('Index #', text => (0+$opt{index}),
                  target => 'index-' . (0+$opt{index}));
    } else {
      $out->html (' ');
      $out->nl_text ('Index #', text => (0+$opt{index}));
    }
    $has_location = 1;
  }

  if (defined $opt{value}) {
    $out->html (' ');
    $out->code ($opt{value});
    $has_location = 1;
  }

  unless ($has_location) {
    if (defined $opt{input}) {
      if (defined $opt{input}->{container_node}) {
        my $original_input = $out->input;
        $out->input ($opt{input}->{parent_input});
        $out->node_link ($opt{input}->{container_node});
        $out->input ($original_input);
        $has_location = 1;
      } elsif (defined $opt{input}->{request_uri}) {
        $out->url ($opt{input}->{request_uri});
        $has_location = 1;
      } elsif (defined $opt{input}->{uri}) {
        $out->url ($opt{input}->{uri});
        $has_location = 1;
      }
    }
    
    unless ($has_location) {
      $out->nl_text ('Unknown location');
    }
  }
 
  $out->start_tag ('dd', class => $class);

  ## Error level
  $out->nl_text ('Error level ' . $error_level);
  $out->text (': ');
  
  ## Error message
  my $error_type_text = $opt{type};
  $out->nl_text ($error_type_text, node => $opt{node}, text => $opt{text});

  ## Additional error description
  if (defined $opt{text}) { ## TODO: Remove this block once all errors are put into the catalog.
    $out->html (' (<q>');
    $out->text ($opt{text});
    $out->html ('</q>)');
  }
  
  ## Link to a long description

  my $fragment = $opt{type};
  $fragment =~ tr/ /-/;
  $fragment = $out->encode_url_component ($fragment);
  $out->text (' [');
  $out->link ('Description', url => '../error-description#' . $fragment,
              rel => 'help');
  $out->text (']');

  if ($error_level eq 'm') {
    $self->{layers}->{$error_layer}->{must}++;
    $self->{global_status} = 'non-conforming';
  } elsif ($error_level eq 's') {
    $self->{layers}->{$error_layer}->{should}++;
    $self->{global_status} = 'should-error'
        unless {'non-conforming' => 1, 
                uncertain => 1}->{$self->{global_status}};
  } elsif ($error_level eq 'w') {
    $self->{layers}->{$error_layer}->{warning}++;
  } elsif ($error_level eq 'u') {
    $self->{layers}->{$error_layer}->{uncertain}++;
    $self->{global_status} = 'uncertain'
        unless $self->{global_status} eq 'non-conforming';
  } elsif ($error_level eq 'i') {
    $self->{layers}->{$error_layer}->{info}++;
  }
} # add_error

sub generate_result_section ($) {
  my $self = shift;

  my $result = $self;

  my $out = $result->output;

  $out->start_section (role => 'result');

  my $para_class = {
    'conforming' => 'result-para no-error',
    'should-error' => 'result-para should-errors',
    'non-conforming' => 'result-para must-errors',
    'uncertain' => 'result-para uncertain',
  }->{$self->{global_status}};
  $out->start_tag ('p', class => $para_class);
  $out->nl_text ('Conformance is ' . $self->{global_status});
  $out->end_tag ('p');

  $out->html (qq[<table>
<colgroup><col><col><colgroup><col><col><col><col><colgroup><col>
<thead>
<tr><th scope=col colspan=2>]);
  for ('Error level m', 'Error level s', 'Error level w',
       'Error level i', 'Score') {
    $out->start_tag ('th');
    $out->nl_text ($_);
  }

  my $maindoc_status = {must => 0, should => 0, warning => 0, info => 0,
                        uncertain => 0, applicable => 1};
  my $subdocs_status = {must => 0, should => 0, warning => 0, info => 0,
                        uncertain => 0, applicable => 1};
  my $global_status = {must => 0, should => 0, warning => 0, info => 0,
                       uncertain => 0, applicable => 1};

  my $score_unit = 2;

  my @row = (
    sub {
      $out->start_tag ('tbody');
      $out->start_tag ('tr');
      $out->start_tag ('th', colspan => 7, scope => 'col');
      $out->nl_text ('Main document');
    },
      {label => 'Transfer L.', status => $self->{layers}->{transfer},
       target => 'transfer-errors', score_base => 20,
       parent_status => $maindoc_status},
      {label => 'Encode L.', status => $self->{layers}->{encode},
       target => 'parse-errors', score_base => 10,
       parent_status => $maindoc_status},
      {label => 'Char L.', status => $self->{layers}->{charset},
       score_base => 10,
       parent_status => $maindoc_status},
      {label => 'Syntax L.', status => $self->{layers}->{syntax},
       target => 'parse-errors', score_base => 20,
       parent_status => $maindoc_status},
      {label => 'Structure L.', status => $self->{layers}->{structure},
       target => 'document-errors', score_base => 20,
       parent_status => $maindoc_status},
      {label => 'Semantics L.', status => $self->{layers}->{semantics},
       score_base => 20,
       parent_status => $maindoc_status},
  );

  if (@{$self->{subdoc_results}}) {
    push @row, {label => 'Subtotal', status => $maindoc_status,
                score_base => 100,
                parent_status => $global_status, is_total => 1};
    push @row, sub {
      $out->start_tag ('tbody');
      $out->start_tag ('tr');
      $out->start_tag ('th', colspan => 7, scope => 'col');
      $out->nl_text ('Subdocuments');
    };
    for (@{$self->{subdoc_results}}) {
      push @row, {label => '#' . $_->{input}->full_subdocument_index,
                  status => $_,
                  target => $_->{input}->id_prefix . 'result-summary',
                  score_base => 100, parent_status => $subdocs_status};
    }
    push @row, {label => 'Subtotal', status => $subdocs_status,
                score_base => 100 * @{$self->{subdoc_results}},
                parent_status => $global_status, is_total => 1};
  } else {
    $global_status = $maindoc_status;
  }

  push @row, sub {
    $out->start_tag ('tfoot');
  };
  push @row, {label => 'Total', status => $global_status,
              score_base => 100 * (@{$self->{subdoc_results}} + 1),
              parent_status => {}, is_total => 1};

  for my $x (@row) {
    if (ref $x eq 'CODE') {
      $x->();
      next;
    }

    $x->{parent_status}->{$_} += $x->{status}->{$_}
        for qw/must should warning info uncertain/;

    my $row_class = $x->{status}->{uncertain} ? 'uncertain' : '';
    $row_class .= ' total' if $x->{is_total};
    $out->start_tag ('tr', class => $row_class);
    my $uncertain = $x->{status}->{uncertain} ? '?' : '';

    $out->start_tag ('td', class => 'subrow') unless $x->{is_total};

    ## Layer name
    $out->start_tag ('th', colspan => $x->{is_total} ? 2 : 1,
                     scope => 'row');
    if (defined $x->{target} and
        ($x->{status}->{must} or $x->{status}->{should} or
         $x->{status}->{warning} or $x->{status}->{info} or
         $x->{status}->{uncertain})) {
      $out->xref ($x->{label}, target => $x->{target});
    } else {
      $out->nl_text ($x->{label});
    }

    ## MUST-level errors
    $out->start_tag ('td', class => $x->{status}->{must} ? 'must-errors' : '');
    if ($x->{status}->{applicable}) {
      $out->text (($x->{status}->{must} or 0) . $uncertain);
    } else {
      $out->nl_text ('N/A');
    }

    ## SHOULD-level errors
    $out->start_tag ('td',
                     class => $x->{status}->{should} ? 'should-errors' : '');
    if ($x->{status}->{applicable}) {
      $out->text (($x->{status}->{should} or 0) . $uncertain);
    } else {
      $out->nl_text ('N/A');
    }

    ## Warnings
    $out->start_tag ('td', class => $x->{status}->{warning} ? 'warnings' : '');
    if ($x->{status}->{applicable}) {
      $out->text (($x->{status}->{warning} or 0) . $uncertain);
    } else {
      $out->nl_text ('N/A');
    }

    ## Informations
    $out->start_tag ('td', class => $x->{status}->{info} ? 'infos' : '');
    if ($x->{status}->{applicable}) {
      $out->text (($x->{status}->{info} or 0) . $uncertain);
    } else {
      $out->nl_text ('N/A');
    }

    ## Score
    $out->start_tag ('td',
                     class => $x->{status}->{must} ? 'score must-errors' :
                              $x->{status}->{should} ? 'score should-errors' :
                              'score');
    
    my $max_score = $x->{score_base};
    $max_score -= $x->{status}->{must} * $score_unit;
    my $min_score = $max_score;
    $min_score -= $x->{status}->{should} * $score_unit;

    $out->start_tag ('strong');
    if ($x->{status}->{uncertain}) {
      $out->html ('&#x2212;&#x221E; '); # negative inifinity
      $out->nl_text ('...');
      $out->html ($max_score < 0 ?
                  ' &#x2212;' . substr ($max_score, 1) : ' ' . $max_score);
    } elsif ($min_score != $max_score) {
      $out->html ($min_score < 0 ?
                  '&#x2212;' . substr ($min_score, 1) . ' ': $min_score . ' ');
      $out->nl_text ('...');
      $out->html ($max_score < 0 ?
                  ' &#x2212;' . substr ($max_score, 1) : ' ' . $max_score);
    } else {
      $out->html ($max_score < 0 ?
                  '&#x2212;' . substr ($max_score, 1) : $max_score);
    }
    $out->end_tag ('strong');

    $out->text (' / ' . $x->{score_base});
  }
  
  $out->end_tag ('table');

  my $parent = $self->parent_result;
  if ($parent) {
    $global_status->{input} = $out->input;
    push @{$parent->{subdoc_results}}, $global_status;
  }

  $out->nl_text ('This checker is work in progress.');
  $out->end_section;
} # generate_result_section

1;

package WebHACC::Result;
use strict;

sub new ($) {
  return bless {}, shift;
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

sub add_error ($%) {
  my ($self, %opt) = @_;

  my $out = $self->output;

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

  my $error_type_text = $opt{type};

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
      $out->text ('Unknown location');
    }
  }
 
  $out->start_tag ('dd', class => $class);

  ## Error level
  
  if ($error_level eq 'm') {
    $out->html (qq[<strong><a href="../error-description#level-m"><em class=rfc2119>MUST</em>-level
        error</a></strong>: ]);
  } elsif ($error_level eq 's') {
    $out->html (qq[<strong><a href="../error-description#level-s"><em class=rfc2119>SHOULD</em>-level
        error</a></strong>: ]);
  } elsif ($error_level eq 'w') {
    $out->html (qq[<strong><a href="../error-description#level-w">Warning</a></strong>: ]);
  } elsif ($error_level eq 'u') {
    $out->html (qq[<strong><a href="../error-description#level-u">Not
        supported</a></strong>: ]);
  } elsif ($error_level eq 'i') {
    $out->html (qq[<strong><a href="../error-description#level-i">Information</a></strong>: ]);
  }

  ## Error message

  $out->nl_text ($error_type_text, node => $opt{node}, text => $opt{text});

  ## Additional error description

  if (defined $opt{text}) {
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


#    my ($type, $cls, $msg) = main::get_text ($opt{type}, $opt{level});
#    $out->html (qq[<dt class="$cls">] . $result->get_error_label ($input, \%opt));

  $error_layer = 'char'
      if $error_layer eq 'charset' or $error_layer eq 'encode';
  if ($error_level eq 's') {
    $self->{$error_layer}->{should}++;
    $self->{$error_layer}->{score_min} -= 2;
    $self->{conforming_min} = 0;
  } elsif ($error_level eq 'w') {
    $self->{$error_layer}->{warning}++;
  } elsif ($error_level eq 'u') {
    $self->{$error_layer}->{unsupported}++;
    $self->{unsupported} = 1;
  } elsif ($error_level eq 'i') {
    #
  } else {
    $self->{$error_layer}->{must}++;
    $self->{$error_layer}->{score_max} -= 2;
    $self->{$error_layer}->{score_min} -= 2;
    $self->{conforming_min} = 0;
    $self->{conforming_max} = 0;
  }
} # add_error

sub generate_result_section ($) {
  my $result = shift;

  my $out = $result->output;

  $out->start_section (id => 'result-summary',
                       title => 'Result');

  if ($result->{unsupported} and $result->{conforming_max}) {  
    $out->html (qq[<p class=uncertain id=result-para>The conformance
        checker cannot decide whether the document is conforming or
        not, since the document contains one or more unsupported
        features.  The document might or might not be conforming.</p>]);
  } elsif ($result->{conforming_min}) {
    $out->html (qq[<p class=PASS id=result-para>No conformance-error is
        found in this document.</p>]);
  } elsif ($result->{conforming_max}) {
    $out->html (qq[<p class=SEE-RESULT id=result-para>This document
        is <strong>likely <em>non</em>-conforming</strong>, but in rare case
        it might be conforming.</p>]);
  } else {
    $out->html (qq[<p class=FAIL id=result-para>This document is 
        <strong><em>non</em>-conforming</strong>.</p>]);
  }

  $out->html (qq[<table>
<colgroup><col><colgroup><col><col><col><colgroup><col>
<thead>
<tr><th scope=col></th>
<th scope=col><a href="../error-description#level-m"><em class=rfc2119>MUST</em>-level
Errors</a></th>
<th scope=col><a href="../error-description#level-s"><em class=rfc2119>SHOULD</em>-level
Errors</a></th>
<th scope=col><a href="../error-description#level-w">Warnings</a></th>
<th scope=col>Score</th></tr></thead><tbody>]);

  ## TODO: Introduce "N/A" value (e.g. Character layer is not applicable
  ## to binary formats)

  my $must_error = 0;
  my $should_error = 0;
  my $warning = 0;
  my $score_min = 0;
  my $score_max = 0;
  my $score_base = 20;
  my $score_unit = $score_base / 100;
  for (
    [Transfer => 'transfer', ''],
    [Character => 'char', ''],
    [Syntax => 'syntax', '#parse-errors'],
    [Structure => 'structure', '#document-errors'],
  ) {
    $must_error += ($result->{$_->[1]}->{must} += 0);
    $should_error += ($result->{$_->[1]}->{should} += 0);
    $warning += ($result->{$_->[1]}->{warning} += 0);
    $score_min += (($result->{$_->[1]}->{score_min} *= $score_unit) += $score_base);
    $score_max += (($result->{$_->[1]}->{score_max} *= $score_unit) += $score_base);

    my $uncertain = $result->{$_->[1]}->{unsupported} ? '?' : '';
    my $label = $_->[0];
    if ($result->{$_->[1]}->{must} or
        $result->{$_->[1]}->{should} or
        $result->{$_->[1]}->{warning} or
        $result->{$_->[1]}->{unsupported}) {
      $label = qq[<a href="$_->[2]">$label</a>];
    }

    $out->html (qq[<tr class="@{[$uncertain ? 'uncertain' : '']}"><th scope=row>$label</th><td class="@{[$result->{$_->[1]}->{must} ? 'FAIL' : '']}">$result->{$_->[1]}->{must}$uncertain</td><td class="@{[$result->{$_->[1]}->{should} ? 'SEE-RESULT' : '']}">$result->{$_->[1]}->{should}$uncertain</td><td>$result->{$_->[1]}->{warning}$uncertain</td>]);
    if ($uncertain) {
      $out->html (qq[<td class="@{[$result->{$_->[1]}->{must} ? 'FAIL' : $result->{$_->[1]}->{should} ? 'SEE-RESULT' : '']}">&#x2212;&#x221E;..$result->{$_->[1]}->{score_max}]);
    } elsif ($result->{$_->[1]}->{score_min} != $result->{$_->[1]}->{score_max}) {
      $out->html (qq[<td class="@{[$result->{$_->[1]}->{must} ? 'FAIL' : 'SEE-RESULT']}">$result->{$_->[1]}->{score_min}..$result->{$_->[1]}->{score_max}]);
    } else {
      $out->html (qq[<td class="@{[$result->{$_->[1]}->{must} ? 'FAIL' : '']}">$result->{$_->[1]}->{score_min}]);
    }
    $out->html (qq[ / 20]);
  }

  $score_max += $score_base;

  $out->html (qq[
<tr class=uncertain><th scope=row>Semantics</th><td>0?</td><td>0?</td><td>0?</td><td>&#x2212;&#x221E;..$score_base / 20
</tbody>
<tfoot><tr class=uncertain><th scope=row>Total</th>
<td class="@{[$must_error ? 'FAIL' : '']}">$must_error?</td>
<td class="@{[$should_error ? 'SEE-RESULT' : '']}">$should_error?</td>
<td>$warning?</td>
<td class="@{[$must_error ? 'FAIL' : $should_error ? 'SEE-RESULT' : '']}"><strong>&#x2212;&#x221E;..$score_max</strong> / 100
</table>

<p><strong>Important</strong>: This conformance checking service
is <em>under development</em>.  The result above might be <em>wrong</em>.</p>]);
  $out->end_section;
} # generate_result_section

1;

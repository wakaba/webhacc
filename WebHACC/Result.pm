package WebHACC::Result;
use strict;

sub new ($) {
  return bless {}, shift;
} # new


sub get_error_label ($$) {
  my $self = shift;
  my ($input, $err) = @_;

  my $r = '';

  my $line;
  my $column;
    
  if (defined $err->{node}) {
    $line = $err->{node}->get_user_data ('manakai_source_line');
    if (defined $line) {
      $column = $err->{node}->get_user_data ('manakai_source_column');
    } else {
      if ($err->{node}->node_type == $err->{node}->ATTRIBUTE_NODE) {
        my $owner = $err->{node}->owner_element;
        $line = $owner->get_user_data ('manakai_source_line');
        $column = $owner->get_user_data ('manakai_source_column');
      } else {
        my $parent = $err->{node}->parent_node;
        if ($parent) {
          $line = $parent->get_user_data ('manakai_source_line');
          $column = $parent->get_user_data ('manakai_source_column');
        }
      }
    }
  }
  unless (defined $line) {
    if (defined $err->{token} and defined $err->{token}->{line}) {
      $line = $err->{token}->{line};
      $column = $err->{token}->{column};
    } elsif (defined $err->{line}) {
      $line = $err->{line};
      $column = $err->{column};
    }
  }
 
  if (defined $line) {
    if (defined $column and $column > 0) {
      $r = qq[<a href="#$input->{id_prefix}line-$line">Line $line</a> column $column];
    } else {
      $line = $line - 1 || 1;
      $r = qq[<a href="#$input->{id_prefix}line-$line">Line $line</a>];
    }
  }

  if (defined $err->{node}) {
    $r .= ' ' if length $r;
    $r .= $self->get_node_link ($input, $err->{node});
  }

  if (defined $err->{index}) {
    if (length $r) {
      $r .= ', Index ' . (0+$err->{index});
    } else {
      $r .= "<a href='#$input->{id_prefix}index-@{[0+$err->{index}]}'>Index "
          . (0+$err->{index}) . '</a>';
    }
  }

  if (defined $err->{value}) {
    $r .= ' ' if length $r; ## BUG: v must be escaped
    $r .= '<q><code>' . ($err->{value}) . '</code></q>';
  }

  return $r;
} # get_error_label

sub get_error_level_label ($) {
  my $self = shift;
  my $err = shift;

  my $r = '';

  if (not defined $err->{level} or $err->{level} eq 'm') {
    $r = qq[<strong><a href="../error-description#level-m"><em class=rfc2119>MUST</em>-level
        error</a></strong>: ];
  } elsif ($err->{level} eq 's') {
    $r = qq[<strong><a href="../error-description#level-s"><em class=rfc2119>SHOULD</em>-level
        error</a></strong>: ];
  } elsif ($err->{level} eq 'w') {
    $r = qq[<strong><a href="../error-description#level-w">Warning</a></strong>:
        ];
  } elsif ($err->{level} eq 'u' or $err->{level} eq 'unsupported') {
    $r = qq[<strong><a href="../error-description#level-u">Not
        supported</a></strong>: ];
  } elsif ($err->{level} eq 'i') {
    $r = qq[<strong><a href="../error-description#level-i">Information</a></strong>: ];
  } else {
    my $elevel = htescape ($err->{level});
    $r = qq[<strong><a href="../error-description#level-$elevel">$elevel</a></strong>:
        ];
  }

  return $r;
} # get_error_level_label

sub get_node_path ($) {
  my $self = shift;
  my $node = shift;
  my @r;
  while (defined $node) {
    my $rs;
    if ($node->node_type == 1) {
      $rs = $node->node_name;
      $node = $node->parent_node;
    } elsif ($node->node_type == 2) {
      $rs = '@' . $node->node_name;
      $node = $node->owner_element;
    } elsif ($node->node_type == 3) {
      $rs = '"' . $node->data . '"';
      $node = $node->parent_node;
    } elsif ($node->node_type == 9) {
      @r = ('') unless @r;
      $rs = '';
      $node = $node->parent_node;
    } else {
      $rs = '#' . $node->node_type;
      $node = $node->parent_node;
    }
    unshift @r, $rs;
  }
  return join '/', @r;
} # get_node_path

use Scalar::Util qw/refaddr/;

sub get_node_link ($$) {
  my $self = shift;
  return qq[<a href="#$_[0]->{id_prefix}node-@{[refaddr $_[1]]}">] .
       ($self->get_node_path ($_[1])) . qq[</a>];
        ## BUG: ^ must be escaped
} # get_node_link

1;

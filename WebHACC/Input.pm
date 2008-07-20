package WebHACC::Input;
use strict;

sub new ($) {
  return bless {id_prefix => ''}, shift;
} # new

sub id_prefix ($;$) {
  if (@_ > 1) {
    if (defined $_[1]) {
      $_[0]->{id_prefix} = ''.$_[1];
    } else {
      $_[0]->{id_prefix} = '';
    }
  }

  return $_[0]->{id_prefix};
} # id_prefix

sub nested ($;$) {
  if (@_ > 1) {
    if ($_[1]) {
      $_[0]->{nested} = 1;
    } else {
      delete $_[0]->{nested};
    }
  }

  return $_[0]->{nested};
} # nested

1;

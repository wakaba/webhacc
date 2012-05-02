package test::WebHACC::Language::WebVTT;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->subdir ('lib')->stringify;
use Test::WebHACC::Default;
use base qw(Test::Class);
use Test::More;

sub _use : Test(1) {
  use_ok 'WebHACC::Language::WebVTT';
} # _use

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

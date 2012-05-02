package Test::WebHACC::Default;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->parent->parent->subdir ('modules', '*', 'lib')->stringify;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

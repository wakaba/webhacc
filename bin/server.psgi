# -*- perl -*-
use strict;
use warnings;
use Wanage::HTTP;
use Warabe::App;

$ENV{LANG} = 'C';
$ENV{TZ} = 'UTC';

return sub {
  delete $SIG{CHLD} if defined $SIG{CHLD} and not ref $SIG{CHLD}; # XXX

  my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
  my $app = Warabe::App->new_from_http ($http);

  return $app->execute_by_promise (sub {
    my $path = $app->path_segments;

    return $app->send_redirect
        ('https://suika.suikawiki.org/gate/2007/html' . $app->http->url->{path} . (defined $app->http->url->{query} ? '?' . $app->http->url->{query} : ''),
         status => 301);
  });
};

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# -*- perl -*-
use strict;
use warnings;
use Path::Tiny;
use Wanage::URL;
use Wanage::HTTP;
use Warabe::App;
use Promised::Command;

$ENV{LANG} = 'C';
$ENV{TZ} = 'UTC';

my $RootPath = path (__FILE__)->parent->parent->absolute;

sub send_file ($$$) {
  my ($app, $file, $mime) = @_;
  return $app->throw_error (404) unless $file->is_file;
  $app->http->set_response_header ('Content-Type' => $mime);
  $app->http->set_response_header
      ('X-Content-Type-Options' => 'nosniff');
  $app->http->set_response_last_modified ($file->stat->mtime);
  $app->http->send_response_body_as_ref (\($file->slurp));
  return $app->http->close_response_body;
} # send_file

return sub {
  my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
  my $app = Warabe::App->new_from_http ($http);

  return $app->execute_by_promise (sub {
    my $path = $app->path_segments;

    $http->set_response_header
        ('Strict-Transport-Security' => 'max-age=2592000; includeSubDomains; preload');

    if (@$path == 1 and $path->[0] eq '') {
      return $app->send_redirect ('/cc/');
    } elsif (@$path == 1 and $path->[0] =~ /\A[0-9A-Za-z_-]+\.css\z/) {
      return send_file
          ($app, $RootPath->child ($path->[0]), 'text/css; charset=utf-8');
    } elsif (@$path == 1 and $path->[0] =~ /\A[0-9A-Za-z_-]+\.js\z/) {
      return send_file
          ($app, $RootPath->child ($path->[0]), 'text/javascript; charset=utf-8');
      return $app->http->close_response_body;
    } elsif (@$path == 1 and $path->[0] =~ /\A[0-9A-Za-z_-]+\.png\z/) {
      return send_file ($app, $RootPath->child ($path->[0]), 'image/png');
    } elsif (@$path == 1 and $path->[0] eq 'LICENSE') {
      return send_file ($app, $RootPath->child ($path->[0]), 'text/plain; charset=utf-8');
    } elsif (@$path == 1 and $path->[0] =~ /\A[0-9A-Za-z_-]+\z/) {
      my $css_file = $RootPath->child ("$path->[0].css");
      if ($css_file->is_file) {
        return send_file ($app, $css_file, 'text/css; charset=utf-8');
      }
      my $js_file = $RootPath->child ("$path->[0].css");
      if ($js_file->is_file) {
        return send_file ($app, $js_file, 'text/javascript; charset=utf-8');
      }
      my $png_file = $RootPath->child ("$path->[0].png");
      if ($png_file->is_file) {
        return send_file ($app, $png_file, 'image/png');
      }
      my $file2 = $RootPath->child ("$path->[0].en.html.u8");
      my $file3 = $RootPath->child ("$path->[0].ja.html.u8");
      if ($file2->is_file) {
        if ($file3->is_file) {
          my $lang = 'en';
          my $file = $file2;
          for (@{$app->http->accept_langs}) {
            if ($_ eq 'en') {
              $file = $file2;
              last;
            } elsif ($_ eq 'ja') {
              $lang = $_;
              $file = $file3;
              last;
            }
          }
          $app->http->set_response_header ('Content-Language', $lang);
          $app->http->set_response_header ('Vary', 'Accept-Language');
          return send_file $app, $file, 'text/html; charset=utf-8';
        } else {
          $app->http->set_response_header ('Content-Language', 'en');
          return send_file $app, $file2, 'text/html; charset=utf-8';
        }
      }
      my $file1 = $RootPath->child ("$path->[0].en.html");
      $app->http->set_response_header ('Content-Language', 'en');
      return send_file $app, $file1, 'text/html; charset=utf-8';
    } elsif (@$path == 1 and $path->[0] =~ /\A[0-9A-Za-z_-]+\.(en|ja)\z/) {
      $app->http->set_response_header ('Content-Language', $1);
      my $file2 = $RootPath->child ("$path->[0].html.u8");
      if ($file2->is_file) {
        return send_file $app, $file2, 'text/html; charset=utf-8';
      }
      my $file1 = $RootPath->child ("$path->[0].html");
      return send_file $app, $file1, 'text/html; charset=utf-8';
    } elsif (@$path == 1 and $path->[0] =~ /\A([0-9A-Za-z_-]+\.(?:en|ja))\.html\z/) {
      return $app->http->send_redirect ($1);
    } elsif (@$path == 1 and $path->[0] =~ /\A([0-9A-Za-z_-]+\.(?:en|ja))\.html\.u8\z/) {
      return $app->http->send_redirect ($1);
    } elsif (@$path == 2 and $path->[0] eq 'icons' and $path->[1] =~ /\A[0-9A-Za-z_-]+\z/) {
      return send_file ($app, $RootPath->child ($path->[0], "$path->[1].png"), 'image/png');
    } elsif (@$path == 2 and $path->[0] eq 'icons' and $path->[1] =~ /\A[0-9A-Za-z_-]+\.png\z/) {
      return send_file ($app, $RootPath->child ($path->[0], $path->[1]), 'image/png');
    } elsif (@$path >= 2 and
             ($path->[0] eq 'cc' or $path->[0] eq 'langtag')) {
      my $cmd = Promised::Command->new ([$RootPath->child ('perl'), $RootPath->child ("$path->[0].cgi")]);
      $cmd->envs->{REQUEST_METHOD} = $app->http->request_method;
      $cmd->envs->{QUERY_STRING} = $app->http->original_url->{query};
      $cmd->envs->{CONTENT_LENGTH} = $app->http->request_body_length;
      $cmd->envs->{CONTENT_TYPE} = $app->http->get_request_header ('Content-Type');
      $cmd->envs->{HTTP_ACCEPT_LANGUAGE} = $app->http->get_request_header ('Accept-Language');
      $cmd->envs->{PATH_INFO} = join '/', map { percent_encode_c $_ } '', @$path[1..$#$path];
      $cmd->stdin ($app->http->request_body_as_ref);
      $cmd->stdout (\my $stdout);
# XXX output streaming
      return $cmd->run->then (sub {
        return $cmd->wait;
      })->then (sub {
        die $_[0] unless $_[0]->exit_code == 0;
        my ($headers, $body) = split /\x0D?\x0A\x0D?\x0A/, $stdout, 2;
        for (split /[\x0D\x0A]/, $headers) {
          if (/^([^\s:]+):(.*)$/) {
            $app->http->add_response_header ($1 => $2);
          } else {
            die "Bad header |$_|";
          }
        }
        $app->http->send_response_body_as_ref (\$body);
        $app->http->close_response_body;
      });
    }

    return $app->send_error (404);
  });
};

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

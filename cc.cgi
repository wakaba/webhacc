#!/usr/bin/perl
# -d:DProf
use strict;

use lib qw[/home/httpd/html/www/markup/html/whatpm
           /home/wakaba/work/manakai2/lib
           /home/httpd/html/regexp/lib
          ];
use CGI::Carp qw[fatalsToBrowser];

  require WebHACC::Input;

{
  require Message::CGI::HTTP;
  my $http = Message::CGI::HTTP->new;

  require WebHACC::Output;
  my $out = WebHACC::Output->new;
  $out->handle (*STDOUT);
  $out->set_utf8;

  if ($http->get_meta_variable ('PATH_INFO') ne '/') {
    $out->http_error (404);
    exit;
  }

  ## TODO: We need real conneg support...
  my $primary_language = 'en';
  if ($ENV{HTTP_ACCEPT_LANGUAGE} =~ /ja/) {
    $primary_language = 'ja';
  }
  $out->load_text_catalog ($primary_language);
  
  $out->set_flush;
  $out->http_header;
  $out->html_header;
  $out->unset_flush;

  $out->generate_input_section ($http);

  my $u = $http->get_parameter ('uri');
  my $s = $http->get_parameter ('s');
  if ((not defined $u or not length $u) and
      (not defined $s or not length $s)) {
    exit;
  }

  require WebHACC::Result;
  my $result = WebHACC::Result->new;
  $result->output ($out);

  require WebHACC::Input;
  my $input = WebHACC::Input->get_document ($http => $result => $out);

  check_and_print ($input => $result => $out);
  
  $out->nav_list;

  exit;
}

sub check_and_print ($$$) {
  my ($input, $result, $out) = @_;
  my $original_input = $out->input;
  $out->input ($input);

  $input->generate_info_section ($result);

  $input->generate_transfer_sections ($result);

  unless (defined $input->{s}) {
    ## NOTE: This is an error of the implementation.
    $result->layer_uncertain ('transfer');
    $result->generate_result_section;
 
    $out->input ($original_input);
    return;
  }

  my $checker_class = {
    'text/cache-manifest' => 'WebHACC::Language::CacheManifest',
    'text/css' => 'WebHACC::Language::CSS',
    'text/x-css-inline' => 'WebHACC::Language::CSSInline',
    'text/html' => 'WebHACC::Language::HTML',
    'text/x-h2h' => 'WebHACC::Language::H2H',
    'text/x-regexp-js' => 'WebHACC::Language::RegExpJS',
    'text/x-webidl' => 'WebHACC::Language::WebIDL',

    'text/xml' => 'WebHACC::Language::XML',
    'application/atom+xml' => 'WebHACC::Language::XML',
    'application/rss+xml' => 'WebHACC::Language::XML',
    'image/svg+xml' => 'WebHACC::Language::XML',
    'application/xhtml+xml' => 'WebHACC::Language::XML',
    'application/xml' => 'WebHACC::Language::XML',
    ## TODO: Should we make all XML MIME Types fall
    ## into this category?

    ## NOTE: This type has different model from normal XML types.
    'application/rdf+xml' => 'WebHACC::Language::XML',
  }->{$input->{media_type}} || 'WebHACC::Language::Default';

  eval qq{ require $checker_class } or die "$0: Loading $checker_class: $@";
  my $checker = $checker_class->new;
  $checker->input ($input);
  $checker->output ($out);
  $checker->result ($result);

  ## TODO: A cache manifest MUST be text/cache-manifest
  ## TODO: WebIDL media type "text/x-webidl"

  $checker->generate_syntax_error_section;
  $checker->generate_source_string_section;

  my @subdoc;
  $checker->onsubdoc (sub {
    push @subdoc, shift;
  });

  $checker->generate_structure_dump_section;
  $checker->generate_structure_error_section;
  $checker->generate_additional_sections;

  my $id_prefix = 0;
  for my $_subinput (@subdoc) {
    my $subinput = WebHACC::Input::Subdocument->new (++$id_prefix);
    $subinput->{$_} = $_subinput->{$_} for keys %$_subinput;
    $subinput->{base_uri} = $subinput->{container_node}->base_uri
        unless defined $subinput->{base_uri};
    $subinput->{parent_input} = $input;

    my $subresult = WebHACC::Result->new;
    $subresult->output ($out);
    $subresult->parent_result ($result);

    $subinput->start_section ($subresult);
    check_and_print ($subinput => $subresult => $out);
    $subinput->end_section ($subresult);
  }

  $result->generate_result_section;

  $out->input ($original_input);
} # check_and_print

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

Copyright 2007-2008 Wakaba <w@suika.fam.cx>

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

## $Date: 2008/12/11 03:22:56 $

#!/usr/bin/perl
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;
use CGI::Carp qw(fatalsToBrowser);
use Message::CGI::HTTP;
use Message::CGI::Util qw(htescape);
use Whatpm::LangTag;
use Encode;

my $cgi = Message::CGI::HTTP->new;

my $tag = decode 'utf-8', ($cgi->get_parameter ('tag') // '');

  require WebHACC::Output;
  my $out = WebHACC::Output->new;
  $out->handle (*STDOUT);
  $out->set_utf8;

  ## TODO: We need real conneg support...
  my $primary_language = 'en';
  if ($ENV{HTTP_ACCEPT_LANGUAGE} =~ /ja/) {
    $primary_language = 'ja';
  }
  $out->load_text_catalog ($primary_language);

  $out->http_header;

  require WebHACC::Result;
  my $result = WebHACC::Result->new;
  $result->output ($out);

print qq{<!DOCTYPE HTML>
<html lang="@{[htescape $primary_language]}">
<title>Language Tag: "@{[htescape $tag]}"</title>
<link rel=stylesheet href="http://suika.fam.cx/gate/2007/html/cc-style">

<h1>Language Tag</h1>

<div class=section id=input>
<h2>Input</h2>

<form action="" accept-charset=utf-8 method=get>
  <label><strong>Language tag</strong>:
  <input name=tag value="@{[htescape $tag]}"></label>
  <input type=submit value="Show">
</form>
</div>
};

my @error1766;
my @error3066;
my @error4646;
my @error5646;

my $parsed4646 = Whatpm::LangTag->parse_rfc4646_tag ($tag, sub {
  push @error4646, {@_};
});
my $parsed5646 = Whatpm::LangTag->parse_rfc5646_tag ($tag, sub {
  push @error5646, {@_};
});
my $result4646 = Whatpm::LangTag->check_rfc4646_parsed_tag ($parsed4646, sub {
  push @error4646, {@_};
});
my $result5646 = Whatpm::LangTag->check_rfc5646_parsed_tag ($parsed5646, sub {
  push @error5646, {@_};
});

$result4646->{conforming} = 1;
for (@error4646) {
  if ($_->{level} eq 'm') {
    delete $result4646->{conforming};
  } elsif ($_->{level} eq 's' and $result4646->{conforming}) {
    $result4646->{conforming} = '';
  }
}

$result5646->{conforming} = 1;
for (@error5646) {
  if ($_->{level} eq 'm') {
    delete $result5646->{conforming};
  } elsif ($_->{level} eq 's' and $result5646->{conforming}) {
    $result5646->{conforming} = '';
  }
}

my $result3066 = {conforming => 1};
Whatpm::LangTag->check_rfc3066_tag ($tag, sub {
  push @error3066, {@_};
  if ($error3066[-1]->{level} eq 'm') {
    delete $result3066->{conforming};
  } elsif ($error3066[-1]->{level} eq 's' and $result3066->{conforming}) {
    $result3066->{conforming} = '';
  }
});

my $result1766 = {conforming => 1};
Whatpm::LangTag->check_rfc1766_tag ($tag, sub {
  push @error1766, {@_};
  if ($error1766[-1]->{level} eq 'm') {
    delete $result1766->{conforming};
  } elsif ($error1766[-1]->{level} eq 's' and $result1766->{conforming}) {
    $result1766->{conforming} = '';
  }
});

sub value ($) {
  if (not defined $_[0]) {
    return '(not defined)';
  } elsif (not length $_[0]) {
    return '(empty string)';
  } else {
    return '<code>' . (htescape $_[0]) . '</code>';
  }
} # value

print qq{
<div class=section id=parsed>
<h2>Parsed language tag</h2>

<table>
  <thead>
    <tr>
      <th>
      <th>RFC 5646
      <th>RFC 4646
      <th>RFC 3066
      <th>RFC 1766
  <tbody>
    <tr>
      <th>Language
      <td>@{[value $parsed5646->{language}]}
      <td>@{[value $parsed4646->{language}]}
    <tr>
      <th>Extended language
      <td>
        @{[@{$parsed5646->{extlang}}
               ? join ', ', map { value $_ } @{$parsed5646->{extlang}}
               : '(none)']}
      <td>
        @{[@{$parsed4646->{extlang}}
               ? join ', ', map { value $_ } @{$parsed4646->{extlang}}
               : '(none)']}
    <tr>
      <th>Script
      <td>@{[value $parsed5646->{script}]}
      <td>@{[value $parsed4646->{script}]}
    <tr>
      <th>Region
      <td>@{[value $parsed5646->{region}]}
      <td>@{[value $parsed4646->{region}]}
    <tr>
      <th>Variants
      <td>
        <ul>
};

for (@{$parsed5646->{variant}}) {
  print q{<li>};
  print value $_;
}

print qq{
        </ul>
      <td>
        <ul>
};

for (@{$parsed4646->{variant}}) {
  print q{<li>};
  print value $_;
}

print q{
    <tr>
      <th>Extensions
      <td>
        <ul>
};

for (@{$parsed5646->{extension}}) {
  print q{<li>};
  print join ', ', map { value $_ } @{$_};
}

print qq{
        </ul>
      <td>
        <ul>
};

for (@{$parsed4646->{extension}}) {
  print q{<li>};
  print join ', ', map { value $_ } @{$_};
}

print qq{
        </ul>
    <tr>
      <th>Private use
      <td>
        @{[@{$parsed5646->{privateuse}}
               ? join ', ', map { value $_ } @{$parsed5646->{privateuse}}
               : '(none)']}
      <td>
        @{[@{$parsed4646->{privateuse}}
               ? join ', ', map { value $_ } @{$parsed4646->{privateuse}}
               : '(none)']}
    <tr>
      <th>Illegal (broken)
      <td>
        @{[@{$parsed5646->{illegal}}
               ? join ', ', map { value $_ } @{$parsed5646->{illegal}}
               : '(none)']}
      <td>
        @{[@{$parsed4646->{illegal}}
               ? join ', ', map { value $_ } @{$parsed4646->{illegal}}
               : '(none)']}
  <tbody>
    <tr>
      <th>Grandfathered
      <td>@{[value $parsed5646->{grandfathered}]}
      <td>@{[value $parsed4646->{grandfathered}]}
  <tfoot>
    <tr>
      <th>Well-formed?
      <td>@{[$result5646->{well_formed} ? 'Yes' : 'No']}
      <td>@{[$result4646->{well_formed} ? 'Yes' : 'No']}
    <tr>
      <th>Valid?
      <td>@{[$result5646->{valid} ? 'Yes' : 'No']}
      <td>@{[$result4646->{valid} ? 'Yes' : 'No']}
    <tr>
      <th>Conforming?
      <td>@{[$result5646->{conforming} ? 'Yes' : defined $result5646->{conforming} ? 'Maybe no' : 'No']}
      <td>@{[$result4646->{conforming} ? 'Yes' : defined $result4646->{conforming} ? 'Maybe no' : 'No']}
      <td>@{[$result3066->{conforming} ? 'Yes' : defined $result3066->{conforming} ? 'Maybe no' : 'No']}
      <td>@{[$result1766->{conforming} ? 'Yes' : defined $result1766->{conforming} ? 'Maybe no' : 'No']}
</table>
</div>

<div class="section errors" id=parse-errors>
<h2>Parse errors</h2>

<div class=section id=parse-errors-5646>
<h3>RFC 5646 errors</h3>

<dl>
};

for my $error (@error5646) {
  $result->add_error (%$error);
}

print qq{
</dl>

</div>

<div class=section id=parse-errors-4646>
<h3>RFC 4646 errors</h3>

<dl>
};

for my $error (@error4646) {
  $result->add_error (%$error);
}

print qq{
</dl>

</div>

<div class=section id=parse-errors-3066>
<h3>RFC 3066 errors</h3>

<dl>
};

for my $error (@error3066) {
  $result->add_error (%$error);
}

print qq{
</dl>

</div>

<div class=section id=parse-errors-1766>
<h3>RFC 1766 errors</h3>

<dl>
};

for my $error (@error1766) {
  $result->add_error (%$error);
}

print qq{
</dl>

</div>

</div>
};

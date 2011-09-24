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

print "Content-Type: text/html; charset=utf-8\n\n";
print qq{<!DOCTYPE HTML>
<title>Language Tag: "@{[htescape $tag]}"</title>
<link rel=stylesheet href="http://suika.fam.cx/gate/2007/html/cc-style">

<h1>Language Tag</h1>

<div class=section id=input>
<h2>Input</h2>

<form action=langtag accept-charset=utf-8 method=get>
  <label><strong>Language tag</strong>:
  <input name=tag value="@{[htescape $tag]}"></label>
  <input type=submit value="Show">
</form>
</div>
};

my $parsed4646 = Whatpm::LangTag->parse_rfc4646_tag ($tag);
my $parsed5646 = Whatpm::LangTag->parse_rfc5646_tag ($tag);

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
</table>
</div>
};

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
<link rel=stylesheet href="../cc-style">

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

print qq{
<div class=section id=registry-data>
<h2>Registry data</h2>
};

for my $spec (
  ['rfc4646', $parsed4646],
  ['rfc5646', $parsed5646],
) {
  $out->start_section (title => 'Registry data:' . $spec->[0]);

  my $method = 'tag_registry_data_' . $spec->[0];

  for my $component (
    (defined $spec->[1]->{language}
         ? (['language', $spec->[1]->{language}]) : ()),
    (map { ['extlang', $_] } @{$spec->[1]->{extlang}}),
    (defined $spec->[1]->{script}
         ? (['script', $spec->[1]->{script}]) : ()),
    (defined $spec->[1]->{region}
         ? (['region', $spec->[1]->{region}]) : ()),
    (map { ['variant', $_] } @{$spec->[1]->{variant}}),
    (map { ['extension', $_->[0]] } @{$spec->[1]->{extension}}),
    (defined $spec->[1]->{grandfathered}
         ? (['grandfathered', $spec->[1]->{grandfathered}]) : ()),
    ['redundant', $tag],
  ) {
    my $def = Whatpm::LangTag->$method ($component->[0] => $component->[1]);
    next if not $def and $component->[0] eq 'redundant';

    $out->start_tag ('div', class => 'section langtag-component');
    $out->start_tag ('dl');
    $out->start_tag ('dt');
    $out->nl_text ('Subtag:' . 'language');
    $out->start_tag ('dd');
    $out->code ($component->[1]);
    
    $out->start_tag ('dt');
    $out->nl_text ('Registered date');
    $out->start_tag ('dd');
    if ($def->{_added}) {
      $out->start_tag ('time');
      $out->text ($def->{_added});
      $out->end_tag ('time');
    } else {
      $out->nl_text ('Not registered');
    }
    
    if ($def->{_deprecated} or $def->{_preferred}) {
      $out->start_tag ('dt');
      $out->nl_text ('Deprecated');
      $out->start_tag ('dd');
      $out->nl_text ($def->{_deprecated} ? 'Yes' : 'No');
      if ($def->{_preferred}) {
        $out->start_tag ('dd');
        $out->nl_text ('->');
        $out->nl_text (' ');
        if ($component->[0] =~ /lang|redundant|grandfathered/) {
          ## _preferred should not contain any & or ; or #
          $out->start_tag ('a', href => '?tag=' . $def->{_preferred});
          $out->code ($def->{_preferred});
          $out->end_tag ('a');
        } else {
          $out->code ($def->{_preferred});
        }
      }
    }

    if ($def->{_macro}) {
      $out->start_tag ('dt');
      $out->nl_text ('Macrolanguage');
      $out->start_tag ('dd');
      ## _macro should not contain any & or ; or #
      $out->start_tag ('a', href => '?tag=' . $def->{_macro});
      $out->code ($def->{_macro});
      $out->end_tag ('a');
    }
    
    if (@{$def->{Description} or []} or @{$def->{Comments} or []}) {
      $out->start_tag ('dt');
      $out->nl_text ('Description');
      for (@{$def->{Description} or []}, @{$def->{Comments} or []}) {
        $out->start_tag ('dd');
        $out->text ($_);
      }
    }
    
    $out->end_tag ('dl');
    $out->end_tag ('div');
  } # $component

  $out->end_section;
}

print qq{
</div>
};

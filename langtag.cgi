#!/usr/bin/perl
use strict;
use warnings;
use Path::Tiny;
use lib path (__FILE__)->parent->child ('lib')->stringify;
use lib glob path (__FILE__)->parent->child ('modules', '*', 'lib')->stringify;
use CGI::Carp qw(fatalsToBrowser);
use Message::CGI::HTTP;
use Message::CGI::Util qw(htescape);
use Whatpm::LangTag;
use Encode;

my $RootPath = path (__FILE__)->parent;

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
<html lang="@{[htescape $primary_language]}" class=webhacc-langtag>
};

$out->start_tag ('title');
$out->nl_text ('Language tag');
$out->text (': "' . $tag . '"');
$out->end_tag ('title');

print qq{
<link rel=stylesheet href="../cc-style">
<script src="../cc-script.js"></script>

<body onclick=" return onbodyclick (event) " onload=" onbodyload () ">
};

$out->start_tag ('h1');
$out->nl_text (q[WebHACC:Heading]);
$out->nl_text ('Language tag');
$out->end_tag ('h1');

$out->start_section (title => 'Input', id => 'input');
$out->start_tag ('form', action => '', 'accept-charset' => 'utf-8');

$out->start_tag ('p');

$out->start_tag ('label');
$out->start_tag ('strong');
$out->nl_text ('Language tag');
$out->end_tag ('strong');
$out->text (': ');
$out->start_tag ('input', name => 'tag', value => $tag, class => 'langtag');
$out->end_tag ('label');

$out->start_tag ('button', type => 'submit');
$out->nl_text ('Check');
$out->end_tag ('button');

$out->end_tag ('form');
$out->end_section;

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

sub out_value ($$) {
  my $out = shift;
  if (not defined $_[0]) {
    $out->nl_text ('(undef)');
  } elsif (not length $_[0]) {
    $out->nl_text ('(empty)');
  } else {
    $out->code ($_[0]);
  }
} # out_value

$out->start_section (title => 'Parse result', id => 'parsed');

print qq{

<table class=parsed-langtag>
  <thead>
    <tr>
      <th>
      <th>RFC 5646
      <th>RFC 4646
      <th>RFC 3066
      <th>RFC 1766
  <tbody>};

for my $subtag (
  ['language'],
  ['extlang'],
  ['script'],
  ['region'],
  ['variant'],
  ['extension'],
  ['privateuse'],
  ['illegal'],
) {
  $out->start_tag ('tr');
  $out->start_tag ('th');
  $out->nl_text ('Subtag:' . $subtag->[0]);
  for my $parsed (
    $parsed5646,
    $parsed4646,
  ) {
    my %has_extension;
    $out->start_tag ('td');
    if (ref $parsed->{$subtag->[0]} eq 'ARRAY') {
      if (@{$parsed->{$subtag->[0]} or []}) {
        $out->start_tag ('ul');
        for (@{$parsed->{$subtag->[0]} or []}) {
          $out->start_tag ('li');
          if (ref $_ eq 'ARRAY') {
            if ($subtag->[0] eq 'extension' and
                $_->[0] =~ /\A[Uu]\z/ and
                $parsed->{u} and
                not $has_extension{u}) {
              $out->start_tag ('table');
              $out->start_tag ('caption');
              $out->code ($_->[0]);
              $out->end_tag ('caption');
              $out->start_tag ('tbody');
              for (@{$parsed->{u}->[0]}) {
                $out->start_tag ('tr');
                $out->start_tag ('th');
                $out->nl_text ('Subtag:u_attr');
                $out->start_tag ('td');
                $out->code ($_);
              }
              $out->start_tag ('tbody');
              for (1..$#{$parsed->{u}}) {
                my $keyword = $parsed->{u}->[$_];
                $out->start_tag ('tr');
                $out->start_tag ('th');
                my $type = $keyword->[0];
                if (Whatpm::LangTag->tag_registry_data_rfc5646 ('u_key', $type)) {
                  $type =~ tr/A-Z/a-z/;
                  $out->nl_text ('Subtag:u_' . $type);
                } else {
                  $out->code ($type);
                }
                $out->start_tag ('td');
                for (1..$#$keyword) {
                  $out->code ($keyword->[$_]);
                  $out->text (' ');
                }
              }
              $out->end_tag ('table');
              $has_extension{u} = 1;
            } else {
              $out->start_tag ('ul');
              for (@$_) {
                $out->start_tag ('li');
                out_value $out, $_;
              } # $_
              $out->end_tag ('ul');
            }
          } else {
            out_value $out, $_;
          }
        } # $parsed->{$subtag->[0]}
      } else {
        $out->nl_text ('(none)');
      }
      $out->end_tag ('ul');
    } else {
      out_value $out, $parsed->{$subtag->[0]};
    }
  }
}

$out->start_tag ('tbody');
$out->start_tag ('tr');
$out->start_tag ('th');
$out->nl_text ('Subtag:grandfathered');
for ($parsed5646, $parsed4646) {
  $out->start_tag ('td');
  out_value $out, $_->{grandfathered};
}

$out->start_tag ('tfoot', class => 'result');
for my $flag (
  ['well_formed', 'Well-formed'],
  ['valid', 'Valid'],
  ['conforming', 'Conforming'],
) {
  $out->start_tag ('tr');
  $out->start_tag ('th');
  $out->nl_text ($flag->[1]);
  for ( 
    ($flag->[0] eq 'conforming' ? 
      (
        $result5646,
        $result4646,
        $result3066,
        $result1766,
      ) : (
        $result5646,
        $result4646,
      )
    )
  ) {
    if ($_->{$flag->[0]}) {
      $out->start_tag ('td');
      $out->nl_text ('Yes');
    } elsif (defined $_->{$flag->[0]}) {
      $out->start_tag ('td', class => 'should-errors');
      $out->nl_text ('Maybe no');
    } else {
      $out->start_tag ('td', class => 'must-errors');
      $out->nl_text ('No');
    }
  }
}

$out->end_tag ('table');
$out->end_section;

$out->start_section (title => 'Errors', class => 'errors', id => 'errors');

for my $spec (
  ['rfc5646', \@error5646, 'RFC 5646'],
  ['rfc4646', \@error4646, 'RFC 4646'],
  ['rfc3066', \@error3066, 'RFC 3066'],
  ['rfc1766', \@error1766, 'RFC 1766'],
) {
  $out->start_section
      (title => $spec->[2], id => 'errors-' . $spec->[0]);

  if (@{$spec->[1]}) {
    $out->start_tag ('dl');
    
    for my $error (@{$spec->[1]}) {
      $result->add_error (%$error);
    }
    
    $out->end_tag ('dl');
  } else {
    $out->start_tag ('p');
    $out->nl_text ('No error found.');
  }

  $out->end_section;
}

$out->end_section;

$out->start_section (title => 'Registry data', id => 'registry-data');

for my $spec (
  ['rfc5646', $parsed5646, 'RFC 5646'],
  ['rfc4646', $parsed4646, 'RFC 4646'],
) {
  $out->start_section (title => $spec->[2]);

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
    ($spec->[1]->{u} ? (
      map { ['u_key', $_->[0]], ($_->[1] && $_->[0] !~ /^[Vv][Tt]$/ ? (['u_' . $_->[0], $_->[1]]) : ()) }
      @{$spec->[1]->{u}}[1..$#{$spec->[1]->{u}}]
    ) : ()),
    (defined $spec->[1]->{grandfathered}
         ? (['grandfathered', $spec->[1]->{grandfathered}]) : ()),
    ['redundant', $tag],
  ) {
    my $def = Whatpm::LangTag->$method ($component->[0] => $component->[1]);
    next if not $def and $component->[0] eq 'redundant';

    $out->start_tag ('div', class => 'section langtag-component');
    $out->start_tag ('dl');
    $out->start_tag ('dt');
    $out->nl_text ('Subtag:' . $component->[0]);
    $out->start_tag ('dd');
    out_value $out, $component->[1];
    
    if ($component->[0] =~ /^u_/ and $def) {
      #
    } elsif ($def->{_added}) {
      $out->start_tag ('dt');
      $out->nl_text ('Registered date');
      $out->start_tag ('dd');
      $out->start_tag ('time');
      $out->text ($def->{_added});
      $out->end_tag ('time');
    } else {
      $out->start_tag ('dt');
      $out->nl_text ('Registered date');
      $out->start_tag ('dd');
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
          out_value $out, $def->{_preferred};
          $out->end_tag ('a');
        } else {
          out_value $out, $def->{_preferred};
        }
      }
    }

    if ($def->{_macro}) {
      $out->start_tag ('dt');
      $out->nl_text ('Macrolanguage');
      $out->start_tag ('dd');
      ## _macro should not contain any & or ; or #
      $out->start_tag ('a', href => '?tag=' . $def->{_macro});
      out_value $out, $def->{_macro};
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

$RootPath->child ('intermediate/misc-a0.txt');
print $RootPath->slurp;

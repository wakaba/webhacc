package WebHACC::Output;
use strict;
use warnings;
our $VERSION = '1.0';

require IO::Handle;
use Scalar::Util qw/refaddr/;

my $htescape = sub ($) {
  my $s = $_[0];
  $s =~ s/&/&amp;/g;
  $s =~ s/</&lt;/g;
#  $s =~ s/>/&gt;/g;
  $s =~ s/"/&quot;/g;
#  $s =~ s{([\x00-\x09\x0B-\x1F\x7F-\xA0\x{FEFF}\x{FFFC}-\x{FFFF}])}{
#    sprintf '<var>U+%04X</var>', ord $1;
#  }ge;
  return $s;
};

my $htescape_value = sub ($) {
  my $s = $_[0];
  $s =~ s/&/&amp;/g;
  $s =~ s/</&lt;/g;
#  $s =~ s/>/&gt;/g;
  $s =~ s/"/&quot;/g;
  return $s;
};

sub new ($) {
  require WebHACC::Input;
  return bless {nav => [], section_rank => 1,
                input => WebHACC::Input->new}, shift;
} # new

sub input ($;$) {
  if (@_ > 1) {
    if (defined $_[1]) {
      $_[0]->{input} = $_[1];
    } else {
      $_[0]->{input} = WebHACC::Input->new;
    }
  }
  
  return $_[0]->{input};
} # input

sub handle ($;$) {
  if (@_ > 1) {
    if (defined $_[1]) {
      $_[0]->{handle} = $_[1];
    } else {
      delete $_[0]->{handle};
    }
  }
  
  return $_[0]->{handle};
} # handle

sub has_error ($;$) {
  if (@_ > 1) {
    if (defined $_[1]) {
      $_[0]->{has_error} = 1;
    } else {
      delete $_[0]->{has_error};
    }
  }
  
  return $_[0]->{has_error};
} # has_error

sub set_utf8 ($) {
  binmode $_[0]->{handle}, ':utf8';
} # set_utf8

sub set_flush ($) {
  $_[0]->{handle}->autoflush (1);
} # set_flush

sub unset_flush ($) {
  $_[0]->{handle}->autoflush (0);
} # unset_flush

sub html ($$) {
  $_[0]->{handle}->print ($_[1]);
} # html

sub text ($$) {
  $_[0]->{handle}->print ($htescape->($_[1]));
} # text

sub url ($$%) {
  my ($self, $url, %opt) = @_;
  $self->{handle}->print (q[<code class=uri>&lt;]);
  $self->link ($url, %opt, url => $url);
  $self->{handle}->print (q[></code>]);
} # url

sub start_tag ($$%) {
  my ($self, $tag_name, %opt) = @_;
  $self->{handle}->print ('<' . $tag_name);
  if (exists $opt{id}) {
    my $id = $self->input->id_prefix . $opt{id};
    $self->{handle}->print (' id="' . $htescape_value->($id) . '"');
    delete $opt{id};
  }
  for (keys %opt) {
    $self->{handle}->print
        (' ' . $_ . '="' . $htescape_value->($opt{$_}) . '"');
  }
  $self->{handle}->print ('>');
} # start_tag

sub end_tag ($$) {
  $_[0]->{handle}->print ('</' . $_[1] . '>');
} # end_tag

sub start_section ($%) {
  my ($self, %opt) = @_;

  my $class = 'section';
  if (defined $opt{role}) {
    if ($opt{role} eq 'parse-errors') {
      $opt{id} ||= 'parse-errors';
      $opt{title} ||= 'Parse Errors Section';
      $opt{short_title} ||= 'Parse Errors';
      $class .= ' errors';
      delete $opt{role};
    } elsif ($opt{role} eq 'structure-errors') {
      $opt{id} ||= 'document-errors';
      $opt{title} ||= 'Structural Errors';
      $opt{short_title} ||= 'Struct. Errors';
      $class .= ' errors';
      delete $opt{role};
    } elsif ($opt{role} eq 'transfer-errors') {
      $opt{id} ||= 'transfer-errors';
      $opt{title} ||= 'Transfer Errors';
      $opt{short_title} ||= 'Trans. Errors';
      $class .= ' errors';
      delete $opt{role};
    } elsif ($opt{role} eq 'reformatted') {
      $opt{id} ||= 'document-tree';
      $opt{title} ||= 'Reformatted Document Source';
      $opt{short_title} ||= 'Reformatted';
      $class .= ' dump';
      delete $opt{role}
    } elsif ($opt{role} eq 'tree') {
      $opt{id} ||= 'document-tree';
      $opt{title} ||= 'Document Tree';
      $opt{short_title} ||= 'Tree';
      $class .= ' dump';
      delete $opt{role};
    } elsif ($opt{role} eq 'structure') {
      $opt{id} ||= 'document-structure';
      $opt{title} ||= 'Document Structure';
      $opt{short_title} ||= 'Structure';
      $class .= ' dump';
      delete $opt{role};
    } elsif ($opt{role} eq 'subdoc') {
      $class .= ' subdoc';
      delete $opt{role};
    } elsif ($opt{role} eq 'source') {
      $opt{id} ||= 'source-string';
      $opt{title} ||= 'Document Source';
      $opt{short_title} ||= 'Source';
      $class .= ' source';
      delete $opt{role};
    } elsif ($opt{role} eq 'result') {
      $opt{id} ||= 'result-summary';
      $opt{title} ||= 'Result';
      $class .= ' result';
      delete $opt{role};
    }
  }
  $class .= ' ' . $opt{class} if defined $opt{class} and length $opt{class};

  $self->{section_rank}++;
  $self->html (qq[<div class="$class"]);
  if (defined $opt{id}) {
    my $prefix = $self->input->id_prefix;
    $opt{parent_id} ||= $prefix;
    my $id = $prefix . $opt{id};
    $self->html (' id="' . $htescape->($id) . '">');
    if ($self->{section_rank} == 2 or length $opt{parent_id}) {
      my $st = $opt{short_title} || $opt{title};
      push @{$self->{nav}},
          [$id => $st => $opt{text}] if $self->{section_rank} == 2;

      unless ($opt{notab}) {
        $self->start_tag ('script');
        $self->html (qq[ addSectionLink ('$id', ']);
        $self->nl_text ($st, text => $opt{text});
        if (defined $opt{parent_id}) {
          $self->html (q[', '] . $opt{parent_id});
        }
        $self->html (q[') ]);
        $self->end_tag ('script');
      }
    }
  } else {
    $self->html ('>');
  }
  my $section_rank = $self->{section_rank};
  $section_rank = 6 if $section_rank > 6;
  $self->html ('<h' . $section_rank . '>');
  $self->nl_text ($opt{title}, text => $opt{text});
  $self->html ('</h' . $section_rank . '>');
} # start_section

sub end_section ($) {
  my $self = shift;
  $self->html ('</div>');
  $self->{handle}->flush;
  $self->{section_rank}--;
} # end_section

sub start_error_list ($%) {
  my ($self, %opt) = @_;

  if (defined $opt{role}) {
    if ($opt{role} eq 'parse-errors') {
      $opt{id} ||= 'parse-errors-list';
      delete $opt{role};
    } elsif ($opt{role} eq 'structure-errors') {
      $opt{id} ||= 'document-errors-list';
      delete $opt{role};
    } elsif ($opt{role} eq 'transfer-errors') {
      $opt{id} ||= 'transfer-errors-list';
      delete $opt{role};
    }
  }

  $self->start_tag ('dl', %opt);

  delete $self->{has_error}; # reset
} # start_error_list

sub end_error_list ($%) {
  my ($self, %opt) = @_;

  my $no_error_message = 'No error found.';

  if (defined $opt{role}) {
    if ($opt{role} eq 'parse-errors') {
      $self->end_tag ('dl');
      ## NOTE: For parse error list, the |add_source_to_parse_error_list|
      ## method is invoked at the end of |generate_source_string_section|,
      ## since that generation method is invoked after the error list
      ## is generated.
      $no_error_message = 'No parse error found.';
    } elsif ($opt{role} eq 'structure-errors') {
      $self->end_tag ('dl');
      $self->add_source_to_parse_error_list ('document-errors-list');
      $no_error_message = 'No structural error found.';
    } elsif ($opt{role} eq 'transfer-errors') {
      $self->end_tag ('dl');
      $no_error_message = 'No transfer error found.';
    } else {
      $self->end_tag ('dl');
    }
  } else {
    $self->end_tag ('dl');
  }

  unless ($self->{has_error}) {
    $self->start_tag ('p', class => 'no-errors');
    $self->nl_text ($no_error_message);
  }
} # end_error_list

sub add_source_to_parse_error_list ($$) {
  my $self = shift;

  $self->script (q[addSourceToParseErrorList ('] . $self->input->id_prefix .
                 q[', '] . shift () . q[')]);
} # add_source_to_parse_error_list

sub start_code_block ($) {
  $_[0]->{handle}->print ('<pre><code>');
} # start_code_block

sub end_code_block ($) {
  $_[0]->{handle}->print ('</code></pre>');
} # end_code_block

sub code ($$;%) {
  my ($self, $content, %opt) = @_;
  $self->start_tag ('code', %opt);
  $self->text ($content);
  $self->{handle}->print ('</code>');
} # code

sub script ($$;%) {
  my ($self, $content, %opt) = @_;
  $self->start_tag ('script', %opt);
  $self->{handle}->print ($content . '</script>');
} # script

sub dt ($$;%) {
  my ($self, $content, %opt) = @_;
  $self->start_tag ('dt', %opt);
  $self->nl_text ($content, text => $opt{text});
} # dt

sub select ($$%) {
  my ($self, $options, %opt) = @_;

  my $selected = $opt{selected};
  delete $opt{selected};

  $self->start_tag ('select', %opt);
  
  my @options = @$options;
  while (@options) {
    my $opt = shift @options;
    if ($opt->{options}) {
      $self->{handle}->print ('<optgroup label="');
      $self->nl_text ($opt->{label});
      $self->{handle}->print ('">');
      unshift @options, @{$opt->{options}}, {end_options => 1};
    } elsif ($opt->{end_options}) {
      $self->end_tag ('optgroup');
    } else {
      $self->start_tag ('option', value => $opt->{value},
                        ((defined $selected and $opt->{value} eq $selected)
                             ? (selected => '') : ()));
      $self->nl_text (defined $opt->{label} ? $opt->{label} : $opt->{value});
    }
  }

  $self->end_tag ('select');
} # select

sub link ($$%) {
  my ($self, $content, %opt) = @_;
  $self->start_tag ('a', %opt, href => $opt{url});
  $self->{handle}->print ($htescape->($content) . '</a>');
} # link

sub xref ($$%) {
  my ($self, $content, %opt) = @_;
  $self->{handle}->print
      ('<a href="#' . $htescape->($self->input->id_prefix . $opt{target}) . '">');
  $self->nl_text ($content, text => $opt{text});
  $self->{handle}->print ('</a>');
} # xref

sub xref_text ($$%) {
  my ($self, $content, %opt) = @_;
  $self->html ('<a href="#' . $htescape->($self->input->id_prefix . $opt{target}) . '">');
  $self->{handle}->print ($htescape->($content) . '</a>');
} # xref

sub link_to_webhacc ($$%) {
  my ($self, $content, %opt) = @_;
  $opt{url} = './?uri=' . $self->encode_url_component ($opt{url});
  $self->link ($content, %opt);
} # link_to_webhacc

my $get_node_path = sub ($) {
  my $node = shift;
  my @r;
  while (defined $node) {
    my $rs;
    if ($node->node_type == 1) {
      $rs = $node->node_name;
      $node = $node->parent_node;
    } elsif ($node->node_type == 2) {
      $rs = '@' . $node->node_name;
      $node = $node->owner_element;
    } elsif ($node->node_type == 3) {
      $rs = '"' . $node->data . '"';
      $node = $node->parent_node;
    } elsif ($node->node_type == 9) {
      @r = ('') unless @r;
      $rs = '';
      $node = $node->parent_node;
    } else {
      $rs = '#' . $node->node_type;
      $node = $node->parent_node;
    }
    unshift @r, $rs;
  }
  return join '/', @r;
}; # $get_node_path

my $get_object_path = sub ($) {
  my $node = shift;
  my @r;
  while (defined $node) {
    my $ref = ref $node;
    $ref =~ /([^:]+)$/;
    my $rs = $1;
    my $node_name = $node->node_name;
    if (defined $node_name) {
      $rs .= ' <code>' . $htescape->($node_name) . '</code>';
    }
    $node = undef;
    unshift @r, $rs;
  }
  return join '/', @r;
}; # $get_object_path

sub node_link ($$) {
  my ($self, $node) = @_;
  if ($node->isa ('Message::IF::Node')) {
    $self->xref_text ($get_node_path->($node),
                      target => 'node-' . refaddr $node);
  } else {
    $self->{handle}->print ($get_object_path->($node));
  }
} # node_link

{
  my $Msg = {};

sub load_text_catalog ($$) {
  my $self = shift;

  my $lang = shift; # MUST be a canonical lang name
  my $file_name = qq[cc-msg.$lang.txt];
  $lang = 'en' unless -f $file_name;
  $self->{primary_language} = $lang;
  
  open my $file, '<:encoding(utf-8)', $file_name or die "$0: $file_name: $!";
  while (<$file>) {
    if (s/^([^;]+);([^;]*);//) {
      my ($type, $cls, $msg) = ($1, $2, $_);
      $msg =~ tr/\x0D\x0A//d;
      $Msg->{$type} = [$cls, $msg];
    }
  }
} # load_text_catalog

sub nl_text ($$;%) {
  my ($self, $type, %opt) = @_;
  my $node = $opt{node};

  if (defined $Msg->{$type}) {
    my $msg = $Msg->{$type}->[1];
    if ($msg =~ /<var>/) {
      $msg =~ s{<var>{\@([A-Za-z0-9:_.-]+)}</var>}{
        UNIVERSAL::can ($node, 'get_attribute_ns')
            ? $htescape->($node->get_attribute_ns (undef, $1)) : ''
      }ge;
      $msg =~ s{<var>{\@}</var>}{
        UNIVERSAL::can ($node, 'value') ? $htescape->($node->value) : ''
      }ge;
      $msg =~ s{<var>{text}</var>}{
        defined $opt{text} ? $htescape->($opt{text}) : ''
      }ge;
      $msg =~ s{<var>{value}</var>}{
        defined $opt{value} ? $htescape->($opt{value}) : ''
      }ge;
      $msg =~ s{<var>{octets}</var>}{
        if (defined $opt{octets}) {
          join ', ', map {sprintf '0x%02X', ord $_} split //, ${$opt{octets}};
        } else {
          '';
        }
      }ge;
      $msg =~ s{<var>{char}</var>}{
        defined $opt{char} ? $htescape->(${$opt{char}}) : ''
      }ge;
      $msg =~ s{<var>{char:hexref}</var>}{
        if (defined $opt{char}) {
          join '', map {sprintf '&amp;#x%02X;', ord $_} split //, ${$opt{char}};
        } else {
          '';
        }
      }ge;
      $msg =~ s{<var>{local-name}</var>}{
        UNIVERSAL::can ($node, 'manakai_local_name')
            ? $htescape->($node->manakai_local_name) : ''
      }ge;
      $msg =~ s{<var>{element-local-name}</var>}{
        (UNIVERSAL::can ($node, 'owner_element') and $node->owner_element)
            ? $htescape->($node->owner_element->manakai_local_name) : ''
      }ge;
    }
    $self->{handle}->print ($msg);
  } else {
    $self->{handle}->print ($htescape->($type));
  }
} # nl_text

}

sub nav_list ($) {
#  my $self = shift;
#  $self->html (q[<ul class="navigation" id="nav-items">]);
#  for (@{$self->{nav}}) {
#    $self->html (qq[<li><a href="#@{[$htescape->($_->[0])]}">]);
#    $self->nl_text ($_->[1], text => $_->[2]);
#    $self->html ('</a>');
#  }
#  $self->html ('</ul>');
} # nav_list

sub http_header ($) {
  $_[0]->{handle}->print (qq[Content-Type: text/html; charset=utf-8\n\n]);
} # http_header

sub http_error ($$) {
  my $self = shift;
  my $code = 0+shift;
  my $text = {
    404 => 'Not Found',
  }->{$code};
  $self->{handle}->print
      (qq[Status: $code $text\nContent-Type: text/html ; charset=us-ascii\n\n$code $text]);
} # http_error

sub html_header ($) {
  my $self = shift;
  $self->{handle}->print (q[<!DOCTYPE html>]);
  $self->start_tag ('html', lang => $self->{primary_language});
  $self->{handle}->print (q[<head><title>]);
  $self->nl_text (q[WebHACC:Title]);
  $self->{handle}->print (q[</title>
<link rel="stylesheet" href="../cc-style.css" type="text/css">
<script src="../cc-script.js"></script>
</head>
<body onclick=" return onbodyclick (event) " onload=" onbodyload () ">
<h1>]);
  $self->nl_text (q[WebHACC:Heading]);
  $self->{handle}->print (q[</h1><script> insertNavSections () </script>]);
} # html_header

sub generate_input_section ($$) {
  my ($out, $cgi) = @_;

  require Encode;
  my $decode = sub ($) {
    if (defined $_[0]) {
      return Encode::decode ('utf-8', $_[0]);
    } else {
      return undef;
    }
  }; # $decode

  my $options = sub ($) {
    my $context = shift;

    $out->start_tag ('section');
    $out->start_tag ('h4');
    $out->nl_text (q[Options]);
    $out->end_tag ('h4');

    if ($context eq 'url') {
      $out->start_tag ('p');
      $out->start_tag ('label');
      $out->start_tag ('input', type => 'checkbox', name => 'error-page',
                       value => 1,
                       ($cgi->get_parameter ('error-page')
                            ? (checked => '') : ()));
      $out->nl_text ('Check error page');
      $out->end_tag ('label');
    }
    
    $out->start_tag ('p');
    $out->start_tag ('label');
    $out->nl_text (q[Content type]);
    $out->text (': ');
    $out->select ([
      {value => '', label => 'As specified'},
      {value => 'application/atom+xml'},
      {value => 'text/cache-manifest'},
      {value => 'text/css'},
      {value => 'text/x-css-inline'},
      {value => 'text/x-h2h'},
      {value => 'text/html'},
      {value => 'text/vtt'},
      {value => 'text/x-regexp-js'},
      {value => 'text/x-webidl'},
      {value => 'application/xhtml+xml'},
      {value => 'application/xml'},
      {value => 'text/xml'},
    ], name => 'i', selected => scalar $cgi->get_parameter ('i'));
    $out->end_tag ('label');

    if ($context ne 'text') {
      $out->start_tag ('p');
      $out->start_tag ('label');
      $out->nl_text (q[Charset]);
      $out->text (q[: ]);
      $out->select ([
        {value => '', label => 'As specified'},
        {label => 'Japanese charsets', options => [
          {value => 'Windows-31J'},
          {value => 'Shift_JIS'},
          {value => 'x-sjis'},
          {value => 'EUC-JP'},
          {value => 'x-euc-jp'},
          {value => 'ISO-2022-JP'},
          {value => 'ISO-2022-JP-1'},
          {value => 'ISO-2022-JP-2'},
        ]},
        {label => 'Latin charsets', options => [
          {value => 'Windows-1250'},
          {value => 'Windows-1252'},
          {value => 'Windows-1254'},
          {value => 'Windows-1257'},
          {value => 'Windows-1258'},
          {value => 'ISO-8859-1'},
          {value => 'ISO-8859-2'},
          {value => 'ISO-8859-3'},
          {value => 'ISO-8859-4'},
          {value => 'ISO-8859-9'},
          {value => 'ISO-8859-10'},
          {value => 'ISO-8859-13'},
          {value => 'ISO-8859-14'},
          {value => 'ISO-8859-15'},
          {value => 'ISO-8859-16'},
          {value => 'US-ASCII'},
        ]},
        {label => 'Greek charsets', options => [
          {value => 'Windows-1253'},
          {value => 'ISO-8859-7'},
        ]},
        {label => 'Cyrillic charsets', options => [
          {value => 'Windows-1251'},
          {value => 'ISO-8859-5'},
        ]},
        {label => 'Arabic charsets', options => [
          {value => 'Windows-1256'},
          {value => 'ISO-8859-6'},
        ]},
        {label => 'Hebrew charsets', options => [
          {value => 'Windows-1255'},
          {value => 'ISO-8859-8'},
        ]},
        {label => 'Thai charsets', options => [
          {value => 'Windows-874'},
          {value => 'ISO-8859-11'},
          {value => 'TIS-620'},
        ]},
        {label => 'Chinese charsets', options => [
          {value => 'Big5'},
          {value => 'x-x-big5'},
          {value => 'Big5-HKSCS'},
          {value => 'GBK'},
          {value => 'GB2312'},
          {value => 'GB_2312-80'},
          {value => 'ISO-2022-CN'},
          {value => 'ISO-2022-CN-EXT'},
        ]},
        {label => 'Korean charsets', options => [
          {value => 'Windows-949'},
          {value => 'EUC-KR'},
          {value => 'KS_C_5601-1987'},
          {value => 'ISO-2022-KR'},
        ]},
        {label => 'Unicode charsets', options => [
          {value => 'UTF-8'},
          {value => 'UTF-8n'},
          {value => 'UTF-16'}, 
          {value => 'UTF-16BE'},
          {value => 'UTF-16LE'},
       ]},
      ], name => 'charset',
      selected => scalar $cgi->get_parameter ('charset'));
      $out->end_tag ('label');
    }

    if ($context eq 'text') {
      $out->start_tag ('p');
      $out->start_tag ('label');
      $out->nl_text ('Setting innerHTML');
      $out->text (': ');
      $out->start_tag ('input', name => 'e',
                       value => $decode->(scalar $cgi->get_parameter ('e')));
      $out->end_tag ('label');
    }

    $out->end_tag ('section');
  }; # $options

  $out->start_section (id => 'input', title => 'Input');
  $out->html (q[<script> insertNavSections ('input') </script>]);

  $out->start_section (id => 'input-url', title => 'By URL',
                       parent_id => 'input');
  $out->start_tag ('form', action => './#result-summary',
                   'accept-charset' => 'utf-8',
                   method => 'get');
  $out->start_tag ('input', type => 'hidden', name => '_charset_');

  $out->start_tag ('p');
  $out->start_tag ('label');
  $out->nl_text ('URL');
  $out->text (': ');
  $out->start_tag ('input',
                   name => 'uri',
                   type => 'url',
                   value => $decode->(scalar $cgi->get_parameter ('uri')));
  $out->end_tag ('label');

  $out->start_tag ('p');
  $out->start_tag ('button', type => 'submit');
  $out->nl_text ('Check');
  $out->end_tag ('button');

  $options->('url');

  $out->end_tag ('form');
  $out->end_section;

  ## TODO: File upload

  $out->start_section (id => 'input-text', title => 'By direct input',
                       parent_id => 'input');
  $out->start_tag ('form', action => './#result-summary',
                   'accept-charset' => 'utf-8',
                   method => 'post');
  $out->start_tag ('input', type => 'hidden', name => '_charset_');

  $out->start_tag ('p');
  $out->start_tag ('label');
  $out->nl_text ('Document source to check');
  $out->text (': ');
  $out->start_tag ('br');
  $out->start_tag ('textarea',
                   name => 's');
  my $s = $decode->($cgi->get_parameter ('s'));
  $out->html ($htescape_value->($s)) if defined $s;
  $out->end_tag ('textarea');
  $out->end_tag ('label');

  $out->start_tag ('p');
  $out->start_tag ('button', type => 'submit', 
                   onclick => 'form.method = form.s.value.length > 512 ? "post" : "get"');
  $out->nl_text ('Check');
  $out->end_tag ('button');

  $options->('text');

  $out->end_tag ('form');
  $out->end_section;

  $out->script (q[
    if (!document.webhaccNavigated &&
        document.getElementsByTagName ('textarea')[0].value.length > 0) {
      showTab ('input-text');
      document.webhaccNavigated = false;
    }
  ]);

  $out->end_section;
} # generate_input_section

sub encode_url_component ($$) {
  shift;
  require Encode;
  my $s = Encode::encode ('utf8', shift);
  $s =~ s/([^0-9A-Za-z_.~-])/sprintf '%%%02X', ord $1/ge;
  return $s;
} # encode_url_component

1;

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

Copyright 2007-2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

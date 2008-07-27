package WebHACC::Output;
use strict;

require IO::Handle;
use Scalar::Util qw/refaddr/;

my $htescape = sub ($) {
  my $s = $_[0];
  $s =~ s/&/&amp;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  $s =~ s/"/&quot;/g;
  $s =~ s{([\x00-\x09\x0B-\x1F\x7F-\xA0\x{FEFF}\x{FFFC}-\x{FFFF}])}{
    sprintf '<var>U+%04X</var>', ord $1;
  }ge;
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

sub set_utf8 ($) {
  binmode shift->{handle}, ':utf8';
} # set_utf8

sub set_flush ($) {
  shift->{handle}->autoflush (1);
} # set_flush

sub unset_flush ($) {
  shift->{handle}->autoflush (0);
} # unset_flush

sub html ($$) {
  shift->{handle}->print (shift);
} # html

sub text ($$) {
  shift->html ($htescape->(shift));
} # text

sub url ($$%) {
  my ($self, $url, %opt) = @_;
  $self->html (q[<code class=uri>&lt;]);
  $self->link ($url, %opt, url => $url);
  $self->html (q[></code>]);
} # url

sub start_tag ($$%) {
  my ($self, $tag_name, %opt) = @_;
  $self->html ('<' . $htescape->($tag_name)); # escape for safety
  if (exists $opt{id}) {
    my $id = $self->input->id_prefix . $opt{id};
    $self->html (' id="' . $htescape->($id) . '"');
    delete $opt{id};
  }
  for (keys %opt) {    # for safety
    $self->html (' ' . $htescape->($_) . '="' . $htescape->($opt{$_}) . '"');
  }
  $self->html ('>');
} # start_tag

sub end_tag ($$) {
  shift->html ('</' . $htescape->(shift) . '>');
} # end_tag

sub start_section ($%) {
  my ($self, %opt) = @_;

  if (defined $opt{role}) {
    if ($opt{role} eq 'parse-errors') {
      $opt{id} ||= 'parse-errors';
      $opt{title} ||= 'Parse Errors Section';
      $opt{short_title} ||= 'Parse Errors';
      delete $opt{role};
    } elsif ($opt{role} eq 'structure-errors') {
      $opt{id} ||= 'document-errors';
      $opt{title} ||= 'Structural Errors';
      $opt{short_title} ||= 'Struct. Errors';
      delete $opt{role};
    } elsif ($opt{role} eq 'reformatted') {
      $opt{id} ||= 'document-tree';
      $opt{title} ||= 'Reformatted Document Source';
      $opt{short_title} ||= 'Reformatted';
      delete $opt{role}
    } elsif ($opt{role} eq 'tree') {
      $opt{id} ||= 'document-tree';
      $opt{title} ||= 'Document Tree';
      $opt{short_title} ||= 'Tree';
      delete $opt{role};
    } elsif ($opt{role} eq 'structure') {
      $opt{id} ||= 'document-structure';
      $opt{title} ||= 'Document Structure';
      $opt{short_title} ||= 'Structure';
      delete $opt{role};
    }
  }

  $self->{section_rank}++;
  $self->html ('<div class=section');
  if (defined $opt{id}) {
    my $id = $self->input->id_prefix . $opt{id};
    $self->html (' id="' . $htescape->($id) . '"');
    push @{$self->{nav}},
        [$id => $opt{short_title} || $opt{title} => $opt{text}] 
        if $self->{section_rank} == 2;
  }
  my $section_rank = $self->{section_rank};
  $section_rank = 6 if $section_rank > 6;
  $self->html ('><h' . $section_rank . '>');
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
    }
  }

  $self->start_tag ('dl', %opt);
} # start_error_list

sub end_error_list ($%) {
  my ($self, %opt) = @_;

  if (defined $opt{role}) {
    if ($opt{role} eq 'parse-errors') {
      delete $opt{role};
      $self->end_tag ('dl');
      ## NOTE: For parse error list, the |add_source_to_parse_error_list|
      ## method is invoked at the end of |generate_source_string_section|,
      ## since that generation method is invoked after the error list
      ## is generated.
    } elsif ($opt{role} eq 'structure-errors') {
      delete $opt{role};
      $self->end_tag ('dl');
      $self->add_source_to_parse_error_list ('document-errors-list');
    } else {
      $self->end_tag ('dl');
    }
  } else {
    $self->end_tag ('dl');
  }
} # end_error_list

sub add_source_to_parse_error_list ($$) {
  my $self = shift;

  $self->script (q[addSourceToParseErrorList ('] . $self->input->id_prefix .
                 q[', '] . shift () . q[')]);
} # add_source_to_parse_error_list

sub start_code_block ($) {
  shift->html ('<pre><code>');
} # start_code_block

sub end_code_block ($) {
  shift->html ('</code></pre>');
} # end_code_block

sub code ($$;%) {
  my ($self, $content, %opt) = @_;
  $self->start_tag ('code', %opt);
  $self->text ($content);
  $self->html ('</code>');
} # code

sub script ($$;%) {
  my ($self, $content, %opt) = @_;
  $self->start_tag ('script', %opt);
  $self->html ($content);
  $self->html ('</script>');
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
      $self->html ('<optgroup label="');
      $self->nl_text ($opt->{label});
      $self->html ('">');
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
  $self->text ($content);
  $self->html ('</a>');
} # link

sub xref ($$%) {
  my ($self, $content, %opt) = @_;
  $self->html ('<a href="#' . $htescape->($self->input->id_prefix . $opt{target}) . '">');
  $self->nl_text ($content, text => $opt{text});
  $self->html ('</a>');
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

sub node_link ($$) {
  my ($self, $node) = @_;
  $self->xref ($get_node_path->($node), target => 'node-' . refaddr $node);
} # node_link

{
  my $Msg = {};

sub load_text_catalog ($$) {
  my $self = shift;

  my $lang = shift; # MUST be a canonical lang name
  my $file_name = qq[cc-msg.$lang.txt];
  $lang = 'en' unless -f $file_name;
  $self->{primary_language} = $lang;
  
  open my $file, '<:utf8', $file_name or die "$0: $file_name: $!";
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

  my @arg;
  {
    if (defined $Msg->{$type}) {
      my $msg = $Msg->{$type}->[1];
      if ($msg =~ /<var>/) {
        $msg =~ s{<var>\$([0-9]+)</var>}{
          defined $arg[$1] ? $htescape->($arg[$1]) : '(undef)';
        }ge;
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
        $msg =~ s{<var>{local-name}</var>}{
          UNIVERSAL::can ($node, 'manakai_local_name')
            ? $htescape->($node->manakai_local_name) : ''
        }ge;
        $msg =~ s{<var>{element-local-name}</var>}{
          (UNIVERSAL::can ($node, 'owner_element') and
           $node->owner_element)
            ? $htescape->($node->owner_element->manakai_local_name) : ''
        }ge;
      }
      $self->html ($msg);
      return;
    } elsif ($type =~ s/:([^:]*)$//) {
      unshift @arg, $1;
      redo;
    }
  }
  $self->text ($type);
} # nl_text

}

sub nav_list ($) {
  my $self = shift;
  $self->html (q[<ul class="navigation" id="nav-items">]);
  for (@{$self->{nav}}) {
    $self->html (qq[<li><a href="#@{[$htescape->($_->[0])]}">]);
    $self->nl_text ($_->[1], text => $_->[2]);
    $self->html ('</a>');
  }
  $self->html ('</ul>');
} # nav_list

sub http_header ($) {
  shift->html (qq[Content-Type: text/html; charset=utf-8\n\n]);
} # http_header

sub http_error ($$) {
  my $self = shift;
  my $code = 0+shift;
  my $text = {
    404 => 'Not Found',
  }->{$code};
  $self->html (qq[Status: $code $text\nContent-Type: text/html ; charset=us-ascii\n\n$code $text]);
} # http_error

sub html_header ($) {
  my $self = shift;
  $self->html (q[<!DOCTYPE html>]);
  $self->start_tag ('html', lang => $self->{primary_language});
  $self->html (q[<head><title>]);
  $self->nl_text (q[WebHACC:Title]);
  $self->html (q[</title>
<link rel="stylesheet" href="../cc-style.css" type="text/css">
<script src="../cc-script.js"></script>
</head>
<body>
<h1>]);
  $self->nl_text (q[WebHACC:Heading]);
  $self->html ('</h1>');
} # html_header

sub generate_input_section ($$) {
  my ($out, $cgi) = @_;

  my $options = sub ($) {
    my $context = shift;

    $out->html (q[<div class=details><p class=legend onclick="nextSibling.style.display = nextSibling.style.display == 'none' ? 'block' : 'none'">]);
    $out->nl_text (q[Options]);
    $out->start_tag ('div');

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
      {value => 'application/xhtml+xml'},
      {value => 'application/xml'},
      {value => 'text/html'},
      {value => 'text/xml'},
      {value => 'text/css'},
      {value => 'text/cache-manifest'},
      {value => 'text/x-webidl'},
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
          {value => 'EUC-JP'},
          {value => 'ISO-2022-JP'},
        ]},
        {label => 'European charsets', options => [
          {value => 'Windows-1252'},
          {value => 'ISO-8859-1'},
          {value => 'US-ASCII'},
        ]},
        {label => 'Asian charsets', options => [
          {value => 'Windows-874'},
          {value => 'ISO-8859-11'},
          {value => 'TIS-620'},
        ]},
        {label => 'Unicode charsets', options => [
          {value => 'UTF-8'},
          {value => 'UTF-8n'},
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
                       value => scalar $cgi->get_parameter ('e'));
      $out->end_tag ('label');
    }

    $out->html (q[</div></div>]);
  }; # $options

  $out->start_section (id => 'input', title => 'Input');

  $out->start_section (id => 'input-url', title => 'By URL');
  $out->start_tag ('form', action => './', 'accept-charset' => 'utf-8',
                   method => 'get');
  $out->start_tag ('input', type => 'hidden', name => '_charset_');

  $out->start_tag ('p');
  $out->start_tag ('label');
  $out->nl_text ('URL');
  $out->text (': ');
  $out->start_tag ('input',
                   name => 'uri',
                   type => 'url',
                   value => $cgi->get_parameter ('uri'));
  $out->end_tag ('label');

  $options->('url');

  $out->start_tag ('p');
  $out->start_tag ('button', type => 'submit');
  $out->nl_text ('Check');

  $out->end_tag ('form');
  $out->end_section;

  $out->end_tag ('fieldset');

  ## TODO: File upload

  $out->start_section (id => 'input-text', title => 'By direct input');
  $out->start_tag ('form', action => './', 'accept-charset' => 'utf-8',
                   method => 'post');
  $out->start_tag ('input', type => 'hidden', name => '_charset_');

  $out->start_tag ('p');
  $out->start_tag ('label');
  $out->nl_text ('Document source to check');
  $out->text (': ');
  $out->start_tag ('br');
  $out->start_tag ('textarea',
                   name => 's');
  my $s = $cgi->get_parameter ('s');
  $out->text ($s) if defined $s;
  $out->end_tag ('textarea');
  $out->end_tag ('label');

  $options->('text');

  $out->start_tag ('p');
  $out->start_tag ('button', type => 'submit', 
                   onclick => 'form.method = form.s.value.length > 512 ? "post" : "get"');
  $out->nl_text ('Check');
  $out->end_tag ('button');

  $out->end_tag ('form');
  $out->end_section;

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

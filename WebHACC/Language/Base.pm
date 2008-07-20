package WebHACC::Language::Base;
use strict;

sub new ($) {
  die "$0: No constructor is defined for " . ref $_[0];
} # new

## NOTE:
## Language ->input, ->output, ->result
## Input
## Output ->input
## Result ->output

sub input ($;$) {
  if (@_ > 1) {
    if (defined $_[1]) {
      $_[0]->{input} = $_[1];
    } else {
      delete $_[0]->{input};
    }
  }

  return $_[0]->{input};
} # input

sub output ($;$) {
  if (@_ > 1) {
    if (defined $_[1]) {
      $_[0]->{output} = $_[1];
    } else {
      delete $_[0]->{output};
    }
  }

  return $_[0]->{output};
} # output

sub result ($;$) {
  if (@_ > 1) {
    if (defined $_[1]) {
      $_[0]->{result} = $_[1];
    } else {
      delete $_[0]->{result};
    }
  }

  return $_[0]->{result};
} # result

sub onsubdoc ($;$) {
  if (@_ > 1) {
    if (defined $_[1]) {
      $_[0]->{onsubdoc} = $_[1];
    } else {
      delete $_[0]->{onsubdoc};
    }
  }

  return $_[0]->{onsubdoc} || sub { };
} # onsubdoc

sub generate_syntax_error_section ($) {
  die "$0: Syntactical checking for " . (ref $_[0]) . " is not supported";
} # generate_syntax_error_section

sub generate_structure_dump_section ($) {
  #
} # generate_structure_dump_section

sub generate_structure_error_section ($) {
  my $self = shift;

  my $out = $self->output;
  
  $out->start_section (id => 'document-errors', title => 'Document Errors');
  $out->html ('<p>Not supported for this kind of contents.');
  ## TODO: class="???"
  $out->end_section;
} # generate_structure_error_section

sub source_charset ($) {
  return 'utf-8';
} # source_charset

sub generate_source_string_section ($) {
  my $self = shift;
  my $input = $self->input;

  my $s;
  unless ($input->{is_char_string}) {
    open my $byte_stream, '<', \($input->{s});
    require Message::Charset::Info;
    my $charset = Message::Charset::Info->get_by_iana_name
        ($self->source_charset);
    my ($char_stream, $e_status) = $charset->get_decode_handle
        ($byte_stream, allow_error_reporting => 1, allow_fallback => 1);
    return unless $char_stream;

    $char_stream->onerror (sub {
      my (undef, $type, %opt) = @_;
      if ($opt{octets}) {
        ${$opt{octets}} = "\x{FFFD}";
      }
    });

    my $t = '';
    while (1) {
      my $c = $char_stream->getc;
      last unless defined $c;
      $t .= $c;
    }
    $s = \$t;
    ## TODO: Output for each line, don't concat all of lines.
  } else {
    $s = \($input->{s});
  }

  my $out = $self->output;
  my $i = 1;
  $out->start_section (id => 'source-string', title => 'Document Source',
                       short_title => 'Source');
  $out->start_tag ('ol', lang => '');

  if (length $$s) {
    while ($$s =~ /\G([^\x0D\x0A]*?)(?>\x0D\x0A?|\x0A)/gc) {
      $out->start_tag ('li', id => 'line-' . $i);
      $out->text ($1);
      $i++;
    }
    if ($$s =~ /\G([^\x0D\x0A]+)/gc) {
      $out->start_tag ('li', id => 'line-' . $i);
      $out->text ($1);
    }
  } else {
    $out->start_tag ('li', id => 'line-1');
  }
  $out->end_tag ('ol');
  $out->html (qq[<script>
  addSourceToParseErrorList ('@{[$input->id_prefix]}', 'parse-errors-list');
</script>]);
  $out->end_section
} # generate_source_string_section

sub generate_additional_sections ($) {
  my $self = shift;
  $self->generate_url_section;
} # generate_additional_sections

sub generate_url_section ($) {
  my $self = shift;
  my $urls = $self->{add_info}->{uri} || {};
  return unless keys %$urls;

  ## NOTE: URIs contained in the DOM (i.e. in HTML or XML documents),
  ## except for those in RDF triples.
  ## TODO: URIs in CSS
  
  my $out = $self->output;
  $out->start_section (id => 'urls', title => 'URLs');
  $out->start_tag ('dl');

  my $input = $self->input;
  my $result = $self->result;

  for my $url (sort {$a cmp $b} keys %$urls) {
    $out->start_tag ('dt');
    $out->url ($url);
    $out->start_tag ('dd');
    $out->link_to_webhacc ('Check conformance of this document', url => $url);
    $out->html ('<dd>Found in: <ul>');
    for my $entry (@{$urls->{$url}}) {
      $out->html (qq[<li>] . $result->get_node_link ($input, $entry->{node}));
      if (keys %{$entry->{type} or {}}) {
        $out->text (' (');
        $out->text (join ', ', map {
          {
            hyperlink => 'Hyperlink',
            resource => 'Link to an external resource',
            namespace => 'Namespace URI',
            cite => 'Citation or link to a long description',
            embedded => 'Link to an embedded content',
            base => 'Base URI',
            action => 'Submission URI',
          }->{$_} 
            or
          $_
        } keys %{$entry->{type}});
        $out->text (')');
      }
    }
    $out->end_tag ('ul');
  }
  $out->end_tag ('dl');
  $out->end_section;
} # generate_url_section

1;

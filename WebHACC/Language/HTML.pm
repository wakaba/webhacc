package WebHACC::Language::HTML;
use strict;
require WebHACC::Language::DOM;
push our @ISA, 'WebHACC::Language::DOM';

sub new ($) {
  return bless {}, shift;
} # new

sub generate_syntax_error_section ($) {
  my $self = shift;
  
  require Message::DOM::DOMImplementation;
  require Encode;
  require Whatpm::HTML;
  
  my $out = $self->output;
  $out->start_section (role => 'parse-errors');
  $out->start_error_list (role => 'parse-errors');
  $self->result->layer_applicable ('syntax');

  my $input = $self->input;
  my $result = $self->result;

  my $onerror = sub {
    my %opt = @_;
    $result->add_error (layer => 'syntax', %opt);

    if ($opt{type} eq 'chardecode:no error') {
      $self->result->layer_uncertain ('encode');
    } elsif ($opt{type} eq 'chardecode:fallback' or
             $opt{type} eq 'charset:not supported') {
      $self->result->layer_uncertain ('charset');
      $self->result->layer_uncertain ('syntax');
      $self->result->layer_uncertain ('structure');
      $self->result->layer_uncertain ('semantics');
    }
  };

  $self->result->layer_applicable ('charset');
  my $char_checker = sub ($) {
    require Whatpm::Charset::UnicodeChecker;
    return Whatpm::Charset::UnicodeChecker->new_handle ($_[0], 'html5');
  }; # $char_checker

  my $dom = Message::DOM::DOMImplementation->new;
  my $doc = $dom->create_document;
  my $el;
  my $inner_html_element = $input->{inner_html_element};
  if (defined $inner_html_element and length $inner_html_element) {
    $input->{charset} ||= 'utf-8';
    my $t = \($input->{s});
    unless ($input->{is_char_string}) {
      $t = \(Encode::decode ($input->{charset}, $$t));
      $self->result->layer_applicable ('encode');
    }
    
    $el = $doc->create_element_ns
        ('http://www.w3.org/1999/xhtml', [undef, $inner_html_element]);
    Whatpm::HTML->set_inner_html ($el, $$t, $onerror, $char_checker);

    $self->{structure} = $el;
    $self->{_structure_root} = $doc;
        ## NOTE: This is necessary, otherwise it would be garbage collected
        ## before $el is useless, since $el->owner_document is only a weak
        ## reference.
  } else {
    if ($input->{is_char_string}) {
      Whatpm::HTML->parse_char_string ($input->{s} => $doc,
                                       $onerror, $char_checker);
    } else {
      $self->result->layer_applicable ('encode');
      Whatpm::HTML->parse_byte_string
          ($input->{charset}, $input->{s} => $doc, $onerror, $char_checker);
    }

    $self->{structure} = $doc;
  }
  $doc->manakai_charset ($input->{official_charset})
      if defined $input->{official_charset};

  ## TODO: We need to issue some warning if media type/charset is
  ## explicitly overridden by the user.

  $doc->document_uri ($input->url);
  $doc->manakai_entity_base_uri ($input->{base_uri});

  $doc->input_encoding (undef) if $input->isa ('WebHACC::Input::Text');

  $out->end_error_list (role => 'parse-errors');
  $out->end_section;
} # generate_syntax_error_section

sub source_charset ($) {
  my $self = shift;
  return (($self->{structure}->owner_document || $self->{structure})->input_encoding || $self->input->{charset});
  ## TODO: We need some way to get the source charset reliably.  The
  ## |input_encoding| DOM attribute might be intentionally left blank
  ## when the input is the direct input form, but even that case the
  ## charset information should be useful because the input string
  ## might be a byte sequence.  In addition, the |input_encoding| does
  ## not reflect the fallback encoding in use.  On the contrary, the
  ## |{charset}| property of the |input| object is always the value
  ## from the lower-level protocol and that might be ignored by the
  ## HTML sniffer.
} # source_charset

1;

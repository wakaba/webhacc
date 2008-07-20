package WebHACC::Language::HTML;
use strict;
require WebHACC::Language::DOM;
push our @ISA, 'WebHACC::Language::DOM';

require Message::DOM::DOMImplementation;

sub new ($) {
  return bless {}, shift;
} # new

sub generate_syntax_error_section ($) {
  my $self = shift;
  
  require Encode;
  require Whatpm::HTML;
  
  my $out = $self->output;
  $out->start_section (id => 'parse-errors', title => 'Parse Errors');
  $out->start_tag (id => 'parse-errors-list');

  my $input = $self->input;
  my $result = $self->result;

  my $onerror = sub {
    $result->add_error (@_, layer => 'syntax');
  };

  my $dom = Message::DOM::DOMImplementation->new;
  my $doc = $dom->create_document;
  my $el;
  my $inner_html_element = $input->{inner_html_element};
  if (defined $inner_html_element and length $inner_html_element) {
    $input->{charset} ||= 'windows-1252'; ## TODO: for now.
    my $t = \($input->{s});
    unless ($input->{is_char_string}) {
      $t = \(Encode::decode ($input->{charset}, $$t));
    }
    
    $el = $doc->create_element_ns
        ('http://www.w3.org/1999/xhtml', [undef, $inner_html_element]);
    Whatpm::HTML->set_inner_html ($el, $$t, $onerror);

    $self->{structure} = $el;
  } else {
    if ($input->{is_char_string}) {
      Whatpm::HTML->parse_char_string ($input->{s} => $doc, $onerror);
    } else {
      Whatpm::HTML->parse_byte_string
          ($input->{charset}, $input->{s} => $doc, $onerror);
    }

    $self->{structure} = $doc;
  }
  $doc->manakai_charset ($input->{official_charset})
      if defined $input->{official_charset};

  $doc->document_uri ($input->{uri});
  $doc->manakai_entity_base_uri ($input->{base_uri});

  $out->end_tag ('dl');
  $out->end_section;
} # generate_syntax_error_section

sub source_charset ($) {
  my $self = shift;
  return $self->input->{charset} || ($self->{structure}->owner_document || $self->{structure})->input_encoding;
  ## TODO: Can we always use input_encoding?
} # source_charset

1;

package WebHACC::Language::XML;
use strict;
require WebHACC::Language::DOM;
push our @ISA, 'WebHACC::Language::DOM';

sub new ($) {
  return bless {}, shift;
} # new

sub generate_syntax_error_section ($) {
  my $self = shift;
  
  require Message::DOM::DOMImplementation;
  require Message::DOM::XMLParserTemp;

  my $out = $self->output;
  $out->start_section (role => 'parse-errors');
  $out->start_error_list (role => 'parse-errors');

  my $input = $self->input;
  my $result = $self->result;

  my $onerror = sub {
    my $err = shift;
    $result->add_error (line => $err->location->line_number,
                        column => $err->location->column_number,
                        type => 'xml parse error',
                        value => $err->text,
                        level => [
                          $err->SEVERITY_FATAL_ERROR => 'm',
                          $err->SEVERITY_ERROR => 'm',
                          $err->SEVERITY_WARNING => 's',
                        ]->[$err->severity],
                        layer => 'syntax');
    return 1;
  };

  my $t = \($input->{s});
  if ($input->{is_char_string}) {
    require Encode;
    $t = \(Encode::encode ('utf8', $$t));
    $input->{charset} = 'utf-8';
  }

  open my $fh, '<', $t;
  my $dom = Message::DOM::DOMImplementation->new;
  $self->{structure} = Message::DOM::XMLParserTemp->parse_byte_stream
      ($fh => $dom, $onerror, charset => $input->{charset});
  $self->{structure}->manakai_charset ($input->{official_charset})
      if defined $input->{official_charset};

  $self->{structure}->document_uri ($input->{uri});
  $self->{structure}->manakai_entity_base_uri ($input->{base_uri});

  $out->end_error_list;
  $out->end_section;
} # generate_syntax_error_section

sub source_charset ($) {
  my $self = shift;
  return $self->input->{charset} || ($self->{structure}->owner_document || $self->{structure})->input_encoding;
  ## TODO: Can we always use input_encoding?
} # source_charset

1;

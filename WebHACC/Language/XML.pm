package WebHACC::Language::XML;
use strict;
require WebHACC::Language::DOM;
push our @ISA, 'WebHACC::Language::DOM';

sub new ($) {
  return bless {}, shift;
} # new

sub generate_syntax_error_section ($) {
  my $self = shift;
  
  require Message::DOM::XMLParserTemp;

  my $out = $self->output;
  $out->start_section (id => 'parse-errors', title => 'Parse Errors');
  $out->start_tag ('dl', class => 'parse-errors-list');

  my $input = $self->input;
  my $result = $self->result;

  my $onerror = sub {
    my $err = shift;
    my $line = $err->location->line_number;
    $out->start_tag ('dt');
    $out->xref (qq[Line $line], target => 'line-' . $line);
    $out->html (' column ' . $err->location->column_number . '<dd>');
    $out->text ($err->text);

    add_error ('syntax', {type => $err->text,
                level => [
                          $err->SEVERITY_FATAL_ERROR => 'm',
                          $err->SEVERITY_ERROR => 'm',
                          $err->SEVERITY_WARNING => 's',
                         ]->[$err->severity]} => $result);

    return 1;
  };

  my $t = \($input->{s});
  if ($input->{is_char_string}) {
    require Encode;
    $t = \(Encode::encode ('utf8', $$t));
    $input->{charset} = 'utf-8';
  }

  open my $fh, '<', $t;
  my $doc = Message::DOM::XMLParserTemp->parse_byte_stream
      ($fh => $dom, $onerror, charset => $input->{charset});
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

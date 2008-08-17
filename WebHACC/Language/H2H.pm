package WebHACC::Language::H2H;
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
  require Whatpm::H2H;
  
  $self->result->layer_uncertain ('encode');
  $self->result->layer_uncertain ('charset');

  my $out = $self->output;
  $out->start_section (role => 'parse-errors');
  $out->start_error_list (role => 'parse-errors');
  $self->result->layer_applicable ('syntax');

  my $input = $self->input;
  my $result = $self->result;

  my $dom = Message::DOM::DOMImplementation->new;
  my $doc = $dom->create_document;

  $input->{charset} ||= 'euc-jp';
  my $t = \($input->{s});
  unless ($input->{is_char_string}) {
    $t = \(Encode::decode ($input->{charset}, $$t));
    $self->result->layer_applicable ('encode');
  }
    
  Whatpm::H2H->parse_string ($$t => $doc);

  $self->{structure} = $doc;

  $doc->manakai_charset ($input->{official_charset})
      if defined $input->{official_charset};

  $doc->document_uri ($input->url);
  $doc->manakai_entity_base_uri ($input->{base_uri});

  $doc->input_encoding ($input->{charset})
      unless $input->isa ('WebHACC::Input::Text');

  $out->end_error_list (role => 'parse-errors');
  $out->end_section;
} # generate_syntax_error_section

sub source_charset ($) {
  my $self = shift;
  return $self->input->{charset} || $self->{structure}->input_encoding;
} # source_charset

1;

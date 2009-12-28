package WebHACC::Language::CSSInline;
use strict;
require WebHACC::Language::CSS;
push our @ISA, 'WebHACC::Language::CSS';

sub generate_syntax_error_section ($) {
  my $self = shift;
  
  my $out = $self->output;
  
  $self->result->layer_uncertain ('charset');

  $out->start_section (role => 'parse-errors');
  $out->start_error_list (role => 'parse-errors');
  $self->result->layer_applicable ('syntax');

  my $input = $self->input;
  my $result = $self->result;

  my $p = $self->get_css_parser ();
  $p->init;
  $p->{onerror} = sub {
    my (%opt) = @_;
    if (not defined $opt{value} and defined $opt{token}) {
      $opt{value} = Whatpm::CSS::Tokenizer->serialize_token ($opt{token});
    }
    $result->add_error (%opt, layer => 'syntax');
  };
  $p->{href} = $input->url;
  $p->{base_uri} = $input->{base_uri};

#  if ($parse_mode eq 'q') {
#    $p->{unitless_px} = 1;
#    $p->{hashless_color} = 1;
#  }

## TODO: Make $input->{s} a ref.

  my $s = \$input->{s};
  unless ($input->{is_char_string}) {
    my $charset;
    $self->result->layer_uncertain ('encode');
    require Encode;
    if (defined $input->{charset}) {## TODO: IANA->Perl
      $charset = $input->{charset};
      $s = \(Encode::decode ($input->{charset}, $$s));
    } else {
      ## TODO: charset detection
      $s = \(Encode::decode ($charset = 'utf-8', $$s));
    }
    $self->{source_charset} = $charset;
  }
  
  $self->{structure} = $p->parse_char_string_as_inline ($$s);

  $out->end_error_list (role => 'parse-errors');
  $out->end_section;
} # generate_syntax_error_section

sub source_charset ($) {
  return shift->{source_charset};
} # source_charset

1;

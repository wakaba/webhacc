package WebHACC::Language::CSS;
use strict;
require WebHACC::Language::Base;
push our @ISA, 'WebHACC::Language::Base';

sub new ($) {
  my $self = bless {}, shift;
  return $self;
} # new

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
  my $charset;
  unless ($input->{is_char_string}) {
    $self->result->layer_uncertain ('encode');
    require Encode;
    if (defined $input->{charset}) {## TODO: IANA->Perl
      $charset = $input->{charset};
      $s = \(Encode::decode ($input->{charset}, $$s));
    } else {
      ## TODO: charset detection
      $s = \(Encode::decode ($charset = 'utf-8', $$s));
    }
  }
  
  $self->{structure} = $p->parse_char_string ($$s);
  $self->{structure}->manakai_input_encoding ($charset) if defined $charset;

  $out->end_error_list (role => 'parse-errors');
  $out->end_section;
} # generate_syntax_error_section

sub source_charset ($) {
  return shift->{structure}->manakai_input_encoding;
} # source_charset

sub generate_structure_dump_section ($) {
  my $self = shift;

  my $out = $self->output;

  $out->start_section (role => 'reformatted');

  $out->start_code_block;
  $out->text ($self->{structure}->css_text);
  $out->end_code_block;
  
  $out->end_section;
} # generate_structure_dump_section

sub generate_structure_error_section ($) {
## NOTE: The content of this method is commented out, since a CSSOM
## tree would contain no error that affect conformance, AFAICT.
## The plan is that we could someday implement "semantic" checking for CSSOM
## trees, like "this color and this background color is too resemble such that
## a user might not be able to read the text".  Such errors do not affect
## conformance, in any way.
#  my $self = shift;
#
#  my $out = $self->output;
#
#  $out->start_section (role => 'structure-errors');
#  $out->start_error_list (role => 'structure-errors');
#  $self->result->layer_applicable ('structure');
#
#  $self->result->add_error (level => 'u',
#                            layer => 'structure',
#                            input => $self->input,
#                            type => 'CSSOM validation not supported');
#
#  $out->end_error_list (role => 'structure-errors');
#  $out->end_section;
} # generate_structure_error_section

sub get_css_parser () {
  our $CSSParser;
  return $CSSParser if $CSSParser;

  require Whatpm::CSS::Parser;
  my $p = Whatpm::CSS::Parser->new;

  require Whatpm::CSS::SelectorsParser;

  $p->{prop}->{$_} = 1 for qw/
    alignment-baseline
    background background-attachment background-color background-image
    background-position background-position-x background-position-y
    background-repeat border border-bottom border-bottom-color
    border-bottom-style border-bottom-width border-collapse border-color
    border-left border-left-color
    border-left-style border-left-width border-right border-right-color
    border-right-style border-right-width
    border-spacing -manakai-border-spacing-x -manakai-border-spacing-y
    border-style border-top border-top-color border-top-style border-top-width
    border-width bottom
    caption-side clear clip color content counter-increment counter-reset
    cursor direction display dominant-baseline empty-cells float font
    font-family font-size font-size-adjust font-stretch
    font-style font-variant font-weight height left
    letter-spacing line-height
    list-style list-style-image list-style-position list-style-type
    margin margin-bottom margin-left margin-right margin-top marker-offset
    marks max-height max-width min-height min-width opacity -moz-opacity
    orphans outline outline-color outline-style outline-width overflow
    overflow-x overflow-y
    padding padding-bottom padding-left padding-right padding-top
    page page-break-after page-break-before page-break-inside
    position quotes right size table-layout
    text-align text-anchor text-decoration text-indent text-transform
    top unicode-bidi vertical-align visibility white-space width widows
    word-spacing writing-mode z-index
  /;
  $p->{prop_value}->{display}->{$_} = 1 for qw/
    block clip inline inline-block inline-table list-item none
    table table-caption table-cell table-column table-column-group
    table-header-group table-footer-group table-row table-row-group
    compact marker
  /;
  $p->{prop_value}->{position}->{$_} = 1 for qw/
    absolute fixed relative static
  /;
  for (qw/-moz-max-content -moz-min-content -moz-fit-content -moz-available/) {
    $p->{prop_value}->{width}->{$_} = 1;
    $p->{prop_value}->{'min-width'}->{$_} = 1;
    $p->{prop_value}->{'max-width'}->{$_} = 1;
  }
  $p->{prop_value}->{float}->{$_} = 1 for qw/
    left right none
  /;
  $p->{prop_value}->{clear}->{$_} = 1 for qw/
    left right none both
  /;
  $p->{prop_value}->{direction}->{ltr} = 1;
  $p->{prop_value}->{direction}->{rtl} = 1;
  $p->{prop_value}->{marks}->{crop} = 1;
  $p->{prop_value}->{marks}->{cross} = 1;
  $p->{prop_value}->{'unicode-bidi'}->{$_} = 1 for qw/
    normal bidi-override embed
  /;
  for my $prop_name (qw/overflow overflow-x overflow-y/) {
    $p->{prop_value}->{$prop_name}->{$_} = 1 for qw/
      visible hidden scroll auto -webkit-marquee -moz-hidden-unscrollable
    /;
  }
  $p->{prop_value}->{visibility}->{$_} = 1 for qw/
    visible hidden collapse
  /;
  $p->{prop_value}->{'list-style-type'}->{$_} = 1 for qw/
    disc circle square decimal decimal-leading-zero
    lower-roman upper-roman lower-greek lower-latin
    upper-latin armenian georgian lower-alpha upper-alpha none
    hebrew cjk-ideographic hiragana katakana hiragana-iroha
    katakana-iroha
  /;
  $p->{prop_value}->{'list-style-position'}->{outside} = 1;
  $p->{prop_value}->{'list-style-position'}->{inside} = 1;
  $p->{prop_value}->{'page-break-before'}->{$_} = 1 for qw/
    auto always avoid left right
  /;
  $p->{prop_value}->{'page-break-after'}->{$_} = 1 for qw/
    auto always avoid left right
  /;
  $p->{prop_value}->{'page-break-inside'}->{auto} = 1;
  $p->{prop_value}->{'page-break-inside'}->{avoid} = 1;
  $p->{prop_value}->{'background-repeat'}->{$_} = 1 for qw/
    repeat repeat-x repeat-y no-repeat
  /;
  $p->{prop_value}->{'background-attachment'}->{scroll} = 1;
  $p->{prop_value}->{'background-attachment'}->{fixed} = 1;
  $p->{prop_value}->{'font-size'}->{$_} = 1 for qw/
    xx-small x-small small medium large x-large xx-large
    -manakai-xxx-large -webkit-xxx-large
    larger smaller
  /;
  $p->{prop_value}->{'font-style'}->{normal} = 1;
  $p->{prop_value}->{'font-style'}->{italic} = 1;
  $p->{prop_value}->{'font-style'}->{oblique} = 1;
  $p->{prop_value}->{'font-variant'}->{normal} = 1;
  $p->{prop_value}->{'font-variant'}->{'small-caps'} = 1;
  $p->{prop_value}->{'font-stretch'}->{$_} = 1 for
      qw/normal wider narrower ultra-condensed extra-condensed
        condensed semi-condensed semi-expanded expanded
        extra-expanded ultra-expanded/;
  $p->{prop_value}->{'text-align'}->{$_} = 1 for qw/
    left right center justify begin end
  /;
  $p->{prop_value}->{'text-transform'}->{$_} = 1 for qw/
    capitalize uppercase lowercase none
  /;
  $p->{prop_value}->{'white-space'}->{$_} = 1 for qw/
    normal pre nowrap pre-line pre-wrap -moz-pre-wrap
  /;
  $p->{prop_value}->{'writing-mode'}->{$_} = 1 for qw/
    lr rl tb lr-tb rl-tb tb-rl
  /;
  $p->{prop_value}->{'text-anchor'}->{$_} = 1 for qw/
    start middle end
  /;
  $p->{prop_value}->{'dominant-baseline'}->{$_} = 1 for qw/
    auto use-script no-change reset-size ideographic alphabetic
    hanging mathematical central middle text-after-edge text-before-edge
  /;
  $p->{prop_value}->{'alignment-baseline'}->{$_} = 1 for qw/
    auto baseline before-edge text-before-edge middle central
    after-edge text-after-edge ideographic alphabetic hanging
    mathematical
  /;
  $p->{prop_value}->{'text-decoration'}->{$_} = 1 for qw/
    none blink underline overline line-through
  /;
  $p->{prop_value}->{'caption-side'}->{$_} = 1 for qw/
    top bottom left right
  /;
  $p->{prop_value}->{'table-layout'}->{auto} = 1;
  $p->{prop_value}->{'table-layout'}->{fixed} = 1;
  $p->{prop_value}->{'border-collapse'}->{collapse} = 1;
  $p->{prop_value}->{'border-collapse'}->{separate} = 1;
  $p->{prop_value}->{'empty-cells'}->{show} = 1;
  $p->{prop_value}->{'empty-cells'}->{hide} = 1;
  $p->{prop_value}->{cursor}->{$_} = 1 for qw/
    auto crosshair default pointer move e-resize ne-resize nw-resize n-resize
    se-resize sw-resize s-resize w-resize text wait help progress
  /;
  for my $prop (qw/border-top-style border-left-style
                   border-bottom-style border-right-style outline-style/) {
    $p->{prop_value}->{$prop}->{$_} = 1 for qw/
      none hidden dotted dashed solid double groove ridge inset outset
    /;
  }
  for my $prop (qw/color background-color
                   border-bottom-color border-left-color border-right-color
                   border-top-color border-color/) {
    $p->{prop_value}->{$prop}->{transparent} = 1;
    $p->{prop_value}->{$prop}->{flavor} = 1;
    $p->{prop_value}->{$prop}->{'-manakai-default'} = 1;
  }
  $p->{prop_value}->{'outline-color'}->{invert} = 1;
  $p->{prop_value}->{'outline-color'}->{'-manakai-invert-or-currentcolor'} = 1;
  $p->{pseudo_class}->{$_} = 1 for qw/
    lang nth-child nth-last-child nth-of-type nth-last-of-type not
    -manakai-contains
  /, keys %$Whatpm::CSS::SelectorsParser::IdentOnlyPseudoClasses;
  $p->{pseudo_element}->{$_} = 1
      for keys %$Whatpm::CSS::SelectorsParser::IdentOnlyPseudoElements;

  return $CSSParser = $p;
} # get_css_parser

1;

=head1 LICENSE

Copyright 2008-2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

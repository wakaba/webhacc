package WebHACC::Output;
use strict;
require IO::Handle;

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
  return bless {nav => []}, shift;
} # new

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
  $self->html ('<div class=section');
  if (defined $opt{id}) {
    my $id = $self->input->id_prefix . $opt{id};
    $self->html (' id="' . $htescape->($id) . '"');
    push @{$self->{nav}}, [$id => $opt{short_title} || $opt{title}] 
        unless $self->input->nested;
  }
  $self->html ('><h2>' . $htescape->($opt{title}) . '</h2>');
} # start_section

sub end_section ($) {
  my $self = shift;
  $self->html ('</div>');
  $self->{handle}->flush;
} # end_section

sub start_code_block ($) {
  shift->html ('<pre><code>');
} # start_code_block

sub end_code_block ($) {
  shift->html ('</code></pre>');
} # end_code_block

sub code ($$) {
  shift->html ('<code>' . $htescape->(shift) . '</code>');
} # code

sub link ($$%) {
  my ($self, $content, %opt) = @_;
  $self->html ('<a href="' . $htescape->($opt{url}) . '">');
  $self->text ($content);
  $self->html ('</a>');
} # link

sub xref ($$%) {
  my ($self, $content, %opt) = @_;
  $self->html ('<a href="#' . $htescape->($self->input->id_prefix . $opt{target}) . '">');
  $self->text ($content);
  $self->html ('</a>');
} # xref

sub nav_list ($) {
  my $self = shift;
  $self->html (q[<ul class="navigation" id="nav-items">]);
  for (@{$self->{nav}}) {
    $self->html (qq[<li><a href="@{[$htescape->($_->[0])]}">@{[$htescape->($_->[1])]}</a>]);
  }
  $self->html ('</ul>');
} # nav_list

1;

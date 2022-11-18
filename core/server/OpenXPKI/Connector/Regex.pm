package OpenXPKI::Connector::Regex;

use Moose;
extends 'Connector';

use English;

has replace => (
    is  => 'ro',
    isa => 'Str',
    required => 0,
    predicate => 'is_replace'
);

has value => (
    is  => 'ro',
    isa => 'HashRef',
    required => 0,
    predicate => 'is_value',
    reader => 'get_value',
    default => sub { return {}; }
);

has invert => (
    is  => 'ro',
    isa => 'Bool',
    default => 0,
);

has modifier => (
    is  => 'ro',
    isa => 'Str',
    default => 'xi',
);

sub get {

    my $self = shift;
    my @args = $self->_build_path( shift );

    my $regex = $self->LOCATION();
    if (my $modifier = $self->modifier()) {
        $regex = "(?$modifier)$regex" ;
    }

    $self->log()->debug($regex);

    my $res = 1;
    if ($self->is_replace()) {
        my $pattern = shift @args;
        my $replace = $self->replace();

        $self->log()->trace("Replace $pattern with $replace");

        $pattern =~ s{$regex}{$replace};
        $res = $pattern;

        $self->log()->trace("Result after replace $pattern");

    } elsif ($self->invert()) {
        foreach my $p (@args) {
            $res = ($res && ($p !~ m{$regex})) ? 1 : 0;
            $self->log()->trace("Check $p = $res");
            last unless ($res);
        }
    } else {
        foreach my $p (@args) {
            $res = ($res && ($p =~ m{$regex})) ? 1 : 0;
            $self->log()->trace("Check $p = $res");
            last unless ($res);
        }
    }

    return $res;

}

sub get_hash {

    my $self = shift;

    my @args = $self->_build_path( shift );

    my $regex = $self->LOCATION();
    if (my $modifier = $self->modifier()) {
        $regex = "(?$modifier)$regex" ;
    }

    my $res;
    my $val = shift @args;
    if ($self->invert()) {
        $res = ($val !~ m{$regex}) ? 1: 0;
    } else {
        $res = ($val =~ m{$regex}) ? 1: 0;
    }

    $self->log()->debug("Result testing $val against $regex: $res");

    return $self->_node_not_exists( $val ) unless ($res);

    return $self->get_value();

}

sub get_meta {

    my $self = shift;

    return { TYPE  => ($self->is_value() ? "hash" : "scalar") };
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

OpenXPKI::Connector::Regex;

=head1 DESCRIPTION

In I<match> mode (replace is not set), return literal I<0|1> if the given
argument(s) match the expression for any I<get> call. In case multiple
arguments are passed, all arguments must match to get a true result.

If I<get_hash> is called, only a single argument is allowed. If matched, the
value set in the I<value> parameter is returned (default is the empty hash).
If not matched, undef is returned (exception if die_on_undef is set).

If I<invert> is set, the pattern match result is inverted - for each item!
For multiple arguments this means you get a true result only of no value
matches!

In I<replace> mode (allowed with I<get> only), the result of the substituion
is returned, multiple arguments are not supported.

=head2 Configuration

=over

=item LOCATION

The regular expression to check against.

=item modifier

optional, default modifier is I<xi>

=item replace

If set, the connector works in replace mode with the given value placed in
the replace part of the perl substitution operator. C<s{LOCATION}{replace}>.

Only allowed with the I<get> call.

=item value

Only used with I<get_hash> call. Contains a hashref which is returned when
the regex matched.

=back



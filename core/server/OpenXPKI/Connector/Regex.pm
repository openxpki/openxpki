package OpenXPKI::Connector::Regex;

use strict;
use warnings;
use English;
use Moose;

extends 'Connector';

has replace => (
    is  => 'ro',
    isa => 'Str',
    required => 0,
    predicate => 'is_replace'
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

sub get_meta {

    my $self = shift;
    return {TYPE  => "scalar" };
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

OpenXPKI::Connector::Regex;

=head1 DESCRIPTION

In I<match> mode (replace is not set), return literal I<0|1> if the given
argument(s) match the expression. In case multiple arguments are passed,
all arguments must match to get a true result.

If I<invert> is set, the pattern match result is inverted - for each item!
For multiple arguments thie means you get a true result only of no value
matches!

In I<replace> mode, the result of the substituion is returned, multiple
arguments are not supported.

=head2 Configuration

=over

=item LOCATION

The regular expression to check against.

=item replace

If set, the connector works in replace mode with the given value placed in
the replace part of the perl substitution operator. C<s{LOCATION}{replace}>.

=item modifier

optional, default modifier is I<xi>

=back


package OpenXPKI::Server::Workflow::Validator::BooleanHasFields;

use Moose;
extends 'OpenXPKI::Server::Workflow::Validator';

use Workflow::Exception qw( validation_error );
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

sub _validate {

    my ($self, $wf, @args) = @_;

    my $op = $self->param('operator') || 'or';

    my $error = $self->param('error') || 'I18N_OPENXPKI_UI_VALIDATOR_ERROR_BOOLEAN_'.uc($op);

    ##! 64: 'args ' . Dumper \@args
    my $count = scalar @args;
    my $setcount = 0;
    map { $setcount++ if(defined $_ && $_ ne ''); } @args;

    ##! 32: sprintf('Op %s - Count %01d - Setcount %01d', $op, $count, $setcount)

    if ($op eq 'or') {
        validation_error($error) if ($setcount == 0);
    } elsif ($op eq 'xor') {
        validation_error($error) if ($setcount != 1);
    } elsif ($op eq 'and') {
        validation_error($error)
            unless (($setcount == 0) || ($setcount == $count));
    }
    return 1;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::BooleanHasFields

=head1 SYNOPSIS

    class: OpenXPKI::Server::Workflow::Validator::BooleanHasFields
    param:
        operator: or
        error: Please enter at least one value
    arg:
      - $val1
      - $val2

=head1 DESCRIPTION

This validator checks whether the number of arguments set matches the
boolean operator. Set in this validator means not empty or undef, the
literal value I<0> is therefore treated as "true" in the equotation!

Note: The check for I<and> is also true if all values are B<NOT> set, so
this option can be checked if all values exist together. To check for
their general presence simply use the I<required> attribute.

=head2 Argument

A list of (at least two) values to use in boolean equotation.

=head2 Parameter

=over

=item operator

One of I<or>, I<xor>, I<and>

=back

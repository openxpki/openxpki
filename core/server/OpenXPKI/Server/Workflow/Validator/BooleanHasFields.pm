package OpenXPKI::Server::Workflow::Validator::BooleanHasFields;

use strict;
use warnings;
use Moose;
use Workflow::Exception qw( validation_error );
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

extends 'OpenXPKI::Server::Workflow::Validator';

sub _validate {

    my ($self, $wf, $arg1, $arg2) = @_;

    my $op = $self->param('operator') || 'or';

    my $error = $self->param('error') || 'I18N_OPENXPKI_UI_VALIDATOR_ERROR_BOOLEAN_'.uc($op);

    $arg1 = (defined $arg1 && $arg1 ne '');
    $arg2 = (defined $arg2 && $arg2 ne '');

    if ($op eq 'or') {
        validation_error($error)
            unless ($arg1 or $arg2);
    } elsif ($op eq 'xor') {
        validation_error($error)
            unless ($arg1 xor $arg2);
    } elsif ($op eq 'and') {
        validation_error($error)
            unless (($arg1 and $arg2) or (not $arg1 and not $arg2));
    }

    return 1;
}

1;

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

Note: The check for I<and> is also true if both values are B<NOT> set, so
this option is used to check if two values exist together. To check for
their general presence simply use the I<required> attribute.

=head2 Argument

Two values to use in boolean equotation.

=head2 Parameter

=over

=item operator

One of I<or>, I<xor>, I<and>

=back

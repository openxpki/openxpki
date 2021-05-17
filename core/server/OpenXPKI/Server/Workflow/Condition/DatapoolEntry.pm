package OpenXPKI::Server::Workflow::Condition::DatapoolEntry;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

sub _evaluate
{
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;
    my $context     = $workflow->context();

    my $condition = $self->param('condition');

    my $params = {
        namespace => $self->param('namespace'),
        key => $self->param('key'),
    };

    if (!$params->{namespace}) {
        configuration_error('Datapool::GetEntry requires the namespace parameter');
    }
    if (!$params->{key}) {
        configuration_error('Datapool::GetEntry requires the key parameter');
    }

    if ($self->param('pki_realm')) {
        if ($self->param('pki_realm') eq '_global') {
            $params->{pki_realm} = '_global';
        } elsif($self->param('pki_realm') ne CTX('session')->data->pki_realm) {
            workflow_error( 'Access to foreign realm is not allowed' );
        }
    }

    ##! 32: $params

    my $msg = CTX('api2')->get_data_pool_entry(%$params);

    ##! 128: $msg

    my $datapool_value = $msg->{value} //  '';

    ##! 64: $datapool_value
    if ($condition eq 'exists') {
        if (!$msg) {
            ##! 64: ' value does not exist'
            condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOLENTRY_DOES_NOT_EXIST';
        }
    } elsif ($condition eq 'notnull') {
        if ($datapool_value eq '') {
            ##! 64: ' value is empty'
            condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOLENTRY_VALUE_EMPTY';
        }
    } elsif ($condition eq 'equals') {

        my $val = $self->param('value') // configuration_error('You must provide a value to compare');
        if ($datapool_value ne $self->param('value')) {
            ##! 64: ' value equality mismatch '
            condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOLENTRY_EQUALITY_MISMATCH';
        }
    } elsif ($condition eq 'regex') {
        my $val = $self->param('value') || configuration_error('You must provide a non-empty string as regex');
        my $regex = qr/$val/ms;
        if ($datapool_value !~ /$regex/) {
            ##! 64: ' value regex mismatch '
            condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOL_REGEX_MISMATCH';
        }
    } else {
        ##! 64: ' invalid condition '
        condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOLENTRY_INVALID_CONDITION';
    }


    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::DatapoolEntry

=head1 SYNOPSIS
    private_key_not_empty:
        class: OpenXPKI::Server::Workflow::Condition::DatapoolEntry
        param:
            _map_key: $cert_identifier
            namespace: certificate.privatekey
            condition: exists

=head1 DESCRIPTION

Checks if the specified datapool entry exists, is not empty or matches
a given string or regex.

=head2 Parameters

=over

=item namespace

check entries in this namespace (required)

=item key

checks are applied to this datapool entry

=item condition

type of check

=over

=item exists

true if an item with the given namespace/key exists

=item notnull

true if the item defined by namespace/key has an non-empty value. This
case is today almost equal to I<exists>, as the default API methods dont
allow to set an empty value to the datapool.

=item equals

true if the datapool value is equal to the string provided via I<value>.
The check is done as a string comparison, so be aware if you compare
numbers.

=item regex

Compiles I<value> to a regex with modifiers I</ms> and compares it
against the value from the datapool. A non-existing (or empty) value
will match the empty string.

=back

=item value

comparison value for I<regex> or I<equals> check

=back


package OpenXPKI::Server::Workflow::Activity::NICE::RevokeCertificate;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Database; # to get AUTO_ID
use Workflow::Exception qw(configuration_error workflow_error);

use OpenXPKI::Server::NICE::Factory;


sub execute {

    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    ##! 32: 'context: ' . Dumper( $context )

    my $nice_backend = OpenXPKI::Server::NICE::Factory->getHandler( $self );
    my $cert_identifier = $self->param('cert_identifier') || $context->param('cert_identifier');
    my $dbi = CTX('dbi');

    ##! 16: 'start revocation for cert identifier' . $cert_identifier
    my $cert = $dbi->select_one(
        from => 'certificate',
        columns => [ 'identifier', 'reason_code', 'invalidity_time', 'status', 'pki_realm' ],
        where => { identifier => $cert_identifier },
    );

    if (!defined $cert) {
        workflow_error('certificate to be revoked not found in database');
    }

    ##! 64: $cert

    if ($cert->{pki_realm} ne CTX('session')->data->pki_realm) {
        workflow_error('certificate is not in the current realm');
    }

    if ($cert->{status} ne 'ISSUED') {
        workflow_error('certificate to be revoked is not in state "issued"', status => $cert->{status});
    }

    my $param = $self->param();
    delete $param->{'cert_identifier'};
    # prior to v3.22 the revocation was a two step process where the revocation information was
    # persisted into the table using PersistCRR and this method only set the status
    # for backward compatibility we use information from the cert table as fallback before reading the context
    my $reason_code     = $self->param('reason_code') // $cert->{reason_code} || $context->param('reason_code') || 'unspecified';
    my $revocation_time = $self->param('revocation_time') // 0;
    my $invalidity_time = $self->param('invalidity_time') // $cert->{'invalidity_time'} || $context->param('invalidity_time') || 0;
    my $hold_instruction_code = $self->param('hold_instruction_code') // $context->param('hold_instruction_code');


    CTX('log')->application()->info("start cert revocation for identifier $cert_identifier, workflow " . $workflow->id);

    my $res = $nice_backend->revokeCertificate(
        $cert_identifier,
        $reason_code,
        $revocation_time,
        $invalidity_time,
        $hold_instruction_code,
        $param
    );
    ##! 64: $res
    if (!$res) {
        $self->pause('I18N_OPENXPKI_UI_NICE_BACKEND_ERROR');
    } elsif (ref $res eq 'HASH') {
        ##! 64: 'Setting Context ' . Dumper $res
        for my $key (keys %{$res} ) {
            my $value = $res->{$key};
            ##! 64: "Set key: $key to value $value";
            $context->param( $key => $value );
        }
    }

    ##! 32: 'Add workflow id ' . $workflow->id . ' to cert_attributes for cert ' . $cert_identifier
    CTX('dbi')->insert(
        into => 'certificate_attributes',
        values => {
            attribute_key => AUTO_ID,
            identifier => $cert_identifier,
            attribute_contentkey => 'system_workflow_crr',
            attribute_value => $workflow->id,
        }
    );
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::RevokeCertificate

=head1 Description

Start certificate revocation using the configured NICE backend.

Does no longer require to use CRR::PersistRequest before, revocation
details are now set via parameters or read direclty from the context
if they are not set in the certificate table already.

The paramters are passed to the selected backend, see
OpenXPKI::Server::NICE::revokeCertificate and the backend
implementation for details.

=head1 Parameters

=head2 Input

=over

=item reason_code

=item revocation_time

=item invalidity_time

=item hold_instruction_code

=back

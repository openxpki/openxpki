package OpenXPKI::Server::Workflow::Activity::CRR::PersistRequest;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use DateTime;

sub execute
{

    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $pki_realm  = CTX('api2')->get_pki_realm();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $dbi        = CTX('dbi');

    my $identifier = $self->param('cert_identifier') // $context->param('cert_identifier');

    my $cert = $dbi->select_one(
        from => 'certificate',
        columns => [ 'status', 'reason_code', 'revocation_time', 'invalidity_time', 'hold_instruction_code' ],
        where => {
            pki_realm  => $pki_realm,
            identifier => $identifier,
        },
    );
    ##! 64: $cert

    if (!$cert) {
        OpenXPKI::Exception->throw(
            message => 'No such certificate in realm',
            params => {
                pki_realm  => $pki_realm,
                identifier => $identifier,
            }
        );
    }

    my $reason_code = $self->param('reason_code') // $context->param('reason_code') || '';
    my $invalidity_time = $self->param('invalidity_time') // $context->param('invalidity_time') || 0;
    my $hold_code = $self->param('hold_code') // $context->param('hold_code');
    my $revocation_time = $self->param('revocation_time');

    my $enforce = $self->param('enforce') || ($revocation_time ? 'all' : ($reason_code ? 'reason_code' : 'none'));
    $reason_code ||= 'unspecified';
    $revocation_time ||= time();

    # certificate already has CRR data - try to be graceful
    if ($cert->{status} ne 'ISSUED' || $cert->{reason_code}) {

        my $error;
        ##! 16: 'Already revoked and enforce set to ' . $enforce
        ##! 32: $cert
        if ($enforce eq 'all' && ($revocation_time != $cert->{revocation_time})) {
            ##! 16: 'revocation time mismatch'
            $error = 'Unable to persist CRR - already revoked and revocation time mismatches';
        }
        elsif ($enforce ne 'none' && $reason_code ne $cert->{reason_code}) {
            ##! 16: 'reason code mismatch'
            $error = 'Unable to persist CRR - already revoked and reason code mismatches';

        # if keyCompromise timestamp is given this must match
        } elsif ($enforce ne 'none' && $reason_code eq 'keyCompromise' && $invalidity_time && $invalidity_time ne $cert->{invalidity_time}) {
            ##! 16: 'keyCompromise time mismatch ' - $invalidity_time
            $error = 'Unable to persist CRR - already revoked and invalidity time mismatches';

        }

        OpenXPKI::Exception->throw(
            message => $error,
            params => {
                identifier => $identifier,
                status => $cert->{status},
            }
        ) if ($error);
        ##! 8: 'Ignore revocation request as certificate is already revoke'
        CTX('log')->application()->warn("revocation request for $identifier ignored as certificate is already revoked");

    } else {

        ##! 8: 'Updating revocation data'
        $dbi->update(
            table => 'certificate',
            set => {
                reason_code     => $reason_code,
                revocation_time => $revocation_time,
                invalidity_time => $invalidity_time || undef,
                hold_instruction_code => $hold_code || undef,
            },
            where => {
                pki_realm  => $pki_realm,
                identifier => $identifier,
            },
        );

        CTX('log')->application()->debug("revocation request for $identifier written to database");
    }

}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRR::PersistRequest

=head1 Description

persists the Certificate Revocation Request into the database, so that
it can then be used by the CRL issuance workflow. If the certificate is
not in ISSUED state or has already revocation details set, the activity
will throw an exception if the requested details do not match the already
present data. This can be relaxed by the I<enforce> parameter

=head2 Activity Parameters

By default, those values are read from the context items with the same name.
It a key with this name exists in the activity definition, it has precedence
over the context value. If a given key has an empty value, the context is
B<not> used as fallback.

=over

=item cert_identifier

=item reason_code

Must be one of the supported openssl reason codes, default is unspecified

=item invalidity_time

Epoch to be set as "key compromise time", the default backend uses this only
when reason_code is set to keyCompromise.

=item hold_code

Hold code for revocation reason "onHold" (not supported by the default backend).

=item revocation_time

Set revocation_time, default is "now". This parameter must be passed as
activity param and has no fallback to the context.

=item enforce (all|reason_code|none)

The default mode depends on the parameters present in context or as action
parameters. If revocation_time is set, time and reason_code must match. If
no time but reason_code is set, then only the reson_code must match. If
neither one is set, the request is always accepted. In case the reason_code
is keyCompromise and the invalidity_time is set, it must also match as long
as you do not set enforce to I<none>.

If you do not set revocation_time/reason_code but want to stop if revocation
data is present, you can enforce the same check level by explicitly setting
I<all> or I<reason_code>. In this case the checks are done against the
default values.

=back

# OpenXPKI::Server::Workflow::Activity::CertRequest::InsertRequest
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::CertRequest::InsertRequest;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::CertRequest::InsertRequest';

use Data::Dumper;

sub execute
{
    my $self = shift;
    my $workflow = shift;
    my $context = $workflow->context();
    my $pki_realm = CTX('api')->get_api('Session')->get_pki_realm();

    my $dbi = CTX('dbi_backend');
    my $csr_serial = $dbi->get_new_serial(
        TABLE => 'CSR',
    );
    my $type    = $context->param('csr_type');
    my $profile = $context->param('cert_profile');
    my $data;
    if ($type eq 'spkac') {
        $data = $context->param('spkac');
    }
    # TODO: PKCS#10, IE
    else {
        OpenXPKI::Exception->throw(
            message   => 'I18N_OPENXPKI_ACTIVITY_CERTREQUEST_INSERTREQUEST_UNSUPPORTED_CSR_TYPE',
            params => {
                TYPE => $type,
            },
        );
    }

    # TODO: LOA (currently NULL)
    $dbi->insert(
        TABLE => 'CSR',
        HASH  => {
            'PKI_REALM'  => $pki_realm,
            'CSR_SERIAL' => $csr_serial,
            'TYPE'       => $type,
            'DATA'       => $data,
            'PROFILE'    => $profile,
        },
    );
    $dbi->commit();
    $context->param('csr_serial' => $csr_serial);
    ##! 32: 'context: ' . Dumper($context)
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CertRequest::InsertRequest

=head1 Description

inserts the Certificate Signing Request into the database, so that
it can then be used by the certificate issuance workflow.

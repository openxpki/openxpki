# OpenXPKI::Server::Workflow::Activity::Tools::CalculateKeyId
# Written by Oliver Welter for the OpenXPKI project 2012
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::CalculateKeyId;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Digest::SHA qw( sha1_hex );

use Data::Dumper;

sub execute {
    my $self = shift;
    my $workflow = shift;

    ##! 1: 'Start'

    # you may wish to use these shortcuts
    my $context      = $workflow->context();

    my $pki_realm   = CTX('session')->data->pki_realm;
    my $default_token = CTX('api')->get_default_token();

    # The default is to fetch the certificate PEM from the "certificate"
    # context value. An alternative context parameter can be set.
    my $certificate;
    if ($self->param('certificate_key')) {
        $certificate = $context->param($self->param('certificate_key'));
    } else {
        $certificate = $context->param('certificate');
    }
    ##! 32: 'certificate: ' . $certificate

    if (!$certificate) {
      OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CALCULATEKEYID_UNABLE_TO_LOAD_CERTIFICATE'
     );
    }

    my $x509 = OpenXPKI::Crypto::X509->new(
        DATA => $certificate,
        TOKEN => $default_token,
    );

    my $modulus = $x509->get_parsed('BODY', 'MODULUS');
    ##! 16: 'modulus: ' . $modulus

    if (!$modulus) {
      OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CALCULATEKEYID_UNABLE_TO_PARSE_CERTIFICATE'
     );
    }

    # compute PKCS#11 plugin compatible key id
    # remove leading null bytes for hash computation
    $modulus =~ s/^(?:00)+//g;
    my $key_id = sha1_hex(pack('H*', $modulus));

    CTX('log')->application()->debug('calculated key id is ' . $key_id);


    ##! 16: 'pkcs11 plugin keyid hash: ' . $key_id

    my $output_key = $self->param('output_key');
    $output_key = 'key_id' unless($output_key);

    $context->param( { $output_key => $key_id } );

    return;

}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CalculateKeyId

=head1 Description

Compute the PKCS#11 plugin compatible key id from a certificate.

By default, the certificate is read from the context key I<certificate>
and the calculated key is written to I<key_id>. You can specified the used
context keys via action parameters:

    <action name="scpers_calculate_key_id"
        class="OpenXPKI::Server::Workflow::Activity::Tools::CalculateKeyId"
        output_key='key_id'
        certificate_key='certificate'
        >
    </action>


# OpenXPKI::Server::Workflow::Activity::Tools::PublishCA
# Copyright (c) 2015 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::PublishCA;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::DN;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $config        = CTX('config');
    my $pki_realm = CTX('session')->get_pki_realm();

    if (!$self->param('prefix')) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CA_NO_PREFIX'
        );
    }

    my $default_token = CTX('api')->get_default_token();
    my $prefix = $self->param('prefix');
    my $ca_alias = $context->param('ca_alias');

    if (!$ca_alias) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CA_NO_CA_ALIAS'
        );
    }

    ##! 16: "Start publishing - ca alias $ca_alias"

    # split of group and generation from alias
    $ca_alias =~ /^(.*)-(\d+)$/;

    my $data = {
        alias => $ca_alias,
        group => $1,
        generation => $2,
    };

    # Load issuer info
    # FIXME - this might be improved using some caching
    my $certificate = CTX('api')->get_certificate_for_alias( { 'ALIAS' => $ca_alias });
    my $x509 = OpenXPKI::Crypto::X509->new(
        DATA  => $certificate->{DATA},
        TOKEN => $default_token,
    );

    # Get Issuer Info from selected ca
    $data->{dn} = $x509->{PARSED}->{BODY}->{SUBJECT_HASH};
    $data->{subject} = $self->{PARSED}->{BODY}->{SUBJECT};

    $data->{pem} = $x509->get_converted('PEM');
    $data->{der} = $x509->get_converted('DER');

    if (!defined $data->{der} || $data->{der} eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CA_COULD_NOT_CONVERT_CERT_TO_DER',
            log => {
            logger => CTX('log'),
                priority => 'error',
                facility => 'system',
            },
        );
    }

    # Get the list of targets
    my @targets = $config->get_keys( $prefix );

    # If the data point does not exist, we get a one item undef array
    return unless ($targets[0]);

    ##! 16: 'Publish targets at prefix '. $prefix .' -  ' . Dumper ( @targets )

    # FIXME - Use exception handling to compensate failures
    ##! 32: 'Data for publication '. Dumper ( $data )
    foreach my $target (@targets) {
        ##! 32: " $prefix.$target . " . $data->{dn}{CN}[0]
        my $res = $config->set( [ "$prefix.$target.", $data->{dn}{CN}[0] ], $data );
        ##! 16 : 'Publish at target ' . $target . ' - Result: ' . $res

        CTX('log')->log(
            MESSAGE => "CA published at $prefix.$target with CN ".$data->{dn}{CN}[0]." for CA $ca_alias in realm $pki_realm",
            PRIORITY => 'info',
            FACILITY => [ 'system' ],
        );
    }

    ##! 4: 'end'
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::PublishCA

=head1 Description

This activity publishes a single ca certificate. The context must hold the
ca_alias parameter. The data point you specify at prefix must contain
a list of connectors. Each connector is called with the CN of the certificate
as location. The data portion contains a hash ref with the keys I<pem>, I<der>
and I<subject> holding the appropriate strings and I<dn> which is the subject
parsed into a hash as used in the template processing when issuing the certificates.

=head1 Configuration

Set the C<prefix> paramater to tell the activity where to find the connector

    publish_crl:
        class: OpenXPKI::Server::Workflow::Activity::Tools::PublishCA
        label: I18N_OPENXPKI_UI_WORKFLOW_ACTION_CRL_ISSUANCE_PUBLISH_CA_LABEL
        description: I18N_OPENXPKI_UI_WORKFLOW_ACTION_CRL_ISSUANCE_PUBLISH_CA_DESC
        input:
          - ca_alias
        param:
            prefix: publishing.cacert


Set up the connector using this syntax

  publishing:
    cacert:
      repo1@: connector:....
      repo2@: connector:....

To publish the certificate to your LDAP with autocreation of missing nodes,
here is an example connector:

    ldap-cacert:
        class: Connector::Proxy::Net::LDAP::Single
        LOCATION: ldap://localhost:389
        base: ou=pki,dc=mycompany,dc=com
        filter: (cn=[% ARGS.0 %])
        binddn: cn=admin,dc=mycompany,dc=com
        password: admin
        attrmap:
            der: cacertificate;binary

        create:
            basedn: ou=pki,dc=mycompany,dc=com
            rdnkey: cn

        schema:
            cn:
                objectclass: top organizationalRole pkiCA crlDistributionPoint


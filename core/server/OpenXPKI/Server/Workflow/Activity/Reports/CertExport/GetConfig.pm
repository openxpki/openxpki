# OpenXPKI::Server::Workflow::Activity::Reports::CertExport::GetConfig
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Reports::CertExport::GetConfig;

=head1 Name

OpenXPKI::Server::Workflow::Activity::Reports::CertExport::GetConfig

=head1 Description

Load the export config specified by the config_path read from the context.
Looks up the identifiers of the necessary encryption certificates.
The config is written to the workflow context.

=cut

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();

    # Get config id from workflow
    my $config_path = $context->param('config_path');

    my $config = CTX('config');

    $context->param( 'max_records' , $config->get( "$config_path.max_records" ) || 100 );
    $context->param( 'key_namespace', $config->get( "$config_path.key_namespace" ) || 'certificate.privatekey');
    $context->param( 'queue_namespace', $config->get( "$config_path.queue_namespace" ) || 'certificate.export.default');

    # Tempdir and Umask for export file
    $context->param( 'tmpfile_tmpdir' , $config->get( "$config_path.tmpdir" ) || '/var/tmp/' );

    my $umask = $config->get( "$config_path.umask" );
    if ($umask) {
        $context->param( 'tmpfile_umask' , $umask );

        if ( $umask !~ /^0[0-7]{3}$/) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_REPORTS_CERTEXPORT_GETCONFIG_WRONG_UMASK',
                params => { umask => $context->param( 'tmpfile_umask' ) }
            );
        }
    } else {
        $context->param( 'tmpfile_umask', '' );
    }

    # The encryption target is given by subject and realm (optional) or a list of ids
    my $enc_target = $config->get_hash( "$config_path.encryption_target" );

    if (!$enc_target || (!$enc_target->{subject})) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_REPORTS_CERTEXPORT_GETCONFIG_NO_SUBJECT'
        );
    }

    # Realm might be empty
    $enc_target->{realm} = CTX('session')->data->pki_realm unless($enc_target->{realm});

    my $enc_cert = CTX('api')->search_cert({ SUBJECT => $enc_target->{subject}, PKI_REALM => $enc_target->{realm}, VALID_AT => time() });

    my $enc_cert_ids = [ map  $_->{IDENTIFIER} , @{$enc_cert} ];

    ##! 8: 'Enc Target ' . Dumper $enc_cert_ids

    my $ser = OpenXPKI::Serialization::Simple->new();

    $context->param( 'enc_cert_ids' , $ser->serialize( $enc_cert_ids ) );

    ##! 16: 'Config vars : ' . Dumper $context->param()

    CTX('log')->application()->info(sprintf("export config, max records: %01d, queue %s, no of enc targets: %01d",
        $context->param( 'max_records' ), $context->param( 'queue_namespace' ), scalar @{$enc_cert}) );

    return 1;

}

1;

=head1 Name

OpenXPKI::Server::Workflow::Activity::Reports::CertExport::GetConfig

=head1 Description

Load the configuration from the config layer into the workflow context,
setting default values if parameter is missing.

Takes the path to the config from the context value "config_path".

=head1 Configuration

    myexport:
        tmpdir: /var/tmp
        umask: 0640
        max_records: 5
        key_namespace: certificate.privatekey
        queue_namespace: certificate.export.default
        encryption_target:
            subject: CN=Mailgateway,O=MyCompany,C=COM
            realm: server-ca

The keys max_records, key_namespace, queue_namespace are all optional, with the
values above used as default.

The encryption_target hash is used to search for certificates, subject is
mandatory and can contain wildcards as accepted by sql LIKE. The realm defaults
to the sessions realm if not given. The certificate_identifier of all certificates
which are valid at the time of the search are written to enc_cert_ids.

This method is a co-worker for
OpenXPKI::Server::Workflow::Activity::Reports::CertExport::GenerateExportFile
where the params are explained in detail.



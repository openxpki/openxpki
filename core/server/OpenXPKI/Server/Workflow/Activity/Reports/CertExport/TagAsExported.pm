package OpenXPKI::Server::Workflow::Activity::Reports::CertExport::TagAsExported;


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

    my $ser = OpenXPKI::Serialization::Simple->new();

    my $exported_cert_ids = $context->param( 'exported_cert_ids' );
    if (! $exported_cert_ids) {
        return 1;
    }

    foreach my $cert_identifier (@{ $ser->deserialize( $exported_cert_ids ) }) {
        CTX('log')->application()->info('remove '.$cert_identifier.' from export queue');
        # set without value deletes the entry
        CTX('api')->set_data_pool_entry({'NAMESPACE' => $context->param( 'queue_namespace' ) , 'KEY' => $cert_identifier, 'VALUE' => undef  });
    }

    $context->param( 'exported_cert_ids', '' );
    $context->param( 'xml_filename' ,  '');
    $context->param( 'xml_targetname' ,  '' );

    return 1;

}

1;


=head1 Name

OpenXPKI::Server::Workflow::Activity::Reports::CertExport::TagAsExported

=head1 Description

Cleanup activity for the export from
OpenXPKI::Server::Workflow::Activity::Reports::CertExport::GenerateExportFile
removes the export flag entries from the datapool and clears the temporary
values from the context.

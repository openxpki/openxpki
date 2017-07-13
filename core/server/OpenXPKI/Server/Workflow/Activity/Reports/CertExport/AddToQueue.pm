package OpenXPKI::Server::Workflow::Activity::Reports::CertExport::AddToQueue;


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

    my $ser  = OpenXPKI::Serialization::Simple->new();

    my $namespace = $self->param('namespace');
    $namespace  = 'certificate.export.default' unless($namespace);

    ##! 16: 'namespace: ' . $namespace

    my @attrs = split /,/, $self->param('attribs');
    my $export = {};
    foreach my $key (@attrs) {
       $export->{$key} = $self->param($key) || '';
    }

    CTX('log')->application()->info("prepare cert ".$context->param( 'cert_identifier' )." for export");


    ##! 16: 'Mapping attributes: ' . Dumper $export

    CTX('api')->set_data_pool_entry({'NAMESPACE' => $namespace, 'KEY' => $context->param( 'cert_identifier' ), 'VALUE' => $ser->serialize( $export ), 'FORCE' => 1 });

    return 1;

}

1;


=head1 NAME

OpenXPKI::Server::Workflow::Activity::Reports::CertExport::AddToQueue;

=head1 Description

Add an entry to the export queue in the datapool

=head1 Configuration

    <action name="add_to_queue" class="OpenXPKI::Server::Workflow::Activity::Reports::CertExport::AddToQueue"
         namespace="certificate.export.default"
         _map_certType="enc"
         _map_email="$email"/>

The namespace parameter is used as the datapool namespace, the datapool key is
set to the certificate identifier. Any parameter starting with I<_map_> is
added to the datapool as attribute for the exporter. Mapped parameters starting
with a $ are treated as context keys.


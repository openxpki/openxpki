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
    	
    my $params = $self->param();
    
    my $ser  = OpenXPKI::Serialization::Simple->new();
    
    my $namespace = $params->{'namespace'};
    $namespace  = 'certificate.export.default' unless($namespace);
       
    ##! 16: 'namespace: ' . $namespace  

    # Check for mapping params
    my $vars = {};
    foreach my $key (keys %{$params}) {
        if ($key !~ /^_map_(.*)/) { next; }
        my $name = $1;
        my $val = $params->{$key};
        ##! 8: 'Found param ' . $name . ' - value : ' . $val
                
        # copy from context?
        if ($val =~ /^\$(\S+)/) {
            my $ctx = $1;
            ##! 16: 'resolve context key ' . $ctx 
            $val = $context->param($ctx);             
            $vars->{$name} = $val if($val);    
        } else { 
            $vars->{$name} = $val;
        } 
                
    }

    ##! 16: 'Mapping attributes: ' . Dumper $vars  
    
    CTX('api')->set_data_pool_entry({'NAMESPACE' => $namespace, 'KEY' => $context->param( 'cert_identifier' ), 'VALUE' => $ser->serialize( $vars ), 'FORCE' => 1 });

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


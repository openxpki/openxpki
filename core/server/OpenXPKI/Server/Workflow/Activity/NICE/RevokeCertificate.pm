# OpenXPKI::Server::Workflow::Activity::NICE::RevokeCertificate
# Written by Oliver Welter for the OpenXPKI Project 2011
# Copyright (c) 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::NICE::RevokeCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use OpenXPKI::Server::Workflow::NICE::Factory;

use Data::Dumper;

sub execute {
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    
    ##! 32: 'context: ' . Dumper( $context )
    
    my $nice_backend = OpenXPKI::Server::Workflow::NICE::Factory->getHandler( $self );
    
	my $crr_serial = $context->param('crr_serial');	
	my $dbi = CTX('dbi_backend');
	
    ##! 16: 'searching for crr serial ' . $crr_serial
	my $crr = $dbi->first(
	    TABLE   => 'CRR',
	    COLUMNS => [ 'REASON_CODE', 'IDENTIFIER' ],	    
		KEY => $crr_serial,		   	    
    );
    
    if (! defined $crr) {
	   OpenXPKI::Exception->throw(
	       message => 'I18N_OPENXPKI_SERVER_NICE_CRR_NOT_FOUND_IN_DATABASE',
	       params => { crr_serial => $crr_serial }
       );
    }
      
    CTX('log')->log(
        MESSAGE  => "start cert revocation for crr_serial $crr_serial, workflow " . $workflow->id,
        PRIORITY => 'info',
        FACILITY => 'application',
    );
           
    $nice_backend->revokeCertificate( $crr );

    # add the crr workflow id to the cert attributes table    
    my $serial = CTX('dbi_backend')->get_new_serial(
        TABLE => 'CERTIFICATE_ATTRIBUTES',
    );
    ##! 32: 'Add workflow id ' . $workflow->id.' to cert_attributes with key ' . $serial . ' for cert ' . $set_context->{cert_identifier} 
    CTX('dbi_backend')->insert(
        TABLE => 'CERTIFICATE_ATTRIBUTES', 
        HASH => {
            ATTRIBUTE_SERIAL => $serial,
            IDENTIFIER => $context->param('cert_identifier'),
            ATTRIBUTE_KEY => 'system_crr_workflow',
            ATTRIBUTE_VALUE => $workflow->id
        }
    );          
    CTX('dbi_backend')->commit();       
    	
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::RevokeCertificate;

=head1 Description

Activity to start certificate revocation using the configured NICE backend.

See OpenXPKI::Server::Workflow::NICE::revokeCertificate for details
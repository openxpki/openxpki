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
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    ##! 32: 'context: ' . Dumper( $context )

    my $nice_backend = OpenXPKI::Server::Workflow::NICE::Factory->getHandler( $self );
	my $crr_serial = $context->param('crr_serial');
	my $dbi = CTX('dbi');

    ##! 16: 'searching for crr serial ' . $crr_serial
	my $crr = $dbi->select_one(
	    from => 'crr',
	    columns => [ 'identifier' ],
		where => { crr_key => $crr_serial },
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

    $nice_backend->revokeCertificate( { IDENTIFIER => $crr->{identifier} } );

    ##! 32: 'Add workflow id ' . $workflow->id.' to cert_attributes ' for cert ' . $set_context->{cert_identifier}
    CTX('dbi')->insert(
        into => 'certificate_attributes',
        values => {
            identifier => $context->param('cert_identifier'),
            attribute_contentkey => 'system_workflow_crr',
            attribute_value => $workflow->id,
        }
    );
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::RevokeCertificate;

=head1 Description

Activity to start certificate revocation using the configured NICE backend.

See OpenXPKI::Server::Workflow::NICE::revokeCertificate for details
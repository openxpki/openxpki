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
use OpenXPKI::Server::Database; # to get AUTO_ID

use OpenXPKI::Server::Workflow::NICE::Factory;

use Data::Dumper;

sub execute {
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    ##! 32: 'context: ' . Dumper( $context )

    my $nice_backend = OpenXPKI::Server::Workflow::NICE::Factory->getHandler( $self );
    my $cert_identifier = $self->param('cert_identifier') || $context->param('cert_identifier');
    my $dbi = CTX('dbi');

    ##! 16: 'start revocation for cert identifier' . $cert_identifier
    my $cert = $dbi->select_one(
        from => 'certificate',
        columns => [ 'identifier', 'reason_code', 'invalidity_time', 'status' ],
        where => { identifier => $cert_identifier },
    );

    if (! defined $cert) {
       OpenXPKI::Exception->throw(
           message => 'nice certificate to revoked not found in database',
           params => { identifier => $cert_identifier }
       );
    }

    if ($cert->{status} ne 'ISSUED') {
        OpenXPKI::Exception->throw(
            message => 'certificate to be revoked is not in issued state',
            params => { identifier => $cert_identifier, status => $cert->{status} }
        );
    }

    if (!$cert->{reason_code}) {
        OpenXPKI::Exception->throw(
            message => 'nice certificate to be revoked has no reason code set',
            params => { identifier => $cert_identifier }
        );
    }

    CTX('log')->application()->info("start cert revocation for identifier $cert_identifier, workflow " . $workflow->id);

    $nice_backend->revokeCertificate( {
        cert_identifier => $cert->{identifier},
        reason_code => $cert->{reason_code},
        invalidity_time => $cert->{invalidity_time},
    } );

    ##! 32: 'Add workflow id ' . $workflow->id.' to cert_attributes ' for cert ' . $set_context->{cert_identifier}
    CTX('dbi')->insert(
        into => 'certificate_attributes',
        values => {
            attribute_key => AUTO_ID,
            identifier => $cert->{identifier},
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

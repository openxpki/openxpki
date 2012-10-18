# OpenXPKI::Server::Workflow::Condition::CertificateHasStatus
# Written by Oliver Welter for the OpenXPKI project 2012
# Copyright (c) 2012 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::CertificateHasStatus;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Debug;
use English;
use OpenXPKI::Exception;

__PACKAGE__->mk_accessors( 'expected_status' );

sub _init
{
    my ( $self, $params ) = @_;
    unless ( defined $params->{'expected_status'}  )    
    {
        configuration_error
             "You must define one value for 'expected_status' in ",
             "declaration of condition ", $self->name;
    }
    $self->expected_status($params->{'expected_status'});
}

sub evaluate
{
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;
    my $context     = $workflow->context();
    my $identifier  = $context->param('cert_identifier');
    my $pki_realm   = CTX('session')->get_pki_realm();

    if (! defined $identifier) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CERTIFICATE_HAS_STATUS_IDENTIFIER_MISSING',
        );
    }
    CTX('dbi_backend')->commit();
    my $cert = CTX('dbi_backend')->first(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
            'STATUS',
        ],
        DYNAMIC => {
            'IDENTIFIER' => $identifier,
            'PKI_REALM'  => $pki_realm,
        }
    );
    ##! 16: 'status: ' . $cert->{'STATUS'}
    
    if ($cert->{'STATUS'} ne $self->expected_status) {
        condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CERTIFICATE_HAS_STATUS_DOES_NOT_MATCH';
    }
     
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CertificateHasStatus

=head1 DESCRIPTION

The condition checks if the certificate identified by cert_identifier
has the status given in the parameter expected_status


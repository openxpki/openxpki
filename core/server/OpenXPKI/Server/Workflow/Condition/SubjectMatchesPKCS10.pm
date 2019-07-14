## Written 2011 by Oliver Welter <openxpki@oliwel.de>
## Based on  OpenXPKI::Server::Workflow::Condition::PKCS10;
## for the OpenXPKI project
## (C) Copyright 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Condition::SubjectMatchesPKCS10;

use strict;
use warnings;
use base qw( Workflow::Condition);
use Workflow::Exception qw( workflow_error );
use OpenXPKI::Crypt::PKCS10;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

sub evaluate {

    ##! 1: 'start'
    my ( $self, $workflow ) = @_;

    my $context     = $workflow->context();

    my $subject  = $context->param('cert_subject');
    my $pkcs10  = $context->param('pkcs10');


    # allow empty pkcs10 for server-side key generation
    if (not $pkcs10)
    {
        return 1;
    }

    # parse PKCS#10 request
    my $default_token = CTX('api')->get_default_token();

    my $csr = OpenXPKI::Crypt::PKCS10->new( $pkcs10 );
    if (!$csr) {
        workflow_error("Unable to parse PKCS10");
    }

    my $parsed_subject = $csr->get_subject();
    if (! defined $parsed_subject) {
        workflow_error("Unable to get subkect from PKCS10");
    }

    CTX('log')->application()->debug("Subject mismatch $subject != $parsed_subject");

    condition_error( "subject mismatch pkcs10" )
        if ( $subject != $parsed_subject );

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::SubjectMatchesPKCS10

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="SubjectMatchesPKCS10"
           class="OpenXPKI::Server::Workflow::Validator::SubjectMatchesPKCS10">
    <arg value="$cert_subject"/>
    <arg value="$pkcs10"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks if the passed subject string is equal to the one
contained in the pkcs10 request. The validator assumes a properly formated
pkcs10 request, if you are unsure put OpenXPKI::Server::Workflow::Validator::PKCS10
in front of this validator.

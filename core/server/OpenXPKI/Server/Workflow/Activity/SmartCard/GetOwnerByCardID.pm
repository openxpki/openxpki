# OpenXPKI::Server::Workflow::Activity::SmartCard::GetOwnerByCardID
# Written by Scott Hardin and Martin Bartosch for the OpenXPKI project 2012
#
# Obtain owner of a given Smartcard using the Connector infrastructure
#
# Based on OpenXPKI::Server::Workflow::Activity::Skeleton,
# written by Martin Bartosch for the OpenXPKI project 2005
#
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::GetOwnerByCardID;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
    ##! 1: 'Entered GetLDAPByCardID::execute()'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();

    my $config = CTX('config');

    my $tokenid = $context->param('token_id');

    # get holder from connector
    my $res =
      $config->walkQueryPoints( 'smartcard.card2user', $tokenid, 'get' );
    my $holder_id = $res->{VALUE};

    if ( !$holder_id ) {
        OpenXPKI::Exception->throw(
            message =>
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETOWNERBYCARDID',
            params => { TOKEN_ID => $tokenid, },
            log    => {
                priority => 'error',
                facility => 'application',
            },
        );
    }

    # now get required user data entries for this user
    my $employeeinfo =
      $config->walkQueryPoints( 'smartcard.employee', $holder_id,
        { call => 'get_hash', deep => 1 } );

    if ( !$employeeinfo ) {
        OpenXPKI::Exception->throw(
            message =>
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETOWNERBYCARDID_SEARCH_PERSON_FAILED',
            params => { EMPLOYEEID => $holder_id },
            log    => {
                priority => 'error',
                facility => 'application'
            },
        );
    }
    if ( !$employeeinfo->{VALUE}->{mail} ) {
        OpenXPKI::Exception->throw(
            message =>
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETOWNERBYCARDID_PERSON_ENTRY_DOES_NOT_HAVE_MAIL_ATTRIBUTE',
            params => { EMPLOYEEINFO => $employeeinfo->{VALUE} },
            log    => {
                priority => 'error',
                facility => 'application',
            },
        );
    }

    CTX('log')->application()->info("SmartCard got owner for $tokenid, ". $employeeinfo->{VALUE}->{mail} ." / ". $employeeinfo->{VALUE}->{cn});


    $context->param( 'owner_mail' => $employeeinfo->{VALUE}->{mail} );
    $context->param( 'owner_cn'   => $employeeinfo->{VALUE}->{cn} );

    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::GetOwnerByCardID

=head1 Description

Obtain the holder of a Smartcard (by querying the connector)
Duplicates the methods used in API::Smartcard to first find the
employee-id and then get the user information.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item token_id

The id of the smartcard

=back

After completion the following context parameters will be set:

=over 12

=item owner_mail

Mailaddress of the owner as returned by the connector

=item owner_cn

CN of the owner

=back

=head1 Functions

=head2 execute

Executes the action.

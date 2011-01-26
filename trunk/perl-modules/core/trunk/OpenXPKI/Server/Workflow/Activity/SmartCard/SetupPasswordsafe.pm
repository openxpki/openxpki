# OpenXPKI::Server::Workflow::Activity::SmartCard::SetupPasswordsafe
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::SetupPasswordsafe;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;


sub execute {
    ##! 1: 'start'
    my $self      = shift;
    my $workflow  = shift;
    my $context   = $workflow->context();
    my $pki_realm = CTX('session')->get_pki_realm();
    my $dbi       = CTX('dbi_backend');
    my $api       = CTX('api');

    my $passwordsafe_workflow_title = 'I18N_OPENXPKI_WF_TYPE_PASSWORD_SAFE';
    my $passwordsafe_key_prefix = $self->param('safeprefix') || '';

    my $passwordsafe_workflow_id;

    my $creator = $context->param('creator');

    # first try to find an existing passwordsafe workflow that may be used
    # for storing secrets or that may hold existing data for this user
    ##! 16: 'searching passwordsafe workflow containing enrypted pw for user ' . $creator
    my $db_results = $dbi->select(
        TABLE => [
	    'WORKFLOW',
            [ 'WORKFLOW_CONTEXT' => 'context1' ],
        ],
        COLUMNS => [
            'WORKFLOW.WORKFLOW_SERIAL',
        ],
        DYNAMIC => {
            'context1.WORKFLOW_CONTEXT_KEY'   => 
		$passwordsafe_key_prefix . $creator,
            'WORKFLOW.PKI_REALM'              => $pki_realm,
	    'WORKFLOW.WORKFLOW_TYPE'          => $passwordsafe_workflow_title,
        },
        JOIN => [
            [
                'WORKFLOW_SERIAL',
                'WORKFLOW_SERIAL',
            ],
        ],
    );

    ##! 16: 'matching passwordsafe workflows: ' . Dumper $db_results

    if (! defined $db_results || ref $db_results ne 'ARRAY') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_SMARTCARD_SETUPPASSWORDSAFE_WF_CONTEXT_QUERY_FAILED',
	    );
    } elsif (scalar @{$db_results} == 0) {
	##! 16: 'no existing passwordsafe workflow found, creating a new one'
	my $wf_info = $api->create_workflow_instance({
            WORKFLOW      => $passwordsafe_workflow_title,
            PARAMS        => {},
        });
        $passwordsafe_workflow_id = $wf_info->{WORKFLOW}->{ID};
    } else {
	##! 16: 'use existing passwordsafe workflow'
	if (scalar @{$db_results} > 1) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_SMARTCARD_SETUPPASSWORDSAFE_MULTIPLE_PASSWORDSAFES_FOUND_FOR_USER',
		);
	}

	$passwordsafe_workflow_id = $db_results->[0]->{'WORKFLOW.WORKFLOW_SERIAL'};
    }

    if (! defined $passwordsafe_workflow_id) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_SMARTCARD_SETUPPASSWORDSAFE_CANNOT_DETERMINE_PASSWORDSAFE_WF_ID',
	    );
    }

    ##! 1: 'passwordsafe workflow for user ' . $creator . ' is ' . $passwordsafe_workflow_id
    $context->param('passwordsafe_workflow_id' => $passwordsafe_workflow_id);

    return 1;
}
1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::SetupPasswordsafe

=head1 Description

This class initializes the workflow for using the required password safe.
It tries to find a passwordsafe workflow which contains a workflow context
key that matches the creator of the workflow instance. The creator can
be prefixed by a string that is configurable in the activity config.
If no existing passwordsafe workflow is found, it will create a new one.

Configuration (activity definition):
safeprefix                String to prepend to the wf creator

Context parameter (output):
passwordsafe_worfklow_id  Numerical workflow ID of passwordsafe



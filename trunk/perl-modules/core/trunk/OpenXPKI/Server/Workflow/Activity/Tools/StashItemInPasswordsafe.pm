# OpenXPKI::Server::Workflow::Activity::Tools:StashItemInPasswordsafe
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::StashItemInPasswordsafe;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $keyentry = $self->param('contextkeyentry');
    my $valueentry = $self->param('contextvalueentry');
    my $safeprefix = $self->param('safeprefix') || '';

    my $ser = OpenXPKI::Serialization::Simple->new(
	{
	    SEPARATOR => '-',
	});

    my $key = $context->param($keyentry);
    ##! 64: 'keyentry: ' . $keyentry
    my $value = $context->param($valueentry);
    ##! 64: 'valueentry: ' . $valueentry

    my $passwordsafe_id = $context->param('passwordsafe_workflow_id');
    if (! defined $passwordsafe_id) {
	$passwordsafe_id = $context->param('_passwordsafe_workflow_id');
    }
    ##! 64: 'passwordsafe_id: ' . $passwordsafe_id

    my $passwordsafe_workflow_title = 'I18N_OPENXPKI_WF_TYPE_PASSWORD_SAFE';

    # sanity checks
    if (! defined $keyentry) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_STASHITEMINPASSWORDSAFE_MISSING_KEYENTRY_DEFINITION',
	    params => {
		contextkeyentry => $keyentry,
		contextvalueentry => $valueentry,
		safeprefix => $safeprefix,
		passwordsafe => $passwordsafe_id,
	    },
	    );
    }

    if (! defined $valueentry) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_STASHITEMINPASSWORDSAFE_MISSING_VALUEENTRY_DEFINITION',
	    params => {
		contextkeyentry => $keyentry,
		contextvalueentry => $valueentry,
		safeprefix => $safeprefix,
		passwordsafe => $passwordsafe_id,
	    },
	    );
    }

    if (! defined $key) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_STASHITEMINPASSWORDSAFE_NO_KEY_FOUND_IN_CONTEXT',
	    params => {
		contextkeyentry => $keyentry,
		contextvalueentry => $valueentry,
		safeprefix => $safeprefix,
		passwordsafe => $passwordsafe_id,
	    },
	    );
    }

    if (! defined $passwordsafe_id || ($passwordsafe_id !~ m{ \A \d+ \z }xms)) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_STASHITEMINPASSWORDSAFE_INVALID_PASSWORDSAFE_ID',
	    params => {
		contextkeyentry => $keyentry,
		contextvalueentry => $valueentry,
		safeprefix => $safeprefix,
		passwordsafe => $passwordsafe_id,
	    },
	    );
    }


    ##! 16: 'stashing data in passwordsafe'

    # DeuBa-specific: retrieve serial number from serialized 'password'
    # and store it in the serial_$id context parameter:

    my $data = {
	SerialNumber => 1,
	Password => $value,
    };
    my $serialized_data = $ser->serialize($data);

    # disabled for now, we simulate this first
    #$context->param('pwsafe_' . $key => $value);

    CTX('api')->execute_workflow_activity(
	{
 	    ID => $passwordsafe_id,
 	    WORKFLOW => $passwordsafe_workflow_title,
 	    ACTIVITY => 'store_password',
 	    PARAMS => {
 		_input_data => {
 		    $safeprefix . $key => $serialized_data,
 		},
 	    },
 	});
    
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::StashItemInPasswordsafe

=head1 Description

Writes a context entry to a PasswordSafe.

Configuration (activity definition):
contextkeyentry           Specifies which context entry to pick as password
                          safe key
contextvalueentry         Specifies which context entry to write as password
                          safe value
safeprefix                String to prepend to the password safe key entry


Runtime variables (from context):
passwordsafe_workflow_id   Workflow ID of a usable passwordsafe
_passwordsafe_workflow_id  Workflow ID of a usable passwordsafe (if previous
                           entry is not set)

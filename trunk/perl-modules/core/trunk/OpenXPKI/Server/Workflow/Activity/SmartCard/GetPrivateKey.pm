# OpenXPKI::Server::Workflow::Activity::SmartCard::GetPrivateKey
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::GetPrivateKey;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();

    ##! 16: 'GetPrivateKey'
    my %contextentry_of = (
	certidentifier => 'enc_cert_identifier',
	privatekey    => 'private_key',
	privatekeyout => '_private_key',
	passwordsafeid => 'passwordsafe_workflow_id',
	passwordsafeidout => '_passwordsafe_workflow_id',
	);

    foreach my $contextkey (keys %contextentry_of) {
	if (defined $self->param($contextkey . 'contextkey')) {
	    $contextentry_of{$contextkey} = $self->param($contextkey . 'contextkey');
	}
    }

    my $key = $context->param($contextentry_of{'privatekey'});
    my $passwordsafe_id = $context->param($contextentry_of{'passwordsafeid'});

    if (defined $key && defined $passwordsafe_id) {
	##! 16: 'copying entries from local context'
	$context->param($contextentry_of{'privatekeyout'} => $key);
	$context->param($contextentry_of{'passwordsafeidout'} => $passwordsafe_id);
	return 1;
    } else {
	my $enc_cert_identifier = $context->param($contextentry_of{'certidentifier'});

	if (! defined $enc_cert_identifier) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_GETPRIVATEKEY_NO_ENC_CERT_IDENTIFIER_FOUND_IN_CONTEXT',
		params  => {
		},
		);
	}
	##! 16: "local context does not contain requested privatekey, query existing workflows; enc_cert_identifier: $enc_cert_identifier"

	# try to find existing personalization workflow that contains
	# the private key for this user
	my $entries = CTX('dbi_backend')->select(
	    TABLE => [ 
		[ 'WORKFLOW_CONTEXT'      => 'context1'],
		[ 'WORKFLOW_CONTEXT_BULK' => 'context2'],
		[ 'WORKFLOW_CONTEXT'      => 'context3'],
	    ],
	    COLUMNS => [
		'context2.WORKFLOW_CONTEXT_VALUE_BULK',
		'context3.WORKFLOW_CONTEXT_VALUE',
	    ],
	    DYNAMIC => {
		'context1.WORKFLOW_CONTEXT_KEY'   => 'enc_cert_identifier',
		'context1.WORKFLOW_CONTEXT_VALUE' => $enc_cert_identifier,

		'context2.WORKFLOW_CONTEXT_KEY'   => 'private_key',

		'context3.WORKFLOW_CONTEXT_KEY'   => 'passwordsafe_workflow_id',
	    },
	    JOIN => [ 
		[ 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL', ],
	    ],
	    REVERSE => 1,
	    );

	# FIXME: REMOVEME
	##! 16: 'entries found: ' . Dumper $entries
	if (! defined $entries) {
	    ##! 16: 'error: could not execute database query'
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_GETPRIVATEKEY_QUERY_ERROR',
		params  => {
		},
		);
	}

	my $private_key;
	my $passwordsafe_id;
	foreach my $entry (@{$entries}) {
	    $private_key ||= $entry->{'context2.WORKFLOW_CONTEXT_VALUE_BULK'};
	    $passwordsafe_id ||= $entry->{'context3.WORKFLOW_CONTEXT_VALUE'};
	}

	if (defined $private_key) {
	    # FIXME: REMOVEME
	    ##! 16: 'found private key: ' . $private_key
	    ##! 16: 'copying private key from existing workflow'
	    $context->param($contextentry_of{'privatekeyout'} => $private_key);
	}

	if (defined $passwordsafe_id) {
	    ##! 16: 'found passwordsafe id: ' . $passwordsafe_id
	    ##! 16: 'copying private key from existing workflow'
	    $context->param($contextentry_of{'passwordsafeidout'} => $passwordsafe_id);
	}
    }
    
    return 1;
}
1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::GetPrivateKey

=head1 Description

This class retrieves a private key from its source and writes it to
the context. The source of the private key can be

1. the workflow's own context (first priority)
2. another workflow's context (second priority)

(The rationale behind is that a SmartCard personalization workflow
may use an existing private key that was generated before for the user
to re-install an existing encryption certificate on the token in case
of lost or damaged hardware.)

If the current workflow contains the private key context entry,
this activity copies its contents to the output context value.

Otherwise it searches for an existing SmartCard personalization workflow 
for the encryption certificate specified by the certificate identifier
enc_cert_identifier (from local context) and copies the private key 
from this workflow.



Input parameter (from context):
private_key          Private key to copy to output context value, optional
enc_cert_identifier  Encryption certificate identifier for which the key
                     should be retrieved

Output parameters (to context):
_private_key         Copy of the private key to use for this workflow


These are the default context parameters. By setting the following activity
parameters you can override these context parameters:

Activity configuration:
certidentifiercontextkey      context parameter to use for input cert identifier
privatekeycontextkey          context parameter to use for input private key
privatekeyoutcontextkey       context parameter to use for output private key
passwordsafeidcontextkey      context parameter to use for input password safe id
passwordsafeidoutcontextkey   context parameter to use for output password safe id



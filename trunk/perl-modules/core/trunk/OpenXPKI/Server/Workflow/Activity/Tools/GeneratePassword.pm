# OpenXPKI::Server::Workflow::Activity::Tools:GeneratePassword:
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::GeneratePassword;

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
    my $default_token = CTX('pki_realm_by_cfg')->
                           {$self->config_id()}->
                           {$self->{PKI_REALM}}->{crypto}->{default};

    my $password_length = $context->param('_password_length');
    if (! defined $password_length) {
	$password_length = $self->param('_password_length');
    }
    if (! defined $password_length) {
	$password_length = 16;
    }

    
    ##! 16: 'pw length: ' . $password_length

    if ($password_length !~ m{ \A \d+ \z }xms) {
	OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_GENERATEPASSWORD_INVALID_LENGTH',
            params  => {
		PASSWORD_LENGTH => $password_length,
            },
	    );
    }

    # command definition
    my $command = {
         COMMAND    => 'create_random',
	 RETURN_LENGTH => $password_length,
	 RANDOM_LENGTH => $password_length,
    };

    ##! 16: 'command: ' . Dumper $command
    my $password = $default_token->command($command);

#     CTX('log')->log(
# 	MESSAGE => 'Created ' . $password_length . ' random characters key for ' . $context->param('creator'),
# 	PRIORITY => 'info',
# 	FACILITY => 'audit',
# 	);

    # sanitize password

    # truncate password to maximum length
    $password = substr($password, 0, $password_length);

    # pass on the password
    $context->param('_password'   => $password);
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::GeneratePassword

=head1 Description

Creates a random password string. The length of the generated string
is determined by the _password_length parameter. It is taken from the
context first. If it is not found in the context, it is read from the
activity definition instead. If neither is defined, a default length of 16
is used.

The generated random string is written to the context parameter
_password.


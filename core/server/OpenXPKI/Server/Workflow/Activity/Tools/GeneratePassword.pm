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

sub execute {
    my $self          = shift;
    my $workflow      = shift;
    my $context       = $workflow->context();

    my $default_token = CTX('api')->get_default_token();

    my $password_length = $context->param('_password_length');
    if ( !defined $password_length ) {
        $password_length = $self->param('_password_length');
    }
    if ( !defined $password_length ) {
        $password_length = $self->param('password_length');
    }
    if ( !defined $password_length ) {
        $password_length = 16;
    }

    my $password_policy = $self->param('password_policy') || '';

    my $password  = '';
    my $policy_ok = 0;

    while ( not $policy_ok ) {
        ##! 16: 'pw length: ' . $password_length

        if ( $password_length !~ m{ \A \d+ \z }xms ) {
            OpenXPKI::Exception->throw(
                message =>
                    'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_GENERATEPASSWORD_INVALID_LENGTH',
                params => { PASSWORD_LENGTH => $password_length, },
            );
        }

        # command definition
        my $command = {
            COMMAND       => 'create_random',
            RETURN_LENGTH => $password_length,
            RANDOM_LENGTH => $password_length,
        };

        ##! 16: 'command: ' . Dumper $command
        $password = $default_token->command($command);

        # sanitize password

        if ( $password_policy eq 'alphanum_5min' ) {
            $password = lc($password);
            $password =~ s/[^a-z0-9]//g;

            if (    ( length($password) >= 5 )
                and ( $password =~ /([a-z][0-9]|[0-9][a-z])/ ) )
            {
                $policy_ok++;
            }

        }
        else {
            $policy_ok++;
        }
    }

    # truncate password to maximum length
    $password = substr( $password, 0, $password_length );

    CTX('log')->application()->debug('Generated random password with length ' . $password_length);


    # pass on the password
    $context->param( '_password' => $password );
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

Optionally, the action parameter I<password_policy> may be set to specify
the password policy to apply to the generated password.

The currently supported policies are:

=over

=item alphanum_5min

The password will consist of one or more lowercase letters and one or more
digits, with a minimum of 5 characters. No other characters (e.g. symbols)
are allowed.

=back

B<Note:> The tuncate done by the the password_length parameter. This value
must fit to the selected password policy.

The generated random string is written to the context parameter
_password.


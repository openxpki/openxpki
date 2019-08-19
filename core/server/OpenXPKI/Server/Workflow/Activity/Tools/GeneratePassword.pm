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
use Workflow::Exception qw( configuration_error );

use Data::Dumper;

sub execute {
    my $self          = shift;
    my $workflow      = shift;
    my $context       = $workflow->context();

    my $default_token = CTX('api2')->get_default_token();

    my $password_length = $self->param('length') || 16;

    configuration_error('Password length must be an integer value') if ( $password_length !~ m{ \A \d+ \z }xms );

    my $password_policy = $self->param('policy') || '';

    my $password  = $default_token->command({
        COMMAND       => 'create_random',
        RETURN_LENGTH => $password_length,
        RANDOM_LENGTH => $password_length,
    });

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
is determined by the length parameter. If not set a default length of 16
is used.

The generated random string is written to the context parameter
_password.


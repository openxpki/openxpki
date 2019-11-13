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

    my $target_key = $self->param('target_key') || '_password';
    # not supported yet
    #my $password_policy = $self->param('policy') || '';
    my $password_length = $self->param('length') || '0';
    my $random_bytes = $self->param('bytes') || '0';
    if ($random_bytes && $password_length) {
        configuration_error('You must not set length AND bytes');
    }

    # as encoded version is always longer as binary we just get some
    # more data as required as it is easier than calculating the
    # correct number of bytes here
    if (!$random_bytes && !$password_length) {
        $password_length  = 16;
    }

    configuration_error('Random bytes must be an integer value') if ( $random_bytes !~ m{ \A \d+ \z }xms );
    configuration_error('Password length must be an integer value') if ( $password_length !~ m{ \A \d+ \z }xms );

    my $charset = $self->param('charset') || 'base64';
    configuration_error('Unsupported charset') if ( $charset !~ m{ \A (base64|hex) \z }xms );

    my $password = CTX('api2')->get_default_token()->command({
        COMMAND => 'create_random',
        BINARY => ($charset ne 'base64'),
        RANDOM_LENGTH => $random_bytes || $password_length
    });

    if ($charset eq 'hex') {
        $password = unpack("H*", $password);
    }

    if ($password_length) {
        $password = substr($password, 0, $password_length);
        if (length($password) != $password_length) {
            workflow_error('Unable to generate password');
        }
    }

    CTX('log')->application()->debug('Generated random password with charset '.$charset.' and length ' . $password_length);

    # pass on the password
    $context->param( $target_key => $password );
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::GeneratePassword

=head1 Description

Creates a random password string.

You can specify either the length of the generated string setting
I<length> or provide the number of random bytes with I<bytes>. You
must not set both.

You can set the charset that will be used for the password with
I<charset>.

The default are 16 characters in base64 encoding which is equal to
an entropy of 12 byte.

You can set the context key to write the password to using I<target_key>,
the default is I<_password>.

=head2 Parameters

=over

=item length

The length in characters of the generated password.

=item bytes

The number of random input bytes.

=item charset

Character set for the generated string, possible options I<base64> and
I<hex> (lowercase).

=back


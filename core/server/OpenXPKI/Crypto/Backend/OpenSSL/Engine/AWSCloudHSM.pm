use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Engine::AWSCloudHSM;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Engine);

sub get_engine
{
    return "cloudhsm";
}

sub get_keyform
{
    return "";
}

sub get_password
{
    return;
}

1;

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Engine::AWSCloudHSM

=head1 Description

This class implements an interface for the AWS Cloud HSM using the
dynamic engine driver and the fake key files. The credentials for
the HSM must be set via the environment from outside OpenXPKI as
documented by AWS.

This class sets "-engine cloudhsm" and forces the internal password to
be undef, it does not support any additional engine parameters.

=head1 Configuration

Set I<engine: AWSCloudHSM> and set the I<key> attribute to point to
the fake-key file (supports local file or datapool as with plain
OpenSSL software keys).

=head1 Functions

=head2 get_engine

returns the used OpenSSL engine 'cloudhsm'.

=head2 get_keyform

returns ""

=head2 get_passwd

returns undef

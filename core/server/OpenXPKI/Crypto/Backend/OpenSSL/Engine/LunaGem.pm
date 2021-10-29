use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Engine::LunaGem;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Engine);

sub get_engine
{
    return "gem";
}

sub get_keyform
{
    ## do not return something with a leading "e"
    ## if you don't use an engine
    return "engine";
}

1;

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Engine::LunaGem

=head1 Description

This class implements an interface to use the Gemalto Luna HSM.

This class sets "-engine gem -keyform engine" and does not support
any additional engine parameters. It is required that the HSM is
unlocked, the OpenXPKI server user/group must be properly chosen so
the daemon can access the HSM, this is usually achieved by running
OpenXPKI and the HSM service with the same group.

=head1 Configuration

Set I<engine: LunaGem> and set the I<key> attribute of your token to
the label of the HSM key.

=head1 Functions

=head2 get_engine

returns the used OpenSSL engine 'gem'.

=head2 get_keyform

returns "engine" because otherwise the use of this module makes no sense.


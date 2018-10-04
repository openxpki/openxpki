package OpenXPKI::Server::Workflow::Condition::KeyGenerationMode;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DateTime;
use OpenXPKI::Debug;
use English;

sub _evaluate
{
    ##! 64: 'start'
    my ( $self, $wf ) = @_;
    my $context = $wf->context();

    my $profile = $self->param('profile');
    $profile = $context->param('cert_profile') if(!$profile);

    if (!$profile) {
        configuration_error ("No profile set or empty") ;
    }

    my $mode = $self->param('generate');
    if (!$mode) {
        configuration_error ("No generate mode set or empty");
    }

    my $config = CTX('config');

    my $config_mode = $config->get( [ 'profile', $profile, 'key', 'generate' ] );
    $config_mode = $config->get( [ 'profile', 'default', 'key', 'generate' ] ) unless($config_mode);

    # if nothing is set, check if we have algorithms for server side
    if (!defined $config_mode) {

        CTX('log')->application()->debug("KeyGenerationMode condition fall back to autodetect");


        if ($config->exists( [ 'profile', $profile, 'key', 'alg' ] ) ||
        $config->exists( [ 'profile', 'default', 'key', 'alg' ] )) {
            $config_mode = 'both';

        } else {
            $config_mode = 'client';
        }
    }

    my $result;
    if ($mode eq "escrow") {
       $result = ($config_mode eq "escrow");
    } elsif ($mode eq "server") {
        $result = ($config_mode ne "client");
    } elsif ($mode eq "client") {
        $result = ($config_mode eq "client" || $config_mode eq "both");
    } else {
        configuration_error("unknown option passed for mode ($mode)");
    }

    CTX('log')->application()->info("KeyGenerationMode condition result: $result ($mode ?= $config_mode)");


    if (!$result) {
        condition_error("Requested mode $mode is not allowed ($config_mode)");
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::KeyGenerationMode

Check if the profile allows key generation as specified by the "generate"
parameter.

Example:

    can_use_server_key:
        class: OpenXPKI::Server::Workflow::Condition::KeyGenerationMode
        param:
            generate: server
            _map_profile: $cert_profile


Returns true if the key generation setting is either escrow, server or both.
The setting is obtained for the given profile (by profile or from the default
setting) from the node I<key.generate>. If this node is missing, client is
allowed and server is assumed ok if I<key.alg> is not empty.

If the profile parameter is not given in the configuration, the context value
of cert_profile is used.

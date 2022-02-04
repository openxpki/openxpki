package OpenXPKI::Server::Workflow::Activity::Tools::LoadPolicy;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $context   = $workflow->context();
    my $config = CTX('config');

    my $policy_params = $config->get_hash(  $self->_get_service_config_path('policy') );

    if (!$policy_params) {
        CTX('log')->application()->warn("No policy params set in LoadPolicy");

    } else {

        foreach my $key (keys (%{$policy_params})) {
            $context->param( "p_$key" => $policy_params->{$key} );
        }

        CTX('log')->application()->debug("Server policy loaded");

    }
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::LoadPolicy

=head1 Description

Load the policy section for a server endpoint.

The path to load defaults to $interface.$server.policy where interface
and server are read from the context. You can override the full path by
setting the key I<config_path>.

The given path is expected to return a hash, each key/value pair is read
into the context with the I<p_> prefix added to each key!

=head1 Configuration

=head2 Activity Parameter

=over

=item config_path

Explict path to read the policy from.

=back

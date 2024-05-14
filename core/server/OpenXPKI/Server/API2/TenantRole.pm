package OpenXPKI::Server::API2::TenantRole;
use OpenXPKI -role;

=head1 NAME

OpenXPKI::Server::API2::TenantRole - provides helper methods for plugins

=cut

use OpenXPKI::Server::Context qw( CTX );

sub get_validated_tenant ($self, $tenant = undef) {

    # no tenant was given, try to load the primary tenant
    return $self->api->get_primary_tenant unless defined $tenant;

    my $res = $self->api->can_access_tenant( tenant => $tenant );
    # access is granted either explict (true)
    # or implicit if no handler is defined (undef)

    # result is defined but false = acccess denied
    OpenXPKI::Exception->throw(
        message => 'Access to this tenant is forbidden for the current user'
    ) unless ($res or not defined $res);

    return $tenant;

}

1;
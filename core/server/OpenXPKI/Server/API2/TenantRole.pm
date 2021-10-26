package OpenXPKI::Server::API2::TenantRole;

=head1 NAME

OpenXPKI::Server::API2::TenantRole - provides helper methods for plugins

=cut

use Moose::Role;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

sub get_validated_tenant {

    my $self = shift;
    my $tenant = shift;

    # no tenant was given, try to load the primary tenant
    return CTX('api2')->get_primary_tenant() unless(defined $tenant);


    my $res = CTX('api2')->can_access_tenant( tenant => $tenant );
    # access is granted either explict (true)
    # or implicit if no handler is defined (undef)

    # result is defined but false = acccess denied
    OpenXPKI::Exception->throw(
        message => 'Access to this tenant is forbidden for the current user'
    ) unless ($res || !defined $res);

    return $tenant;

}

1;
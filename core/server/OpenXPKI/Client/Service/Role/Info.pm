package OpenXPKI::Client::Service::Role::Info;
use OpenXPKI -role;

requires 'declare_routes';

=head1 NAME

OpenXPKI::Client::Service::Role::Info - Role to provide basic service info,
i.e. Mojolicious route declarations.

=head1 DESCRIPTION

A consuming class looks like this:

    package OpenXPKI::Client::Service::TheXProtocol;
    use OpenXPKI -class;

    with qw(
        OpenXPKI::Client::Service::Role::Info
        OpenXPKI::Client::Service::Role::Base
    );

    ...
    sub declare_routes ($r) { ... }

=head2 REQUIRED METHODS

The consuming class needs to implement the following methods:

=head3 declare_routes

Static subroutine to set up all Mojolicious URL routes belonging to the service.

Called by L<OpenXPKI::Client::Web/startup>.

    # e.g. in package OpenXPKI::Client::Service::RPC

    sub declare_routes ($r) {
        $r->any('/rpc/<endpoint>/<method>')->to(
            service_class => __PACKAGE__,
            method => '',
        );
    }

For every route OpenXPKI's special Mojolicious stash parameters must be set:

=over

=item * C<service_class> = the class which consumes
L<OpenXPKI::Client::Service::Role::Base> and processes the request (usually the
same class, i.e. C<__PACKAGE__>).

=item * C<endpoint> = the service endpoint (e.g. statically set to C<"default">
or dynamically set via URL path).

=back

B<Parameters>

=over

=item * C<$r> - L<Mojolicious::Routes>

=back

=cut

1;

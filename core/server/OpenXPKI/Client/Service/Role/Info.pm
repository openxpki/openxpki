package OpenXPKI::Client::Service::Role::Info;
use OpenXPKI -role;

requires 'declare_routes';

=head1 NAME

OpenXPKI::Client::Service::Role::Info - Role for the classes that provide
basic service info, i.e. Mojolicious route declarations.

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

The consuming class needs to implement the following methods.

=head3 declare_routes

Called by L<OpenXPKI::Client::Web>, this static subroutine must set up all
Mojolicious URL routes belonging to the service.

    # e.g. in package OpenXPKI::Client::Service::RPC

    sub declare_routes ($r) {
        $r->any('/rpc/<endpoint>/<method>')->to(
            service_class => __PACKAGE__,
            method => '',
        );
    }

The implementing service class must set OpenXPKI's special Mojolicious stash
parameter C<service_class> to a package which consumes
L<OpenXPKI::Client::Service::Role::Base> (usually C<__PACKAGE__>).

B<Passed parameters>

=over

=item * C<$r> - L<Mojolicious::Routes>

=back

=cut

1;

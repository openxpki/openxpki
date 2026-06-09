package OpenXPKI::Client::Service::WebUI::Session::Role;
use OpenXPKI qw( -role -typeconstraints );

=head1 NAME

OpenXPKI::Client::Service::WebUI::Session::Role - Common interface for frontend session backends

=head1 DESCRIPTION

Moose role that defines the interface shared by all frontend session backends
(L<OpenXPKI::Client::Service::WebUI::Session> and
L<OpenXPKI::Client::Service::WebUI::LegacyCGISession>).

Consuming this role also registers the C<OpenXPKI::Client::Service::WebUI::Session::Role> Moose type constraint,
which can be used instead of a class-name union in C<isa> declarations.

=cut

requires qw(
    id
    param
    expire
    flush
    clone
    delete
);

1;

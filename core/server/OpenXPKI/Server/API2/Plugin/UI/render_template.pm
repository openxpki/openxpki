package OpenXPKI::Server::API2::Plugin::UI::render_template;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::render_template

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Template;


=head1 COMMANDS

=head2 render_template

Renders the given template with the given parameters.

This is just a wrapper around L<OpenXPKI::Template/render>.

This is a workaround and should be refactored, see Github issue #283.

B<Parameters>

=over

=item * C<template> I<Str> - template string including placeholders.

=item * C<params> I<HashRef> - parameters to fill in the placeholders. Optional, default:  {}

=back

=cut
command "render_template" => {
    template => { isa => 'Str', required => 1, },
    params   => { isa => 'HashRef', default => sub { {} } },
} => sub {
    my ($self, $params) = @_;

    my $oxtt = OpenXPKI::Template->new();
    my $result = $oxtt->render($params->template, $params->params);

    # trim whitespaces
    $result =~ s{ \A [\s\n]+ }{}xms;
    $result =~ s{ [\s\n]+ \z }{}xms;
    return $result;
};

__PACKAGE__->meta->make_immutable;

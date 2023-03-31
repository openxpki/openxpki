package OpenXPKI::Server::API2::Plugin::UI::render_template;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::render_template

=cut

use Try::Tiny;
use YAML::Loader;
use Data::Dumper;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Template;
use OpenXPKI::Debug;

=head1 COMMANDS

=head2 render_template

Renders the given template with the given parameters.

This is just a wrapper around L<OpenXPKI::Template/render>.

This is a workaround and should be refactored, see Github issue #283.

B<Parameters>

=over

=item * C<template> I<Str> - template string including placeholders.

=item * C<params> I<HashRef> - parameters to fill in the placeholders. Optional, default: C<{}>

=item * C<trim> I<Bool> - trim whitespaces at beginning and end of rendered string. Optional, default: C<1>

=back

=cut
command "render_template" => {
    template => { isa => 'Str', required => 1, },
    params   => { isa => 'HashRef', default => sub { {} } },
    trim     => { isa => 'Bool', default => 1 },
} => sub {
    my ($self, $params) = @_;

    ##! 64: $params->template
    ##! 128: $params->params
    my $oxtt = OpenXPKI::Template->new({ trim_whitespaces => $params->trim });
    my $result = $oxtt->render($params->template, $params->params);

    return $result;
};

=head2 render_yaml_template

Renders the given template with the given parameters, the result is
expected to be a valid YAML document and parsed as such.

The return value is a perl structure representing the YAML document.

Throws OpenXPKI::Exception if the template can not be rendered or the
document can not be parsed. Returns undef if the document is empty.

B<Parameters>

=over

=item * C<template> I<Str> - template string including placeholders.

=item * C<params> I<HashRef> - parameters to fill in the placeholders. Optional, default: C<{}>

=back

=cut
command "render_yaml_template" => {
    template => { isa => 'Str', required => 1, },
    params   => { isa => 'HashRef', default => sub { {} } },
} => sub {
    my ($self, $params) = @_;

    ##! 64: $params->template
    ##! 128: $params->params
    my $log = CTX('log')->system;
    my $oxtt = OpenXPKI::Template->new({ trim_whitespaces => 0 });

    my $yaml;
    my $has_head;
    # if template does not start with a word character we add a top level
    # node to make it a valid and parsable YAML document
    if ($params->template =~ m{\A\w}) {
        $yaml = $params->template;
    } else {
        $yaml = "OXI_PLACEHOLDER:\n" . $params->template;
        $has_head = 1;
    }

    my $result = $oxtt->render($yaml, $params->params);

    ##! 64: 'Rendered YAML template: ' . $result
    $log->debug('Rendered YAML template: ' . $result);

    return unless($result);

    my $doc;
    my $value;
    try {
        $value = YAML::Loader->new->load($result);
    }
    catch {
        OpenXPKI::Exception->throw (
            message => "Error parsing YAML in 'yaml_template'",
            params => { error => $_, yaml => $result }
        );
    };

    $value = $value->{OXI_PLACEHOLDER} if ($has_head);
    $log->trace('Parsed Perl structure: ' . Dumper($value)) if $log->is_trace;
    ##! 64: 'Parsed Perl structure: ' . Dumper($value)
    return $value;
};

__PACKAGE__->meta->make_immutable;

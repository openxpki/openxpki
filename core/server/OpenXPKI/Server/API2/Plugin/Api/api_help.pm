package OpenXPKI::Server::API2::Plugin::Api::api_help;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Api::api_help

=cut

# CPAN modules
use Pod::POM;

# Project modules
use OpenXPKI::Server::API2::Plugin::Api::Util::ModuleFinder;
use OpenXPKI::Server::API2::Plugin::Api::Util::PodPOMView;

=head1 COMMANDS

=head2 api_help

Returns a description of the given API command.

The documentation is read from the source code POD documentation.

B<Parameters>

=over

=item * C<command> I<Str> - name of the API command

=back

=cut
command "api_help" => {
    command => { isa => 'Str', required => 1 },
} => sub {
    my ($self, $params) = @_;

    my $command = $params->command;

    # query the 'command => package' mapping
    my $package = $self->rawapi->commands->{$command};
    return "ERROR: Unknown API command '$command'" unless $package;

    # find module path
    my $path = OpenXPKI::Server::API2::Plugin::Api::Util::ModuleFinder
        ->new
        ->find($package);
    return "ERROR: Could not find module with package '$package'" unless $path;

    # format module POD
    my $pom = Pod::POM->new;
    my $view = OpenXPKI::Server::API2::Plugin::Api::Util::PodPOMView->new;

    my $tree = $pom->parse_file($path)
        or return "ERROR: ".$pom->error();

    my @heading_blocks = grep { $_->title eq "COMMANDS" } $tree->head1;
    return "ERROR: Missing section COMMANDS in $path" unless scalar @heading_blocks;

    my @cmd_blocks = grep { $_->title eq $command } $heading_blocks[0]->head2;
    return "ERROR: No description found for '$command' in $path" unless scalar @cmd_blocks;

    return sprintf "%s\n", $cmd_blocks[0]->present($view);
};

__PACKAGE__->meta->make_immutable;

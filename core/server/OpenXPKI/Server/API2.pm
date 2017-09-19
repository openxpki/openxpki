package OpenXPKI::Server::API2;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Server::API2 - Standardized internal and external access to sensitive
functions

=cut

# Core modules
use Carp qw(croak);
use Cwd qw (abs_path);
use Module::Load;

# CPAN modules
use Module::List qw(list_modules);
use Try::Tiny;

# Project modules
use OpenXPKI::Server::API2::PluginRole;



=head1 DESCRIPTION

=head2 Call API commands

This class acts as a dispatcher (single entrypoint) to execute API commands via
L<dispatch>.

It makes available all API commands defined in the C<OpenXPKI::Server::API2::Plugin>
namespace.

=head2 Create a plugin class

The standard (and easy) way to define a new plugin class with API commands is to
create a new package in the C<OpenXPKI::Server::API2::Plugin> namespace and use
L<OpenXPKI::Server::API2::EasyPlugin> as described there.

=cut



=head1 ATTRIBUTES

=head2 namespace

Optional: Perl package namespace that will be searched for the command plugins
(classes). Default: C<OpenXPKI::Server::API2::Plugin>

Example:

    my $api = OpenXPKI::Server::API2->new(namespace => "My::App::Command");

=cut
has namespace => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => __PACKAGE__."::Command",
);

=head2 command_base_class

Optional: role that all command classes are expected to have. This allows
the API to distinct between command modules that shall be registered and helper
classes. Default: C<OpenXPKI::Server::API2::PluginRole>.

=cut
has command_role => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => "OpenXPKI::Server::API2::PluginRole",
);

=head2 commands

I<HashRef> containing registered API commands and their Perl packages. The hash
is built on first access, you should rarely have a reason to set this manually.

Structure:

    {
        "API command 1" => "Perl package name",
        "API command 2" => ...,
    }

=cut
has commands => (
    is => 'rw',
    isa => 'HashRef[Str]',
    lazy => 1,
    builder => "_build_commands",
);

sub _build_commands {
    # Code taken from Plugin::Simple
    my $self = shift;

    my @modules = ();
    my $candidates = {};
    try {
        $candidates = list_modules($self->namespace."::", { list_modules => 1, recurse => 1 });
    }
    catch {
        die "Error listing modules in namespace ".$self->namespace.": $_";
    };

    for my $module (keys %{ $candidates }) {
        my $ok;
        try {
            load $module;
            $ok = 1;
        }
        catch {
            warn "Error loading module $module: $_\n";
        };
        push @modules, $module if $ok;
    }

    my %commands = ();

    print "Registering command modules:\n";
    for my $mod (@modules){
        if ($mod->DOES($self->command_role)) {
            $commands{$_} = $mod for keys %{ $mod->meta->param_classes };
            print "- register $mod: ".join(", ", keys %{ $mod->meta->param_classes })."\n";
        }
        else {
            print "- ignore   $mod (does not have role ".$self->command_role.")\n";
        }
    }
    return \%commands;
}


=head1 METHODS

=head2 dispatch

Dispatches an API command call to the responsible plugin instance.

B<Parameters>

=over

=item * C<$command> - API command name

=item * C<%params> - Parameter hash

=back

=cut
sub dispatch {
    my ($self, $command, %params) = @_;

    my $package = $self->commands->{$command};
    die "Unknown API command $command\n" unless $package;

    my $params = $package->meta->new_param_object($command, %params);
    return $package->new->$command($params);
}

__PACKAGE__->meta->make_immutable;

=head1 INTERNALS

=head2 Design principles

=over

=item * B<No base class>: when you use L<OpenXPKI::Server::API2::EasyPlugin> to
define a plugin class all functionality is added via Moose roles instead of
a base class. This allows for plugin classes to be based on any other classes
if needed.

=item * B<Standard magic>: syntactic sugar and helper functions only use Moose's
standard way to e.g. customize meta classes or inject roles. No other black
magic is used.

=item * B<Breakout allowed>: using L<OpenXPKI::Server::API2::EasyPlugin> is not
a must, API plugins might be implemented differently by manually adding the role
L<OpenXPKI::Server::API2::PluginRole> to a plugin class.

=back

=cut

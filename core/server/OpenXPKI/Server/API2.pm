package OpenXPKI::Server::API2;
use Moose;
use utf8;

=head1 Name

OpenXPKI::Server::API2

=cut

# Core modules
use Carp qw(croak);
use Cwd qw (abs_path);
use Module::Load;

# CPAN modules
use Module::List qw(list_modules);
use Try::Tiny;

# Project modules
use OpenXPKI::Server::API2::CommandRole;

=head1 Attributes

=head2 namespace

Optional: Perl package namespace that will be searched for the command plugins
(classes). Default: C<OpenXPKI::Server::API2::Command>

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
classes. Default: C<OpenXPKI::Server::API2::CommandRole>.

=cut
has command_role => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => "OpenXPKI::Server::API2::CommandRole",
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
            $commands{$_} = $mod for keys %{ $mod->meta->api_param_classes };
            print "- register $mod: ".join(", ", keys %{ $mod->meta->api_param_classes })."\n";
        }
        else {
            print "- ignore   $mod (does not have role ".$self->command_role.")\n";
        }
    }
    return \%commands;
}

sub dispatch {
    my ($self, $command, %params) = @_;

    my $package = $self->commands->{$command};
    die "Unknown API command $command\n" unless $package;

    my $params = $package->meta->new_param_object($command, %params);
    return $package->new->$command($params);
}

__PACKAGE__->meta->make_immutable;

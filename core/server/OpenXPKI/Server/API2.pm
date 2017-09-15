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



has namespace => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => __PACKAGE__."::Command",
);

has plugin_base_class => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => "OpenXPKI::Server::API2::CommandBase",
);

has plugins => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    builder => "_build_plugins",
);



sub _build_plugins {
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

    my @plugins = ();
    my @ignored = ();

    print "Registering command modules:\n";
    for my $mod (@modules){
        if ($mod->isa($self->plugin_base_class)) {
            push @plugins, $mod;
            print "- register: $mod\n";
        }
        else {
            push @ignored, $mod;
            print "- ignore:   $mod (no subclass of ".$self->plugin_base_class.")\n";
        }
    }
    return \@plugins;
}

__PACKAGE__->meta->make_immutable;

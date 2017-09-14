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

use Test::More;

has namespace => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => __PACKAGE__."::Command",
);

has plugin_role => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => "OpenXPKI::Server::API2::CommandRole",
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
#diag "Searching namespace $item";
    my $candidates = {};
    try {
        $candidates = list_modules($self->namespace."::", { list_modules => 1, recurse => 1 });
    }
    catch {
        die "Error listing modules in namespace ".$self->namespace.": $_";
    };

    for my $module (keys %{ $candidates }) {
diag "Candidate $module";
        my $ok;
        try {
            load $module;
            $ok = 1;
        }
        catch {
            warn "Error loading module $module: $_\n";
        };
diag "--> OK" if $ok;
        push @modules, $module if $ok;
    }

    my @plugins = ();

    for my $mod (@modules){
        if ($mod->isa("Moose::Object") and $mod->DOES($self->plugin_role)) {
            push @plugins, $mod;
            print "$mod\n";
        }
        else {
            print "IGNORING $mod (does not have ".$self->plugin_role." role)\n";
        }
    }

    return \@plugins;
}

__PACKAGE__->meta->make_immutable;

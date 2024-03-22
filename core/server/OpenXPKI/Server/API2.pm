package OpenXPKI::Server::API2;
use Moose;

=head1 NAME

OpenXPKI::Server::API2 - Standardized internal and external access to sensitive
functions

=cut

# Core modules
use Module::Load;
use File::Spec;
use IO::Dir 1.03;
use Scalar::Util qw( blessed );

# CPAN modules
use Type::Params qw( signature_for );
use Feature::Compat::Try;

# Project modules
use OpenXPKI::Server::Log;
use OpenXPKI::Exception;
use OpenXPKI::Server::API2::PluginRole;
use OpenXPKI::Server::API2::Autoloader;

use experimental 'signatures'; # should be done after imports to safely disable warnings in Perl < 5.36

=head1 SYNOPSIS

B<Default usage>:

    use OpenXPKI::Server::API2;

    my $api = OpenXPKI::Server::API2->new(
        acl_rule_accessor => sub { CTX('config')->get('acl.rules.' . CTX('session')->data->role ) },
    );
    printf "Available commands: %s\n", join(", ", keys %{$api->commands});

    my $api_direct = $api->autoloader;

    my $result = $api_direct->mycommand(myaction => "go");
    # same as: $result = $api->dispatch("mycommand", myaction => "go");

B<Disable ACL checks> when executing a command:

    my $api = OpenXPKI::Server::API2->new(
        enable_acls => 0,
    );

B<Different plugin namespace> for auto-discovery:

    my $api = OpenXPKI::Server::API2->new(
        namespace => "My::Command::Plugins",
    );

B<Disable plugin auto-discovery>:

    my $api = OpenXPKI::Server::API2->new(
        commands => {},
    );

B<Manually register> a plugin outside the default namespace:

    my @commands = $api->register_plugin("OpenXPKI::MyAlienplugin");

=head1 DESCRIPTION

Please note that all classes in the C<OpenXPKI::Server::API2::> namespace are
context free, i.e. do not use the C<CTX> object.

Within the OpenXPKI server the API (or L<OpenXPKI::Server::API2::Autoloader>, to be
more precise) is available via C<CTX('api2')>.

=head2 Call API commands

This class acts as a dispatcher (single entrypoint) to execute API commands via
L<dispatch>.

It makes available all API commands defined in the C<OpenXPKI::Server::API2::Plugin>
namespace.

For easy access to the API commands you should use the autoloader instance
returned by L</autoloader>.

=head2 Create a plugin class

Standard (and easy) way to define a new plugin class with API commands: create
a new package in the C<OpenXPKI::Server::API2::Plugin> namespace (any
deeper hierarchy is okay) and in your package use
L<OpenXPKI::Server::API2::EasyPlugin> as described there.

=cut



=head1 ATTRIBUTES

=head2 log

Optional: L<Log::Log4perl::Logger>.

Default: C<OpenXPKI::Server::Log-E<gt>new(CONFIG =E<gt> undef)-E<gt>system>.

=cut
has log => (
    is => 'rw',
    isa => 'Log::Log4perl::Logger',
    lazy => 1,
    default => sub { OpenXPKI::Server::Log->new(CONFIG => undef)->system }, # CONFIG => undef: reuse existing Log4Perl config
);

=head2 autoloader

Returns an instance of L<OpenXPKI::Server::API2::Autoloader> that allows to
directly call API commands:

    my $api = OpenXPKI::Server::API2->new( ... );
    my $api_direct = $api->autoloader;
    $api_direct->search_cert(pki_realm => ...)

=cut
has autoloader => (
    is => 'ro',
    isa => 'OpenXPKI::Server::API2::Autoloader',
    lazy => 1,
    default => sub {
        my $self = shift;
        return OpenXPKI::Server::API2::Autoloader->new(api => $self);
    },
);

=head2 enable_acls

Optional: set to FALSE to disable ACL checks when commands are executed.

Default: TRUE

Can only be set via constructor.

=cut
has enable_acls => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);

=head2 enable_protected

Optional: set to TRUE to enable running protected commands

Default: FALSE

Can only be set via constructor.

=cut
has enable_protected => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

=head2 acl_rule_accessor

Only if C<enable_acls = 1>: callback that should return the ACL configuration
I<HashRef> for the current user (role).

Example:

    my $cfg = $api2->acl_rule_accessor->();

=cut
has acl_rule_accessor => (
    is => 'rw',
    isa => 'CodeRef',
    lazy => 1,
    default => sub { die "Attribute 'acl_rule_accessor' not set in ".__PACKAGE__."\n" },
);

=head2 namespace

Optional: Perl package namespace that will be searched for the command plugins
(classes).

Default: C<OpenXPKI::Server::API2::Plugin>

Example:

    my $api = OpenXPKI::Server::API2->new(namespace => "My::App::Command");

=cut
has namespace => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => __PACKAGE__."::Plugin",
);

=head2 command_role

Optional: role that all command classes are expected to have. This allows
the API to distinct between command modules that shall be registered and helper
classes.

Default: C<OpenXPKI::Server::API2::PluginRole>.

B<ATTENTION>: if you change this make sure the role you specify requires at
least the same methods as L<OpenXPKI::Server::API2::PluginRole>.

=cut
has command_role => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => "OpenXPKI::Server::API2::PluginRole",
);

=head2 commands

I<HashRef> containing registered API commands and their Perl packages. The hash
is built on first access, only manually set this if you want to disable the
auto-discovery of plugin modules.

Structure:

    {
        "API command 1" => "Perl package name",
        "API command 2" => ...,
    }

=head1 METHODS

=head2 add_commands

Register the given C<command =E<gt> package> mappings to the list of known API
commands.

=cut
has commands => (
    is => 'rw',
    isa => 'HashRef[Str]',
    traits => [ 'Hash' ],
    handles => {
        add_commands => 'set',
    },
    lazy => 1,
    builder => "_build_commands",
);

sub _build_commands {
    # Code taken from Plugin::Simple
    my $self = shift;

    my @modules = ();
    my $pkg_map = {};
    try {
        $pkg_map = _list_modules($self->namespace."::");
    }
    catch ($err) {
        OpenXPKI::Exception->throw (
            message => "Error listing API plugins",
            params => { namespace => $self->namespace, error => $err }
        );
    }

    return $self->_load_plugins($pkg_map);
}

#
# Tries to load the given plugin classes.
#
# Returns a HashRef that contains the C<command =E<gt> package> mappings.
#
sub _load_plugins {
    my ($self, $pkg_map) = @_;

    my $cmd_package_map = {};

    $self->log->debug("Loading ".(scalar keys %{ $pkg_map })." API plugins");

    for my $pkg (keys %{ $pkg_map }) {
        my $file = $pkg_map->{$pkg};

        Module::Load::load $pkg;

        if (not $pkg->DOES($self->command_role)) {
            $self->log->trace("API - ignore $pkg (does not consume ".$self->command_role.") - $file");
            next;
        }

        $self->log->trace("API - register $pkg: ".join(", ", @{ $pkg->commands })." - $file");

        # store commands and their source package
        for my $cmd (@{ $pkg->commands }) {
            # check if command was previously defined by another package
            my $earlier_pkg = $cmd_package_map->{$cmd};
            if ($earlier_pkg) {
                my $earlier_file = $pkg_map->{$earlier_pkg};
                OpenXPKI::Exception->throw(
                    message => "API command '$cmd' now defined in $pkg was previously found in $earlier_pkg",
                    params => { now_file => $file, previous_file => $earlier_file }
                );
            }

            if (substr($cmd,0,2) eq '__' && not $self->enable_protected) {
                $self->log->trace("API - skipping protected command $pkg: ".join(", ", @{ $pkg->commands })." - $file");
                next;
            }

            $cmd_package_map->{$cmd} = $pkg;
        }
    }

    return $cmd_package_map;
}

=head2 register_plugin

Manually register a plugin class containing API commands.

This is usually not neccessary because plugin classes are auto-discovered
as described L<above|/DESCRIPTION>.

Returns a plain C<list> of API commands that were found.

B<Parameters>

=over

=item * C<$packages> - class/package name I<Str> or I<ArrayRef> of package names

=back

=cut

sub register_plugin {
    my ($self, $packages) = @_;
    # convert string to arrayref
    $packages = [ $packages ] unless (ref $packages or "") eq "ARRAY";
    # convert arrayref to hashref
    my $pkg_map = { map { $_ => "manually added" } @$packages };

    my $pkg_by_cmd = $self->_load_plugins($pkg_map);
    $self->add_commands( %{ $pkg_by_cmd } );
    return ( keys %{ $pkg_by_cmd } );
}

=head2 dispatch

Dispatches an API command call to the responsible plugin instance.

B<Named parameters>

=over

=item * C<command> - API command name

=item * C<params> - Parameter hash

=back

=cut
signature_for dispatch => (
    method => 1,
    named => [
        command => 'Str',
        params  => 'Optional[ HashRef ]', { default => {} },
    ],
);
sub dispatch ($self, $arg) {
    my $command = $arg->command;

    my $package = $self->commands->{ $command }
        or OpenXPKI::Exception->throw(
            message => "Unknown API command",
            params => { command => $command, caller => sprintf("%s:%s", ($self->my_caller())[1,2]) },
        );

    my $all_params;
    if ($self->enable_acls) {
        my $rules = $self->_get_acl_rules($command)
            or OpenXPKI::Exception->throw(
                message => "ACL does not permit call to API command",
                params => { command => $command, caller => sprintf("%s:%s", ($self->my_caller())[1,2]) }
            );

        $all_params = $self->_apply_acl_rules($command, $rules, $arg->params);
    }
    else {
        $all_params = $arg->params;
    }

    $self->log->debug("API call to '$command'") if $self->log->is_debug;

    my $result;
    try {
        $result = $package
            ->new(rawapi => $self)
            ->execute($command, $all_params);
    }
    catch ($err) {
        my $msg = $err;
        if (blessed($err)) {
            if ($err->isa("OpenXPKI::Exception")) {
                $err->rethrow;
            }
            elsif ($err->isa("Moose::Exception")) {
                $msg = $err->message;
            }
        }
        OpenXPKI::Exception->throw(
            message => "Error while executing API command",
            params => { command => $command, error => $msg, caller => sprintf("%s:%s", ($self->my_caller())[1,2]) }, # stringify in case error is an object
        );
    }

    return $result;
}

=head2 my_caller

Returns informations about the caller of the code that invokes this method:
a I<list> (!) as returned by Perls L<caller>.

This is like a wrapper for Perls C<caller> that skips / steps over subroutines
that are part of the API infrastructure (except plugins), so we get the "real"
calling code.

E.g.

    package OpenXPKI::Server::API2::Plugin::test

    command "who_is_it" => { ... } => sub {
        my ($self, $params) = @_;
        return $self->get_info;
    }

    sub get_info {
        return $self->rawapi->my_caller(1); # who invoked API command "who_is_it"
    }

B<Parameters>

=over

=item * C<$skip> I<Int> - how many callers to step over. Default: 0

=back

=cut

sub my_caller {
    my ($self, $skip) = @_;
    my $start_stackframe = 1 + ($skip // 0); # 1 = skip the code that called us

    # skip API in call chain
    my @caller; my $i = $start_stackframe;
    my $cache_key;
    while (@caller = caller($i)) {
        $i++;
        next if $caller[0] =~ m{ ^ OpenXPKI::Server::API2 (?!::Plugin::) }x;
        next if $caller[0] =~ m{ ^ Try::Tiny }x;
        last;
    }
    return @caller;
}

=head2 _apply_acl_rules

Enforces the given ACL rules on the given API command parameters (e.g. applies
defaults or checks ACL constraints).

Returns a I<HashRef> containing the resulting parameters.

Throws an exception if the current user role is not permitted to access the
given command.

B<Parameters>

=over

=item * C<$command> - API command name

=item * C<$rules> - I<HashRef> containing the parameter rules

=item * C<$params> - I<HashRef> of API command parameters as received by the caller

=back

=cut

sub _apply_acl_rules {
    my ($self, $command, $rules, $params) = @_;

    my $result = { %$params }; # copy given params so we can modify hash without side effects

    for my $param (keys %$rules) {
        my $rule = $rules->{$param};
        # enforced parameter
        if ($rule->{force}) {
            if ($result->{$param}) {
                $self->log->warn("API command '$command': overwriting '$param' with forced value via ACL config");
            }
            elsif ($self->log->is_debug) {
                $self->log->debug("API command '$command': setting '$param' to forced value via ACL config");
            }
            $result->{$param} = $rule->{force};
        }
        # parameter not set
        elsif (not $result->{$param}) {
            if ($rule->{required}) {
                OpenXPKI::Exception->throw(
                    message => "API command parameter required by ACL but not given",
                    params => { command => $command, param => $param },
                );
            }
            if ($rule->{default}) {
                $result->{$param} = $rule->{default};
                $self->log->debug("API command '$command': setting '$param' to default via ACL config")
                  if $self->log->is_debug;
            }
        }
        # parameter set but blocked
        elsif ($rule->{block}) {
            OpenXPKI::Exception->throw(
                message => "API command parameter was given but blocked via ACL",
                params => { command => $command, param => $param },
            );
        }
        # non-matching parameter
        elsif ($rule->{match} and not $result->{$param} =~ qr/$rule->{match}/msx) {
            OpenXPKI::Exception->throw(
                message => "API command parameter does not match regex in ACL",
                params => { command => $command, param => $param, value => $result->{$param} },
            );
        }
    }
    return $result;
}

=head2 _get_acl_rules

Checks if the given current OpenXPKI user's role is allowed to execute the
given command.

On success it returns the command configuration (might be an empty I<HashRef>),
e.g.:

    {
        param_a => {
            default => "lawn",
            match => "^la",
        }
        param_b => {
            force => "green",
        }
    }

On failure (if user role has no access) returns I<undef>.

B<Parameters>

=over

=item * C<$command> - API command name

=back

=cut

sub _get_acl_rules {
    my ($self, $command) = @_;

    my $conf = $self->acl_rule_accessor->(); # invoke the CodeRef
    # no ACL config
    if (not $conf) {
        $self->log->debug("ACL config: unknown role") if $self->log->is_debug;
        return;
    }

    my $default_allow = ($conf->{policy} && $conf->{policy} eq 'allow');

    $self->log->debug("ACL default policy: " . ($default_allow ? 'allow' : 'deny'))
      if ($self->log->is_debug);

    my $all_cmd_configs = $conf->{commands};
    # no command config hash
    if (not $all_cmd_configs) {
        return {} if $default_allow;
        $self->log->debug("ACL config: no allowed commands specified when default policy is deny") if $self->log->is_debug;
        return;
    }

    my $cmd_config = $all_cmd_configs->{$command};
    # command not specified (or not a TRUE value)
    if ($cmd_config) {

        # filter definition
        if (ref $cmd_config eq 'HASH') {
            return $cmd_config;
        # allow full access
        } else {
            return {};
        }


    }
    # defined but false value => deny
    if (defined $cmd_config) {
        $self->log->debug("ACL config: command '$command' explicit deny") if $self->log->is_debug;
        return;

    }

    # allowed by default policy
    if ($default_allow) {
        $self->log->debug("ACL config: command '$command' allowed by default policy") if $self->log->is_debug;
        return {};
    }

    $self->log->debug("ACL config: command '$command' not allowed") if $self->log->is_debug;
    return;

}

=head2 _list_modules

Lists all modules below the given namespace.

B<Parameters>

=over

=item * C<$namespace> - Perl namespace (e.g. C<OpenXPKI::Server::API2::Plugin>)

=back

=cut
# Taken from Module::List

sub _list_modules {
    my ($prefix) = @_;

    my $root_rx = qr/[a-zA-Z_][0-9a-zA-Z_]*/;
    my $notroot_rx = qr/[0-9a-zA-Z_]+/;

    OpenXPKI::Exception->throw(message => "Bad module name given to _list_modules()", params => { prefix => $prefix })
        unless (
            $prefix =~ /\A(?:${root_rx}::(?:${notroot_rx}::)*)?\z/x
            and $prefix !~ /(?:\A|[^:]::)\.\.?::/
        );

    my @prefixes = ($prefix);
    my %seen_prefixes;
    my %results;

    while(@prefixes) {
        my $prefix = pop(@prefixes);
        my @dir_suffix = split(/::/, $prefix);
        my $module_rx = $prefix eq "" ? $root_rx : $notroot_rx;
        my $pmc_rx = qr/\A($module_rx)\.pmc\z/;
        my $pm_rx = qr/\A($module_rx)\.pm\z/;
        my $dir_rx = $prefix eq "" ? $root_rx : $notroot_rx;
        $dir_rx = qr/\A$dir_rx\z/;
        # Reverse @INC so that modules paths listed earlier win (by overwriting
        # previously found modules in $results{...}.
        # This is similar to Perl's behaviour when including modules.
        for my $incdir (reverse @INC) {
            my $dir = File::Spec->catdir($incdir, @dir_suffix);
            my $dh = IO::Dir->new($dir) or next;
            my @entries = $dh->read;
            $dh->close;
            # list modules
            for my $pmish_rx ($pmc_rx, $pm_rx) {
                for my $entry (@entries) {
                    if($entry =~ $pmish_rx) {
                        my $name = $prefix.$1;
                        $results{$name} = File::Spec->catdir($dir, $entry);
                    }
                }
            }
            # recurse
            for my $entry (@entries) {
                next unless (
                    File::Spec->no_upwards($entry)
                    and $entry =~ $dir_rx
                    and -d File::Spec->catdir($dir, $entry)
                );
                my $newpfx = $prefix.$entry."::";
                if (!exists($seen_prefixes{$newpfx})) {
                    push @prefixes, $newpfx;
                    $seen_prefixes{$newpfx} = undef;
                }
            }
        }
    }
    return \%results;
}

__PACKAGE__->meta->make_immutable;


=head1 ACLs

ACLs for the API commands can be defined on a per-role basis in each OpenXPKI
realm.

If ACLs are enabled (see L</enable_acls>) then the default is to forbid all API
commands. Allowed commands have to be specified per role in the realm.

The structure of the configuration subtree (below the realm) is as follows:

    acl:
        <role name>:
            # "allow" or "deny"
            policy: allow
            commands:
                # deny access to this command
                <command1>: 0

                # allow unfiltered access to this command
                <command2>: 1

                # allow access and preprocess arguments
                <command3>:
                    <parameter>:
                        default: <string>
                        force:   <string>
                        match:   <regex>
                        block:   1

                <command4>:
                    ...

        <role name>:
            ...

The ACL processor first looks if the command name has a key in the
I<commands> tree, if no key is found the action given by I<policy> is
taken. If no policy is set, the default is deny.

To allow unfiltered access to a command, set a true scalar value.

To fully deny access to the command, set a false scalar value.

To grant access with some control over the parameters given, use a hash
where the attribute names are the keys and the value is a hash with the
rules to be applied on the parameter:

=over

=item * B<force>

Enforce parameter to the given value (overwrites a given value).

    acl:
        CA Operator:
            search_cert:
                status:
                    force: ISSUED

=item * B<default>

Default value if none was given.

                    default: ISSUED

=item * B<match>

Match parameter against regular expression. The Regex is executed using the
modifiers C</msx>, so please escape spaces.

                    match: \A (ISSUED|REVOKED) \z

=item * B<block>

Block parameter so that an exception will be thrown if the caller tries to set
it.

                    block: 1

=back

=head1 INTERNALS

=head2 Design principles

=over

=item * B<One or more commands per class>:

Each plugin class can specify one or
more API commands. This allows to keep helper functions that are shared between
several API commands close to the command code. It also helps reducing the
number of individual Perl module files.

=item * B<No base class>:

When you use L<OpenXPKI::Server::API2::EasyPlugin> to
define a plugin class all functionality is added via Moose roles instead of
a base class. This allows for plugin classes to be based on any other classes
if needed.

=item * B<Standard magic>:

Syntactic sugar and helper functions only use Moose's
standard way to e.g. customize meta classes or inject roles. No other black
magic is used.

=item * B<Breakout allowed>:

Using L<OpenXPKI::Server::API2::EasyPlugin> is not
a must, API plugins might be implemented differently by manually adding the role
L<OpenXPKI::Server::API2::PluginRole> to a plugin class.

=back

=cut

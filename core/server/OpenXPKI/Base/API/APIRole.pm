package OpenXPKI::Base::API::APIRole;
use OpenXPKI -role;

=head1 NAME

OpenXPKI::Base::API::APIRole - General use API functions where commands are loaded via
plugins.

=cut

# Core modules
use Module::Load ();
use File::Spec;
use IO::Dir 1.03;
use List::Util qw( any );

# CPAN modules
use Moose::Util qw( does_role );

# Project modules
use OpenXPKI::Server::Log;
use OpenXPKI::Base::API::PluginRole;
use OpenXPKI::Base::API::Autoloader;

=head2 REQUIRED METHODS

=head2 namespace

Perl package namespace that will be searched for the command plugin classes.

=cut
requires 'namespace';
requires 'handle_dispatch_error';

=head1 SYNOPSIS

B<Default usage>:

    package OpenXPKI::Server::API2;
    use OpenXPKI -class;

    with 'OpenXPKI::Base::API::APIRole';

Then to use it:

    my $api = OpenXPKI::Server::API2->new(
        acl_rule_accessor => sub { CTX('config')->get('acl.rules.' . CTX('session')->data->role ) },
        log => OpenXPKI::Server::Log->new(CONFIG => '')->system,
    );
    printf "Available commands in root namespace: %s\n", join(", ", keys $api->namespace_commands->%*);

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

=head1 DESCRIPTION

Please note that all classes in the C<OpenXPKI::Base::API::> namespace are
context free, i.e. do not use the C<CTX> object.

Within the OpenXPKI server the API (or L<OpenXPKI::Base::API::Autoloader>, to be
more precise) is available via C<CTX('api2')>.

=head2 Call API commands

This class acts as a dispatcher (single entrypoint) to execute API commands via
L<dispatch>.

It makes available all API commands defined in the C<OpenXPKI::Base::API::Plugin>
namespace.

For easy access to the API commands you should use the autoloader instance
returned by L</autoloader>.

=head2 Create a plugin class

Create a new package in the C<OpenXPKI::Base::API::Plugin> namespace (any
deeper hierarchy is okay) and in your package
C<use L<OpenXPKI> -plugin> as described there.

All plugins are expected to consume L<OpenXPKI::Base::API::PluginRole> and
have meta class role L<OpenXPKI::Base::API::PluginMetaClassTrait> applied.

=head1 CONSTRUCTOR PARAMETERS

=head2 log

Required: L<Log::Log4perl::Logger>.

=cut
has log => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    required => 1,
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

=head2 enable_protection

Optional: set to TRUE to enable protection of commands.

Protected commands are defined via L<C<protected_command()>|OpenXPKI::Base::API::Plugin/protected_command>
and must then be called by passing C<protected_call =E<gt> 1> to L</dispatch>.

Default: FALSE

Can only be set via constructor.

=cut
has enable_protection => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

=head2 acl_rule_accessor

Optional, only if C<enable_acls = 1>: callback that should return the ACL
configuration I<HashRef> for the current user (role).

Example:

    my $cfg = $api2->acl_rule_accessor->();

=cut
has acl_rule_accessor => (
    is => 'rw',
    isa => 'CodeRef',
    lazy => 1,
    default => sub { die "Attribute 'acl_rule_accessor' not set in ".__PACKAGE__."\n" },
);

=head1 ATTRIBUTES

=head2 autoloader

Readonly: returns an instance of L<OpenXPKI::Base::API::Autoloader> that
allows to directly call API commands. E.g.:

    my $api = OpenXPKI::Server::API2->new( ... );
    my $api_direct = $api->autoloader;

    # call command in the root namespace:
    $api_direct->search_cert(pki_realm => ...)

    # call command in the config namespace:
    $api_direct->config->show;

=cut
has autoloader => (
    is => 'ro',
    isa => 'OpenXPKI::Base::API::Autoloader',
    lazy => 1,
    default => sub {
        my $self = shift;
        return OpenXPKI::Base::API::Autoloader->new(api => $self);
    },
);

=head2 plugin_packages

I<ArrayRef> of the Perl packages of all loaded plugins.

=cut
has plugin_packages => (
    is => 'rw',
    isa => 'ArrayRef',
    init_arg => undef,
    default => sub { [] },
);

# I<HashRef> containing registered API commands under their respective relative
# namespace and their Perl packages. The hash is built on first access.

# If no namespace is specified in a plugin class the commands are assigned to
# the default namespace C<""> (empty string).

# Structure:

#     {
#         'namespace1' => {
#             'command_a' => 'OpenXPKI::Server::API2::Plugin::namespace1::command',
#             'command_b' => 'OpenXPKI::Server::API2::Plugin::namespace1::command',
#         },
#         ...
#     }
has _namespace_commands => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
    lazy => 1,
    builder => "_build_namespace_commands",
);

sub _build_namespace_commands ($self) {
    # Code inspired by Plugin::Simple
    my $result = {};
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

    # Try to load the given plugin classes.
    $self->log->debug("Checking ".(scalar keys $pkg_map->%*)." packages in API plugin namespace " . $self->namespace);

    for my $pkg (sort keys $pkg_map->%*) {
        my $file = $pkg_map->{$pkg};
        Module::Load::load($pkg);

        if (not does_role($pkg, 'OpenXPKI::Base::API::PluginRole')) {
            $self->log->trace("API - ignore $pkg (does not consume OpenXPKI::Base::API::PluginRole)");
            next;
        }

        # paranoia
        OpenXPKI::Exception->throw (
            message => "API plugin ${pkg}'s meta class does not consume OpenXPKI::Base::API::PluginMetaClassTrait",
            params => { namespace => $self->namespace }
        ) unless $pkg->meta->meta->does_role('OpenXPKI::Base::API::PluginMetaClassTrait');

        my $root_namespace = $self->namespace;
        my $namespace = '';
        if ($pkg->meta->has_namespace) {
            $namespace = $pkg->meta->namespace;
            if ($namespace !~ /^\Q$root_namespace\E/) {
                $self->log->warn("API - ignore $pkg (its namespace $namespace is not below this API namespace)");
                next;
            }
            $namespace =~ s/^\Q$root_namespace\E:://;
        }

        $self->log->trace("API - register $pkg: ".join(", ", $pkg->meta->command_list));
        push $self->plugin_packages->@*, $pkg;

        # store commands and their source package
        for my $cmd ($pkg->meta->command_list) {
            # check if command was previously defined by another package
            my $earlier_pkg = $result->{$namespace}->{$cmd};
            if ($earlier_pkg) {
                my $earlier_file = $pkg_map->{$earlier_pkg};
                OpenXPKI::Exception->throw(
                    message => "API command '$cmd' now defined in $pkg was previously found in $earlier_pkg",
                    params => { now_file => $file, previous_file => $earlier_file }
                );
            }
            $result->{$namespace}->{$cmd} = $pkg;
        }
    }

    # Check if a command name equals a relative namespace (this would confuse our autoloader magic)
    for my $namespace (keys $result->%*) {
        for my $cmd ($result->{$namespace}->%*) {
            OpenXPKI::Exception->throw(
                message => sprintf("API command name '%s' in %s equals a (relative) namespace name", $cmd, $result->{$namespace}->{$cmd})
            ) if exists $result->{$cmd};
        }
    }

    return $result;
}

=head2 rel_namespaces

Readonly: an I<ArrayRef> of all relative command namespaces, i.e. with this
API's root namespace parts cut off.

If there are no namespaces defined in any plugin this only contains a single
item C<""> (empty string).

=cut
has rel_namespaces => (
    is => 'rw',
    isa => 'ArrayRef',
    init_arg => undef,
    lazy => 1,
    default => sub ($self) { [ keys $self->_namespace_commands->%* ] },
);

=head2 has_non_root_namespaces

Readonly: returns TRUE if there is any non-root namespace.

=cut
has has_non_root_namespaces => (
    is => 'rw',
    isa => 'Bool',
    init_arg => undef,
    lazy => 1,
    default => sub ($self) { (scalar $self->rel_namespaces->@* > 1 or any { $_ ne '' } $self->rel_namespaces->@*) ? 1 : 0 },
);

=head1 METHODS

=head2 namespace_commands

Returns a I<HashRef> with API commands of the given relative namespace and
their Perl packages.

    my $root_cmds = $api->namespace_commands;
    my $config_cmds = $api->namespace_commands('config');

If no namespace is specified the commands of this API's root namespace (i.e.
usually those that did not explicitely set a namespace) are returned.

Structure:

    {
        'command_a' => 'OpenXPKI::Server::API2::Plugin::namespace1::command',
        'command_b' => 'OpenXPKI::Server::API2::Plugin::namespace1::command',
        ...
    }

B<Parameters>

=over

=item * C<$namespace> - Optional: relative (!) namespace

=back

=cut
signature_for namespace_commands => (
    method => 1,
    positional => [
        'Optional[ Str ]',
    ],
);
sub namespace_commands ($self, $namespace = '') {
    return $self->_namespace_commands->{$namespace} // {};
}

=head2 dispatch

Dispatches an API command call to the responsible plugin instance.

B<Named parameters>

=over

=item * C<rel_namespace> - Optional: B<relative> command namespace. Default: C<"">
(root namespace = API namespace)

=item * C<command> - Command name

=item * C<params> - Parameter hash

=item * C<protected_call> - Optional: must be set to TRUE to call a protected
command while L</enable_protection> is TRUE

=back

=cut
signature_for dispatch => (
    method => 1,
    named => [
        rel_namespace => 'Str', { default => '' },
        command => 'Str',
        params => 'Optional[ HashRef ]', { default => {} },
        protected_call => 'Bool', { default => 0 },
    ],
);
sub dispatch ($self, $arg) {
    my $rel_ns = $arg->rel_namespace;
    my $command = $arg->command;

    # Known namespace?
    if (not any { $rel_ns eq $_ } $self->rel_namespaces->@*) {
        OpenXPKI::Exception->throw(
            message => "Unknown API namespace",
            params => { namespace => $rel_ns, command => $command, caller => sprintf("%s:%s", ($self->my_caller())[1,2]) },
        );
    }

    # Known command?
    my $package = $self->namespace_commands($rel_ns)->{ $command }
        or OpenXPKI::Exception->throw(
            message => "Unknown API command",
            params => { namespace => $rel_ns, command => $command, caller => sprintf("%s:%s", ($self->my_caller())[1,2]) },
        );

    # Protected command?
    if ($self->enable_protection and $package->meta->is_protected($command) and not $arg->protected_call) {
        OpenXPKI::Exception->throw(
            message => "Forbidden call to protected API command",
            params => { namespace => $rel_ns, command => $command, caller => sprintf("%s:%s", ($self->my_caller())[1,2]) }
        );
    }

    # ACL checks / parameter rewriting
    my $ns_and_command = ($rel_ns ? "$rel_ns." : '') . $command;
    my $all_params;
    if ($self->enable_acls) {
        my $rules = $self->_get_acl_rules($ns_and_command)
            or OpenXPKI::Exception->throw(
                message => "ACL does not permit call to API command",
                params => { namespace => $rel_ns, command => $command, caller => sprintf("%s:%s", ($self->my_caller())[1,2]) }
            );

        $all_params = $self->_apply_acl_rules($command, $rules, $arg->params);
    }
    else {
        $all_params = $arg->params;
    }

    $self->log->debug("API call to '$ns_and_command'");

    # Call command method
    my $result;
    try {
#        $result = $package->meta->execute($self, $command, $all_params);
        my $plugin = $package->new(rawapi => $self);

        if (my $preprocess = $self->can('preprocess_params')) {
            $preprocess->($self, $command, $all_params, $plugin);
        }

        my $param_obj = $package->meta->new_param_object($command, $all_params); # provided by OpenXPKI::Base::API::PluginMetaClassTrait
        $result = $plugin->$command($param_obj);
    }
    catch ($err) {
        return $self->handle_dispatch_error($err);
    }

    return $result;
}

# TODO - might be better part of the bootstrap process to have this cached?
signature_for command_help => (
    method => 1,
    positional => [
        'Str',
    ],
);
sub command_help ($self, $command) {
    # This is a 'Moose::Meta::Class' holding attributes and coderef
    my $attributes = $self->get_command_attributes(undef, $command);

    # each item is a 'Moose::Meta::Attribute'
    my %arguments = map {
        ( $_->name => {
                'required' => ($_->is_required? 1 : 0),
                'type' => ($_->has_type_constraint ? $_->type_constraint->name : 'unknown'),
                'documentation' => ($_->documentation || ''),
        })
    } $attributes->@*;

    return \%arguments;

}

=head2 get_command_attributes

Returns an I<ArrayRef> with the L<Moose::Meta::Attribute> objects of the
parameters of the given command.

=cut
signature_for get_command_attributes => (
    method => 1,
    positional => [ 'Str', 'Str' ],
);
sub get_command_attributes ($self, $namespace, $command) {
    $namespace //= ''; # convert undef to empty string (= root namespace)
    my $package = $self->namespace_commands($namespace)->{ $command };
    my $meta = $package->meta;

    OpenXPKI::Exception->throw(
        'Unable to find help for given API command'
    ) unless (blessed $meta && $meta->isa('Moose::Meta::Class'));

    # param_metaclass() returns a 'Moose::Meta::Class'
    my @attributes = sort { $a->name cmp $b->name } $meta->param_metaclass($command)->get_all_attributes;

    return \@attributes; # ArrayRef of Moose::Meta::Attribute
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
        next if $caller[0] =~ m{ ^ OpenXPKI::Base::API:: }x;
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

=item * C<$namespace> - Perl namespace (e.g. C<OpenXPKI::Base::API::Plugin>)

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
                my $dir = File::Spec->catdir($dir, $entry);
                next unless (
                    File::Spec->no_upwards($entry)
                    and $entry =~ $dir_rx
                    and -d $dir
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

=head1 ACLs

ACLs for the API commands can be defined on a per-role basis in each OpenXPKI
realm.

If ACLs are enabled (see L</enable_acls>) then the default is to forbid all API
commands. Allowed commands have to be specified per role in the realm.

The structure of the configuration subtree (below the realm) is as follows:

    acl:
        <role name>:
            policy: allow   # default policy: "allow" or "deny"
            commands:
                # deny access to command1 (root namespace)
                command1: 0

                # allow unfiltered access to namespace1.command1
                "<namespace1.command1>": 1

                # allow namespace1.command2 and preprocess arguments
                "<namespace1.command2>":
                    <parameter>:
                        required: 1
                        force:    <string>
                        default:  <string>
                        match:    <regex>
                        block:    1

                "<namespace2.command1>":
                    ...

        <role name>:
            ...

For commands in the root namespace (i.e. those where no namespace is set in the
plugin class) only the command name needs to be given without leading dot.

The ACL processor first looks if the command name has a key in the
I<commands> tree:

=over

=item * B<Command not specified>: if no key is found the action given by I<policy> is
taken. If no policy is set, the default is deny.

=item * B<True> value: allow unfiltered access to a command.

=item * B<False> value: fully deny access to the command.

=item * B<Detailed parameter rules>: to grant access to a command while
restricting its parameters a hash can be specified.

Default policy for parameters not mentioned in the given hash is to allow them.

Key is the parameter name and value is a hash with rules:

=over

=item C<B<required>>

Mark parameter as required.

    acl:
        CA Operator:
            search_cert:
                status:
                    required: 1

=item C<B<force>>

Enforce parameter value (overwrites a given value).

                    force: ISSUED

=item C<B<default>>

Set a default value if none was given (cannot be used together with C<force>).

                    default: ISSUED

=item C<B<match>>

Match parameter against regular expression. The Regex is executed using the
modifiers C</msx>, so please escape spaces.

                    match: \A (ISSUED|REVOKED) \z

=item C<B<block>>

Block parameter. An exception will be thrown if the caller tries to set
it.

                    block: 1

=back

=back

=head1 INTERNALS

=head2 Design principles

=over

=item * B<One or more commands per class>:

Each plugin class can specify one or more API commands. This allows to keep
helper functions that are shared between several API commands close to the
command code. It also helps reducing the number of individual Perl module files.

=item * B<No base class>:

When you use L<use OpenXPKI -plugin> to define a plugin class all
functionality is added via Moose roles instead of a base class. This allows for
plugin classes to be based on any other classes if needed.

=item * B<Standard magic>:

Syntactic sugar and helper functions only use Moose's standard way to e.g.
customize meta classes or inject roles. No other black magic is used.

=back

=cut

1;
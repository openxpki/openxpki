package OpenXPKI::Client::API;
use OpenXPKI qw( -class -typeconstraints );

with 'OpenXPKI::Base::API::APIRole';

# required by OpenXPKI::Base::API::APIRole
sub namespace { 'OpenXPKI::Client::API::Command' }

# Core modules
use List::Util qw( any none );

# CPAN modules
use Pod::Find qw(pod_where);
use Pod::POM;
use Pod::POM::View::Text;
use Log::Log4perl qw(:easy :no_extra_logdie_message);

# Project modules
use OpenXPKI::Client::API::Util;

=head1 NAME

OpenXPKI::Client::API

=head1 SYNOPSIS

Root class that provides an API to access the commands defined below
C<OpenXPKI::Client::API::Command>. The constuctor of the API does not
take any arguments.

The API is structured into commands and subcommands.

The result of any dispatch is a C<OpenXPKI::Client::API::Response>
instance.

=head1 Methods

=head2 Commands

Find the available commands by iterating over all perl modules found
directly below C<OpenXPKI::Client::API::Command>. Return value is a
hash ref with the names as key and the description (extracted from POD)
as value.

=cut

has commands => (
    is => 'ro',
    isa => 'HashRef[Str]',
    builder => '_build_commands',
    lazy => 1,
);

sub _build_commands ($self) {
    my %commands = map {
        my $pod = $self->getpod($_, 'SYNOPSIS');
        $pod =~ s{\A[^\n]*\n\s+(.+?)[\s\n]*\z}{$1}ms;
        $pod =~ s{[\s\n]*\z}{}ms;
        (substr($_,32) => $pod);
    } map { $self->namespace . '::' . $_ } $self->rel_namespaces->@*;

    return \%commands;
}

has log => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    default => sub { return Log::Log4perl->get_logger(); },
    lazy => 1,
);

has client => (
    is => 'rw',
    isa => 'Object',
    lazy => 1,
    default => sub { shift->log->logdie('Client object was not initialized'); },
    predicate => 'has_client',
);

my %internal_command_attributes = (
    payload => { isa => 'ArrayRef[Str]' },
    positional_args => { isa => 'ArrayRef[Str]' }
);

sub BUILD ($self, $args) {
    # add these attributes to all API commands
    for my $pkg ($self->plugin_packages->@*) {
        $pkg->meta->add_default_attribute_spec(%internal_command_attributes);
    }
}

# required by OpenXPKI::Base::API::APIRole
sub handle_dispatch_error ($self, $err) {
    if (blessed $err) {
        if ($err->isa("Moose::Exception")) {
            if ($err->isa('Moose::Exception::AttributeIsRequired')) {
                die OpenXPKI::DTO::ValidationException->new( field => $err->attribute_init_arg, reason => 'required' );
            }
            if (
                $err->isa('Moose::Exception::ValidationFailed')
                or $err->isa('Moose::Exception::ValidationFailedForTypeConstraint')
            ) {
                die OpenXPKI::DTO::ValidationException->new( field => $err->attribute->init_arg, reason => 'type' );
            }
        }
        $err->rethrow if $err->can('rethrow');
    }
    die $err;
}

=head2 preprocess_params

A hook called by L<OpenXPKI::Base::API::APIRole/dispatch>.

It converts minuses to underscores in parameter names and processes the C<hint>
parameter attribute.

It throws a C<OpenXPKI::DTO::ValidationException> object on validation
errors.

=cut
# $params - ArrayRef[Moose::Meta::Attribute]
sub preprocess_params ($self, $command, $input_params, $plugin) {
    for my $name (keys $input_params->%*) {
        my $val = $input_params->{$name};

        # convert minus to underscore
        my $new_name = OpenXPKI::Client::API::Util::to_api_field($name);
        if ($new_name ne $name) {
            $input_params->{$new_name} = $val;
            delete $input_params->{$name};
            $name = $new_name;
        }

        # parameter hints - Empty input + hint flag = show choices
        next unless (defined $val and $val eq '');

        my $param = $plugin->meta->get_param_metaclass($command)->get_attribute($name);
        next unless $param->has_hint;

        $self->log->debug('Call hint method "'.$param->hint.'" to get choices');
        my $hint_cb = $plugin->can($param->hint)
          or die "Method '".$param->hint."' not found in ".$plugin->meta->name."\n";
        my $choices = $hint_cb->($plugin, $input_params);
        $self->log->trace('Result from hint method: ' . Dumper $choices) if $self->log->is_trace;
        die OpenXPKI::DTO::ValidationException->new( field => $name, reason => 'choice', choices => $choices );
    }
}

=head2 getpod I<package> I<section>

Extract the POD documentation found at I<section> from the given I<package>.
Section defaults to I<USAGE> if not given, uses pod_where to find the file
to read the POD from. Returns plain text by applying Pod::POM::View::Text

=cut

sub getpod ($self, $package, $section = 'USAGE') {
    my $path = pod_where({-inc => 1}, ($package));

    return "no documentation available" unless($path);
    # Code copied from API2 pod handler, should be unified
    my $pom = Pod::POM->new;
    my $tree = $pom->parse_file($path)
        or return "ERROR: ".$pom->error();

    my @heading_blocks = grep { $_->title eq $section } $tree->head1;
    return "ERROR: Missing section $section in $path" unless scalar @heading_blocks;

    # need to add subsections ?
    my $pod = Pod::POM::View::Text->print($heading_blocks[0]->content);
    $pod =~ s/\s+$//m;
    return $pod;

    # FIXME Code after return
    my @cmd_blocks = grep { $_->title eq $package } $heading_blocks[0]->head2;
    return "ERROR: No description found for '$package' in $path" unless scalar @cmd_blocks;

    return Pod::POM::View::Text->print($cmd_blocks[0]->content);

}

=head2 subcommands I<command>

Find the available subcommands for the given I<command> by iterating
over all perl modules found in the constructed namespace. Return
value is a hash ref with the names as key and the description
(extracted from POD) as value.

Will die if the command can not be found in the I<commands> list.

=cut

sub subcommands ($self, $command) {
    if (none { $command eq $_ } $self->rel_namespaces->@*) {
        die "Unknown command '$command'\n";
    }
    my @subcmd = keys $self->namespace_commands($command)->%*;
    my %subcmd = map {
        my $pod = $self->getpod($self->namespace . "::${command}::${_}", 'SYNOPSIS');
        $pod =~ s{\A[^\n]*\n\s+(.+?)[\s\n]*\z}{$1}ms;
        $pod =~ s{[\s\n]*\z}{}ms;
        ($_ => $pod);
    } @subcmd;
    return \%subcmd;
}

=head2 help I<command> [I<subcommand>]

Runs C<getpod> on the package name constructed from the given arguments.

If a I<subcommand> is given, evaluates the parameter specification and
renders a description on the parameters.

=cut

sub help ($self, $command = '', $subcommand = '', @) {
    unless ($command) {
        my $pod = "Available commands:";
        my $commands = $self->commands;
        $pod .= sprintf "%12s: %s\n", $_, $commands->{$_} for sort keys $commands->%*;
        return $pod;
    }

    LOGDIE("Invalid characters in command") unless($command =~ m{\A\w+\z});
    # TODO - select right sections and enhance formatting
    unless ($subcommand) {
        my $pod = $self->getpod($self->namespace . "::${command}", 'SYNOPSIS');
        $pod .= "\n\nAvailable subcommands:\n";
        my $subcmds = $self->subcommands($command);
        $pod .= sprintf "%12s: %s\n", $_, $subcmds->{$_} for sort keys $subcmds->%*;
        return $pod;
    }

    LOGDIE("Invalid characters in subcommand") unless($subcommand =~ m{\A\w+\z});
    my $pod = $self->getpod($self->namespace . "::${command}::${subcommand}", 'SYNOPSIS');

    # Generate parameter help from spec
    # Might be useful to write POD and parse to text to have unified layout
    try {
        # list of Moose::Meta::Attribute
        if (my @spec = $self->get_command_attributes($command, $subcommand)->@*) {
            $pod .= "\n\nParameters:\n";
            for my $param (@spec) {
                next if exists $internal_command_attributes{$param->name};
                $pod .= sprintf('  - %s: %s', OpenXPKI::Client::API::Util::to_cli_field($param->name), $param->label);
                $pod .= ', ' . $self->openapi_type($param);
                $pod .= ', required' if $param->is_required;
                $pod .= ', hint' if $param->has_hint;
                $pod .= ', default: '.$param->default if $param->has_default;
                $pod .= "\n    " . $param->description if $param->has_description;
                $pod .= "\n";
            };
        }
    }
    catch ($err) {
        $self->log->warn("Error fetching parameter list for command '$command.$subcommand': $err");
    }

    return $pod;
}

=head2 getopt_params I<command> [I<subcommand>]

Return the parameters required to run C<Getopt::Long/GetOptions>.

=cut

sub getopt_params ($self, $command, $subcommand) {
    my @spec = $self->get_command_attributes($command, $subcommand)->@*;

    return map {
        my $type = $self->getopt_type($_);
        my $name = OpenXPKI::Client::API::Util::to_cli_field($_->name);
        $name . ($type ? ($_->has_hint ? ':' : '=') . $type : '')
    } grep { not exists $internal_command_attributes{$_->name} } @spec;
}

signature_for getopt_type => (
    method => 1,
    positional => [ 'Moose::Meta::Attribute' ],
);
sub getopt_type ($self, $attribute) {
    return $self->map_value_type(
        $attribute,
        {
            'Int' => 'i',
            'Num' => 'f',
            'Str' => 's',
            'Bool' => '',
        }
    );
}

signature_for openapi_type => (
    method => 1,
    positional => [ 'Moose::Meta::Attribute' ],
);
sub openapi_type ($self, $attribute) {
    return $self->map_value_type(
        $attribute,
        {
            'Int' => 'integer',
            'Num' => 'numeric',
            'Str' => 'string',
            'Bool' => 'boolean',
        }
    );
}

signature_for map_value_type => (
    method => 1,
    positional => [ 'Moose::Meta::Attribute', 'HashRef' ],
);
sub map_value_type ($self, $attribute, $map) {
    my @to_check = $attribute->type_constraint;

    while (my $type = shift @to_check) {
        # If current type constraint is known, return its mapped type
        return $map->{$type->name} if any { $type->name eq $_ } keys $map->%*;

        # Type coercion - check all "from" types
        if ($type->has_coercion) {
            push @to_check, map { find_type_constraint($_) } $type->coercion->type_coercion_map->@*;
        }

        # Union type ("Str | Undef") - check all parts
        if ($type->isa('Moose::Meta::TypeConstraint::Union')) {
            push @to_check, $type->type_constraints->@*;

        # Derived type - check parent
        } elsif ($type->has_parent) {
            push @to_check, $type->parent;
        }
    }

    return;
}

__PACKAGE__->meta->make_immutable;

package OpenXPKI::Client::API;
use OpenXPKI qw( -class -typeconstraints );

with 'OpenXPKI::Base::API::APIRole';

# required by OpenXPKI::Base::API::APIRole
sub namespace { 'OpenXPKI::Client::API::Command' }

# Core modules
use List::Util qw( any none );
use Pod::Usage qw( pod2usage );

# CPAN modules
use Pod::Find qw(pod_where);
use Pod::POM;
use Pod::POM::View::Text;
use Log::Log4perl qw(:easy :no_extra_logdie_message);

# Project modules
use OpenXPKI::Client::API::Util;

=head1 NAME

OpenXPKI::Client::API

=head1 DESCRIPTION

Root class that provides an API to access the commands defined in the namespace
C<OpenXPKI::Client::API::Command::*>.

The API is structured into commands and subcommands.

The result of any dispatch is a L<OpenXPKI::Client::API::Response>
instance.

=head1 ATTRIBUTES

=head2 script_name

Name of the Perl script for token replacement in L</show_pod>. Required.

=cut

has script_name => (
    required => 1,
    is => 'ro',
    isa => 'Str',
);

=head1 METHODS

=head2 commands

Lists available API commands by iterating over all Perl modules found directly
in the namespace C<OpenXPKI::Client::API::Command::*>.

Returns a I<HashRef> with the names as key and the description (extracted from POD)
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
        my $pod = $self->get_pod_text($_, 'DESCRIPTION');
        $pod =~ s{\A[^\n]*\n\s+(.+?)[\s\n]*\z}{$1}ms;
        $pod =~ s{[\s\n]*\z}{}ms;
        ($_ => $pod);
    } $self->rel_namespaces->@*;

    return \%commands;
}

has log => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    default => sub { Log::Log4perl->get_logger; },
    lazy => 1,
);

has client => (
    is => 'rw',
    isa => 'Object',
    lazy => 1,
    default => sub { shift->log->logdie('Client object was not initialized'); },
    predicate => 'has_client',
);

has is_privileged => (
    is => 'ro',
    isa => 'Bool',
    lazy => 1,
    default => sub { return shift->client->authenticator()->has_account_key(); },
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

Throws a C<OpenXPKI::DTO::ValidationException> object on validation
errors.

=cut
# $input_params - HashRef[Str]
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

=head2 subcommands (I<$command>)

Find the available subcommands for the given I<$command> by iterating
over all perl modules found in the constructed namespace. Return
value is a hash ref with the names as key and the description
(extracted from POD) as value.

Will die if the command is unknown.

=cut

sub subcommands ($self, $command) {
    if (none { $command eq $_ } $self->rel_namespaces->@*) {
        die "Unknown command '$command'\n";
    }
    my @subcmd = keys $self->namespace_commands($command)->%*;
    my %subcmd = map {
        my $pod = $self->get_pod_text(join('::', $command, $_), 'DESCRIPTION');
        $pod =~ s{\A[^\n]*\n\s+(.+?)[\s\n]*\z}{$1}ms;
        $pod =~ s{[\s\n]*\z}{}ms;
        ($_ => $pod);
    } @subcmd;
    return \%subcmd;
}

=head2 get_pod_nodes (I<$rel_package_or_path>, I<$section>)

Extract the POD documentation found at I<$section> from the given
I<$rel_package_or_path> (or all POD if I<$section> is omitted).

I<$rel_package_or_path> is either a file path or the the last part of the
package name consisting of command or command+C<::>+subcommand, e.g. C<acme> or
C<acme::create>.

Uses L<POD::Find/pod_where> to find the file to read the POD from.

Returns a list of POD nodes.

=cut

sub get_pod_nodes ($self, $rel_package_or_path, $section = undef) {
    my $path;
    if (-f $rel_package_or_path) {
        $path = $rel_package_or_path;
    } else {
        $path = pod_where({-inc => 1}, join('::', $self->namespace, $rel_package_or_path))
            or return "no documentation available";
    }

    # Code copied from API2 pod handler, should be unified
    my $pom = Pod::POM->new;
    my $tree = $pom->parse_file($path) or return "ERROR: ".$pom->error;

    my @heading_blocks = $tree->head1;

    # filter headings if $section was set
    if ($section) {
        @heading_blocks = grep { $_->title eq $section } @heading_blocks;
        return "ERROR: Missing section '$section' in $path" unless @heading_blocks;
    }

    return (@heading_blocks);
}

=head2 get_pod (I<$rel_package_or_path>, I<$section>)

Extract the POD documentation found at I<$section> from the given
I<$rel_package_or_path> (or all POD if I<$section> is omitted).

I<$rel_package_or_path> is either a file path or the the last part of the
package name consisting of command or command+C<::>+subcommand, e.g. C<acme> or
C<acme::create>.

Returns a POD string.

=cut

sub get_pod ($self, $rel_package_or_path, $section = undef) {
    return join '', $self->get_pod_nodes($rel_package_or_path, $section);
}

=head2 get_pod_text (I<$rel_package_or_path>, I<$section>)

Extract the POD documentation found at I<$section> from the given
I<$rel_package_or_path>.

I<$rel_package_or_path> is either a file path or the the last part of the
package name consisting of command or command+C<::>+subcommand, e.g. C<acme> or
C<acme::create>.

Converts the POD section contents (without heading) to plain text via
L<Pod::POM::View::Text>.

=cut

sub get_pod_text ($self, $rel_package_or_path, $section) {
    # need to add subsections ?
    my @nodes = $self->get_pod_nodes($rel_package_or_path, $section);
    my $pod = join "\n\n", map { Pod::POM::View::Text->print($_->content) } @nodes;
    $pod =~ s/\s+$//m;
    return $pod;
}

=head2 show_pod

Thin wrapper around L<POD::Usage/pod2usage> that replaces special tokens:

=over

=item C<%%SCRIPT%%>

The Perl script name.

=item C<%%COMMANDS%%>

A POD formatted list of available commands and their description.

=back

Per default these sections are shown:

    USAGE
    SYNOPSIS
    DESCRIPTION
    COMMANDS
    SUBCOMMANDS
    PARAMETERS
    OPTIONS

All arguments are passed to L<pod2usage|POD::Usage/pod2usage>.

=cut

sub show_pod ($self, @args) {
    my %args = @args;
    my $pod = delete $args{-oxi_pod} or die "show_pod(): missing parameter -oxi_pod";

    # inject variables
    my $script = $self->script_name;
    $pod =~ s/%%SCRIPT%%/$script/g;

    if ($pod =~ /%%COMMANDS%%/) {
        my $pod_cmd = "=over\n\n";
        my $cmds = $self->commands;
        for my $cmd (sort keys $cmds->%*) {
            $pod_cmd.= sprintf "=item %s\n\n%s\n\n", $cmd, $cmds->{$cmd};
        }
        $pod_cmd.= "=back\n\n";
        $pod =~ s/%%COMMANDS%%/$pod_cmd/g;
    }

    # print formatted POD
    open my $pod_fh, '<', \$pod;
    pod2usage(
        -input => $pod_fh,
        -verbose => 99,
        -sections => 'USAGE|SYNOPSIS|DESCRIPTION|COMMANDS|SUBCOMMANDS|PARAMETERS|OPTIONS',
        %args,
    ); # calls exit()
}

sub get_attribute_details ($self, $cmd, $subcmd) {
    my $attrs = {};
    try {
        # list of Moose::Meta::Attribute
        for my $param ($self->get_command_attributes($cmd, $subcmd)->@*) {
            next if exists $internal_command_attributes{$param->name};
            # name
            my $name = OpenXPKI::Client::API::Util::to_cli_field($param->name);
            # specification
            my $spec = $self->openapi_type($param);
            $spec.= ', required' if $param->is_required;
            $spec.= ', hint' if $param->has_hint;
            $spec.= sprintf(', default: "%s"', $param->default) if $param->has_default;
            # description
            my $desc = $param->label;
            $desc.= " - " . $param->description if $param->has_description;

            $attrs->{$name} = {
                spec => $spec,
                desc => $desc,
            }
        }
    }
    catch ($err) {
        $self->log->warn("Error fetching parameter list for command '$cmd.$subcmd': $err");
    }
    return $attrs;
}

=head2 getopt_params (I<$command>, I<$subcommand>)

Return the parameters required to run L<Getopt::Long/GetOptions>.

I<$subcommand> may be omitted.

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

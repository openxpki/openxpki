package OpenXPKI::Client::API;

use Moose;

use Data::Dumper;
use Mojo::Loader;

use Pod::Find qw(pod_where);
use Pod::POM;
use Pod::POM::View::Text;

use Log::Log4perl qw(:easy :no_extra_logdie_message);
Log::Log4perl->easy_init($TRACE);

=head1 NAME

OpenXPKI::Client::API

=head1 SYNOPSIS

Root class that provides an API to access the commands defined below
C<OpenXPKI::Client::API::Command>. The constuctor of the API does not
take any arguments.

The API is structured into commands and subcommands, input is handled
by the C<OpenXPKI::Client::API::Request> class, description and
validation of input fields is implemented by C<OpenXPKI::DTO::Field>.

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

sub _build_commands {
    my $self = shift;
    my @plugins = Mojo::Loader::find_modules('OpenXPKI::Client::API::Command');
    my %commands = map {
        my $pod = $self->getpod($_, 'SYNOPSIS');
        $pod =~ s{\A[^\n]*\n\s+(.+?)[\s\n]*\z}{$1}ms;
        $pod =~ s{[\s\n]*\z}{}ms;
        (substr($_,32) => $pod);
    } @plugins;
    return \%commands;
}

has log => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    default => sub { return Log::Log4perl->get_logger(); },
    lazy => 1,
);


=head2 getpod I<package> I<section>

Extract the POD documentation found at I<section> from the given I<package>.
Section defaults to I<USAGE> if not given, uses pod_where to find the file
to read the POD from. Returns plain text by applying Pod::POM::View::Text

=cut

sub getpod {

    my $self = shift;
    my $package = shift;
    my $section = shift || 'USAGE';
    my $path = pod_where({-inc => 1}, ($package));

    return "no documentation available" unless($path);
    # Code copied from API2 pod handler, should be unified
    my $pom = Pod::POM->new;
    my $tree = $pom->parse_file($path)
        or return "ERROR: ".$pom->error();

    my @heading_blocks = grep { $_->title eq $section } $tree->head1;
    return "ERROR: Missing section $section in $path" unless scalar @heading_blocks;

    # need to add subsections ?
    return Pod::POM::View::Text->print($heading_blocks[0]->content);

    my @cmd_blocks = grep { $_->title eq $package } $heading_blocks[0]->head2;
    return "ERROR: No description found for '$package' in $path" unless scalar @cmd_blocks;

    return Pod::POM::View::Text->print($cmd_blocks[0]->content);

}

=head2 routes I<command>

Find the available subcommands for the given I<command> by iterating
over all perl modules found in the constructed namespace. Return
value is a hash ref with the names as key and the description
(extracted from POD) as value.

Will die if the command can not be found in the I<commands> list.

=cut

sub routes {

    my $self = shift;
    my $command = shift;

    my $command_ref = $self->commands();
    if (!$command_ref->{$command}) {
        die "command $command does not exist";
    }

    my $base = "OpenXPKI::Client::API::Command::$command";
    my @subcmd = Mojo::Loader::find_modules($base);
    my %subcmd = map {
        my $pod = $self->getpod($_, 'SYNOPSIS');
        $pod =~ s{\A[^\n]*\n\s+(.+?)[\s\n]*\z}{$1}ms;
        $pod =~ s{[\s\n]*\z}{}ms;
        (substr($_,length($base)+2) => $pod);
    } @subcmd;
    return \%subcmd;

}

=head2 help I<command> [I<subcommand>]

Runs C<getpod> on the package name constructed from the given arguments.

If a I<subcommand> is given, evaluates the parameter specification by
running C<param_spec> and renders a description on the parameters.

=cut

sub help {

    my $self = shift;
    my $command = shift;
    my $subcommand = shift;

    LOGDIE("Invalid characters in command") unless($command =~ m{\A\w+\z});
    # TODO - select right sections and enhance formatting
    if (!$subcommand) {
        return $self->getpod("OpenXPKI::Client::API::Command::${command}", 'SYNOPSIS');
    }

    LOGDIE("Invalid characters in subcommand") unless($subcommand =~ m{\A\w+\z});
    my $pod = $self->getpod("OpenXPKI::Client::API::Command::${command}::${subcommand}", 'SYNOPSIS');

    # Generate parameter help from spec
    # Might be useful to write POD and parse to text to have unified layout
    my @spec = @{$self->param_spec($command, $subcommand)};
    return $pod unless(@spec);

    $pod .= "Parameters\n";
    map {
        $pod .= sprintf('  %s (%s)', $_->label, $_->name);
        $pod .= ', ' . $_->openapi_type;
        $pod .= ', required' if ($_->required);
        $pod .= ', hint' if (defined $_->hint);
        $pod .= ', default: '.$_->value if ($_->has_value);
        $pod .= "\n    " . $_->description if ($_->description);
        $pod .= "\n\n";
    } @spec;

    return $pod;

}

=head2 load_class I<command> I<subcommand>

Constructs the package name from the given arguments and loads the class
into the perl namespace. The return value is the name of the class, the
command does not create a class instance.

The command dies if the class can not be loaded.

=cut

sub load_class {

    my $self = shift;
    my $command = shift;
    my $subcommand = shift;
    my $request = shift;

   LOGDIE("Invalid characters in command") unless($command =~ m{\A\w+\z});
   LOGDIE("Invalid characters in subcommand") unless($subcommand =~ m{\A\w+\z});

    my $impl_class = "OpenXPKI::Client::API::Command::${command}::${subcommand}";
    my $error = Mojo::Loader::load_class($impl_class);
    if ($error) {
        LOGDIE(die ref $error ? $error : "Unable to find ${subcommand} in ${command}");
    }
    return $impl_class;
}

=head2 param_spec I<command> I<subcommand>

Returns the I<param_spec> for the given I<subcommand>.

=cut

sub param_spec {

    my $self = shift;
    my $impl_class = $self->load_class(shift, shift);
    return $impl_class->param_spec();
}


=head2 dispatch I<command> I<subcommand> I<request object>

Runs the stated command on the input data passed via the request object.

The request is first handed over to the commands C<preprocess> handler
which might result in a validation error. On success, the C<execute>
method is called to handle the request.

The request must be an C<OpenXPKI::Client::API::Request> object.

The return value is an instance of C<OpenXPKI::Client::API::Response>
with the payload holding the result of the command. If a validation
error occurs, the result code is 400 and the payload is an instance of
C<OpenXPKI::DTO::ValidationException>.

Check the documentation of C<OpenXPKI::Client::API::Command> for more
details.

=cut

sub dispatch {

    my $self = shift;
    my $command_ref = $self->load_class(shift, shift)->new();

    my $request = shift;
    # Returns a validation error object in case something went wrong
    # Preprocess MIGHT change the paramters in the request object!
    if (my $validation = $command_ref->preprocess($request)) {
        return $validation;
    }
    # Returns the response data structure
    return $command_ref->execute($request);

}

__PACKAGE__->meta()->make_immutable();

1;

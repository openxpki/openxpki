package OpenXPKI::Server::Authentication::Command;

use Moose;
extends 'OpenXPKI::Server::Authentication::Base';

use OpenXPKI::Debug;
use Proc::SafeExec;
use OpenXPKI::Template;
use OpenXPKI::Server::Authentication::Handle;
use OpenXPKI::Server::Context qw( CTX );

has env => (
    is => 'ro',
    isa => 'HashRef',
    predicate => 'has_env',
);

has command => (
    is => 'ro',
    isa => 'Str|ArrayRef',
    required => 1,
);

has output_template => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_output_template',
);

has toolkit => (
    is => 'rw',
    isa => 'Template',
    lazy => 1,
    default => sub {
        return OpenXPKI::Template->new();
    }
);

sub handleInput {

    ##! 1: 'start'
    my $self  = shift;
    my $msg   = shift;

    ##! 2: 'login data received'
    my $username = $msg->{username};

    return unless ($username);

    my @clearenv;
    if ($self->has_env()) {
        my $keys = $self->env();
        @clearenv = keys %{$keys};
        foreach my $name (@clearenv) {
            # get pattern from config
            my $value = $keys->{$name};

            # run template toolkit in case there are tags in the string
            $value = $self->toolkit()->render($value, $msg) if ($value =~ m{\[%});

            next unless($value ne '');

            $self->logger->debug("Adding env key $name");
            # set environment for executable
            $ENV{$name} = $value;
        }
    }

    # execute external program. this is safe, since cmd
    # is taken literally from the configuration.
    # NOTE: do not extend this code to allow login parameters
    # to be passed on the command line.
    # - the credentials may be visible in the OS process
    #   environment
    # - worse yet, it is untrusted user input that might
    #   easily be used to execute arbitrary commands on the
    #   system.
    # SO DON'T EVEN THINK ABOUT IT!

    my $cmd = $self->command();
    my @cmd;
    if (ref $cmd) {
        @cmd = @{$cmd};
    } else {
        @cmd = split " " , $cmd;
    }


    # make sure Proc::SafeExec can collect exit status via waitpid()
    local $SIG{'CHLD'} = 'DEFAULT' if (not $SIG{'CHLD'} or $SIG{'CHLD'} eq 'IGNORE');

    my ($out, $retval) = Proc::SafeExec::backtick(@cmd);
    map { delete $ENV{$_} } @clearenv; # clear environment

    $self->logger->debug("Got return value $retval / $out");

    ##! 2: "command returned $retval, STDOUT was: $out"
    if ($retval != 0) {
        return OpenXPKI::Server::Authentication::Handle->new(
            username => $username,
            error => OpenXPKI::Server::Authentication::Handle::LOGIN_FAILED,
            error_message => "Command returned: $out"
        );
    }

    my $role;
    if ($self->has_role()) {

        $role = $self->role();

    } else {

        if ($self->has_output_template()) {
            $self->logger->debug("Render output template for role");
            $out = $self->toolkit()->render($self->output_template, { out => $out });
        }
        # trim whitespace on both ends
        $out =~ s/^\s+|\s+$//g;

        # Assert if the role is not defined
        if (!$out || !CTX('config')->exists(['auth','roles', $out ])) {
            return OpenXPKI::Server::Authentication::Handle->new(
                username => $username,
                error => OpenXPKI::Server::Authentication::Handle::NOT_AUTHORIZED,
                error_message => "Command returned a role that is not defined: $out"
            );
        }
        $role = $out;
    }

    my %userinfo = %{$msg};
    delete $userinfo{username};
    # delete keys that might contain secrets
    map {
        defined $userinfo{$_} && delete $userinfo{$_};
    } ('username','password','token','secret');

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        userid => $self->get_userid( $username ),
        role => $role,
        userinfo => \%userinfo,
        authinfo => $self->authinfo(),
    );
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 OpenXPKI::Server::Authentication::Command

This is the class which supports OpenXPKI with an authentication method
via an external program. The input parameters are are passed as a hash
reference.

When called with a non-empty username, the handler maps the incoming
data into the environment based on the map given by I<env>.

The given command is executed, if its return value is zero the login
is assumed to be valid, otherwise LOGIN_FAILED is returned.

If a static role was set via I<role>, the username provided as input
and the static role are returned. If no role is set, the output of
the command is considered to be the name of the role. It is possible
to postprocess the output by setting I<output_template>. The resulting
string is checked to exist as role name at I<auth.roles>. If the output
does not qualify as valid role, a NOT_AUTHORIZED error is returned.

Any additional parameters set in the incoming hash will be set as
I<userinfo> B<except> the keys I<username>, I<password>, I<token>,
I<secret> which are always removed to avoid leakage of secrets.

The I<authinfo> section can be set as parameter to the handler (HashRef)
and is set as-is.

=head2 Login Parameters

Expects I<username> to be set to a non-empty value, any other parameters
can be set but are not used or validated by the handler itself.

=head2 Configuration Parameters

=over

=item command

The command to execute. A single command can be given as string, if you
need to pass a command with arguments you must pass them as an array.

The script must exit with a return value of 0 for a successful login.

If not I<role> is set, the script must print the role name to assign
on stdout.

For more details see See Proc::SafeExec.

=item env

Any incoming data is passed to the command by setting keys in the
environment. I<env> must be a HashRef where the keys are the names of
the environment variables. The values can either be a static word or a
template toolkit string. The incoming parameters are available with their
names inside the template, e.g. I<[% username%]> holds the value given as
username.

=item role

The role to assign to a valid login, if not set the output of the command
is used.

=item output_template

If no role is set, you can pass the commands output to template toolkit
for postprocessing. The template can access the output of the command
as I<[% out %]>.

The result must be the name of a valid role, leading and trailing
whitespace is removed by the handler.

=back

=head2 Configuration Examples

=head3 Static Role

In this mode, you need to specify the role for the user as a static value
inside the configuration.

 MyHandler:
   type: Command
   role: 'RA Operator'
   command: /path/to/your/script
   env:
        PASSWD: "[% password %]"
        LOGIN: "[% username %]"

The login will succeed if the script has exitcode 0. Here is a stub that
logs in user "john" with password "doe":

  #!/bin/bash

  if [ "$LOGIN" == "john" ] && [ "$PASSWD" == "doe" ]; then
    exit 0;
  fi;

  exit 1;

=head3 Output evaluation

If you do not set the role in the configuration, it is determined from the
scripts output. Leading/Trailing spaces are always stripped by the handler
internally. If your output needs more postprocessing (e.g. strip away a
prefix), you can specify a template toolkit string.

 MyHandler:
   type: Command
   command: /path/to/your/script
   output_template: "[% out.replace('role_','') %]"
   env:
        PASSWD: "[% password %]"
        LOGIN: "[% username %]"


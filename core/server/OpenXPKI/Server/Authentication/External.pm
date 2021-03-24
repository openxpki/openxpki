package OpenXPKI::Server::Authentication::External;

use strict;
use warnings;

use OpenXPKI::Debug;
use OpenXPKI::Server::Authentication::Handle;
use OpenXPKI::Server::Context qw( CTX );

use Moose;

extends 'OpenXPKI::Server::Authentication::Base';

has envkeys => (
    is => 'ro',
    isa => 'HashRef',
    predicate => 'has_envkeys',
);

has command => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has pattern => (
    is => 'ro',
    isa => 'Str',
);

has replacement => (
    is => 'ro',
    isa => 'Str',
);

sub handleInput {

    ##! 1: 'start'
    my $self  = shift;
    my $msg   = shift;


    ##! 2: 'login data received'
    my $username = $msg->{LOGIN} // $msg->{username};
    my $passwd  = $msg->{PASSWD} // $msg->{password};

    return unless ($username && defined $passwd);

    my @clearenv;
    if ($self->has_envkeys()) {
        my $keys = $self->envkeys();
        @clearenv = keys %{$keys};
        foreach my $name (@clearenv) {
            # get pattern from config
            my $value = $keys->{$name};

            # replace username and password placeholders
            $value =~ s/__USER__/$username/g;
            $value =~ s/__PASSWD__/$passwd/g;

            # set environment for executable
            $ENV{$name} = $value;
        }
    }

    # execute command
    my $command = $self->command();
    ##! 2: "execute command"

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
    # TODO - to be replaced by Proc::SafeExec?
    my $out = `$command`;
    map { delete $ENV{$_} } @clearenv; # clear environment

    ##! 2: "command returned $?, STDOUT was: $out"

    if ($? != 0) {
        return OpenXPKI::Server::Authentication::Handle->new(
            username => $username,
            error => OpenXPKI::Server::Authentication::Handle::LOGIN_FAILED
        );
    }

    my $role;
    if ($self->has_role()) {
        $role = $self->role();
    } else {
        my $pattern = $self->pattern();
        my $replace = $self->replacement();

        $out =~ s/$pattern/$replace/ if (defined $pattern && defined $replace);

        # trimming does not hurt
        $out =~ s/\s+$//g;
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

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        userid => $username,
        role => $role,
    );
}

1;
__END__

=head1 Name

OpenXPKI::Server::Authentication::External - support for external authentication.

=head1 Description

This is the class which supports OpenXPKI with an authentication method
via an external program. The parameters are passed as a hash reference.

=head2 Login Parameters

Expects the credentials given as I<username> and I<password>.

=head2 Configuration Parameters

=head3 Exit code only / static role

In this mode, you need to specify the role for the user as a static value
inside the configuration. The Username/Password is passed via the environment.

 MyHandler:
   type: External
   label: My Auth Handler
   command: /path/to/your/script
   role: 'RA Operator'
   env:
        LOGIN: __USER__
        PASSWD: __PASSWD__

The login will succeed if the script has exitcode 0. Here is a stub that
logs in user "john" with password "doe":

  #!/bin/bash

  if [ "$LOGIN" == "john" ] && [ "$PASSWD" == "doe" ]; then
    exit 0;
  fi;

  exit 1;

=head3 Output evaluation

If you do not set the role in the configuration, it is determined from the
scripts output. Trailing spaces are always stripped by the handler internally.
If your output needs more postprocessing (e.g. strip away a prefix), you can
specify a pattern and replacement, that are placed into a perl regex and
applied to the output.

 MyHandler:
   type: External
   label: My Auth Handler
   command: /path/to/your/script
   role: ''
   pattern: 'role_'
   replacement: ''
   env:
        LOGIN: __USER__
        PASSWD: __PASSWD__


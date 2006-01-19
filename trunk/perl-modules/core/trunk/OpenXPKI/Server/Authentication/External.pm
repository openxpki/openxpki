## OpenXPKI::Server::Authentication::External.pm 
##
## Written by Michael Bell 2006
## Copyright (C) 2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;

package OpenXPKI::Server::Authentication::External;

use OpenXPKI qw(debug);
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

## constructor and destructor stuff

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
                DEBUG     => 0,
               };

    bless $self, $class;

    my $keys = shift;
    $self->{DEBUG} = 1 if ($keys->{DEBUG});
    $self->debug ("start");

    my $config = CTX->config();

    $self->{COMMAND} = $config->get_xpath (XPATH   => [ %{$keys->{XPATH}},   "command" ],
                                           COUNTER => [ %{$keys->{COUNTER}}, 0 ]);
    $self->debug("command: ".$self->{COMMAND});

    if ($config->get_xpath_count (XPATH   => [ %{$keys->{XPATH}},   "role" ],
                                  COUNTER => [ %{$keys->{COUNTER}}, 0 ]))
    {
        $self->{ROLE} = $config->get_xpath (XPATH   => [ %{$keys->{XPATH}},   "role" ],
                                            COUNTER => [ %{$keys->{COUNTER}}, 0 ]);
        $self->debug("role: ".$self->{ROLE});
    } else {
        $self->{PATTERN} = $config->get_xpath (XPATH   => [ %{$keys->{XPATH}},   "pattern" ],
                                               COUNTER => [ %{$keys->{COUNTER}}, 0 ]);
        $self->{REPLACE} = $config->get_xpath (XPATH   => [ %{$keys->{XPATH}},   "replacement" ],
                                               COUNTER => [ %{$keys->{COUNTER}}, 0 ]);
    }

    # get environment settings
    $self->debug ("loading environment variable settings");

    my @clearenv;
    my $count = $config->get_xpath_count (XPATH    => [ %{$keys->{XPATH}}, 'env' ],
                                          COUNTER  => $keys->{COUNTER});
		
    for (my $i = 0; $i < $count; $i++)
    {
        my $name = $config->get_xpath (XPATH    => [ %{$keys->{XPATH}},   'env', 'name' ],
                                       COUNTER  => [ %{$keys->{COUNTER}}, $i,    0 ]);
        my $value = $config->get_xpath (XPATH    => [ %{$keys->{XPATH}},   'env', 'value' ],
                                        COUNTER  => [ %{$keys->{COUNTER}}, $i,    0 ]);
        $self->{ENV}->{$name} = $value;
        if (exists $self->{CLEARENV})
        {
            push (@{$self->{CLEARENV}}, $name);
        } else {
            $self->{CLEARENV} = [ $name ];
        }
        $self->debug("setenv: $name ::= $value");
    }
		
    $self->debug("finished");

    return $self;
}

sub login
{
    my $self = shift;
    $self->debug ("start");
    my $gui = shift;

    my ($account, $passwd) = $gui->get_passwd_login ("");

    $self->debug ("credentials ... present");
    $self->debug ("account ... $account");

    # see security warning below (near $out=`$cmd`)

    foreach my $name (keys %{$self->{ENV}})
    {
        my $value = $self->{ENV}->{$name};
	# we don't want to see expanded passwords in the log file,
	# so we just replace the password after logging it
	$value =~ s/__USER__/$account/g;
	$value =~ s/__PASSWD__/$passwd/g;

	# set environment for executable
	$ENV{$name} = $value;
    }
    my $command = $self->{COMMAND};
    $self->debug("execute command");

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
    my $out = `$command`;
    map { undef $ENV{$_} } @{$self->{CLEARENV}}; # clear environment

    $self->debug("command returned $?, STDOUT was: $out");
		
    if ($? != 0)
    {
        CTX->log->log (FACILITY => "auth",
                       PRIORITY => "warn",
                       MESSAGE  => "Login to external database failed.\n".
                                   "user::=$account\n".
                                   "logintype::=External");
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_EXTERNAL_LOGIN_FAILED",
            params  => {USER => $account});
    }

    $self->{USER} = $account;

    if (not exists $self->{ROLE})
    {
        $out =~ s/$self->{PATTERN}/$self->{REPLACE}/;
        $self->{ROLE} = $out;
    }
}

sub get_user
{
    my $self = shift;
    $self->debug ("start");
    return $self->{USER};
}

sub get_role
{
    my $self = shift;
    $self->debug ("start");
    return $self->{ROLE};
}

1;
__END__

=head1 Description

This is the class which supports OpenXPKI with an authentication method
via an external program. The parameters are passed as a hash reference.

=head1 Functions

=head2 new

is the constructor. The supported parameters are DEBUG, XPATH and COUNTER.
This is the minimum parameter set for any authentication class.
The XML configuration includes a command tag and a role or a regular expression
configuration (pattern and replacement). Additionally it is possible to
specify environment variables. The tag env must include a name and a value
parameter. Please note that the strings __USER__ and __PASSWORD__ in the value
parameter will be replaced by the entered user and passphrase.

=head2 login

returns true if the login was ok.

=head2 get_user

returns the user from the successful login.

=head2 get_role

returns the role which is specified in the configuration or extracted from
the returned output of the external command.

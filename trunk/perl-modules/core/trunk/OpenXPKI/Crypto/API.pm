## OpenXPKI::Crypto::API.pm
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

package OpenXPKI::Crypto::API;
	
use strict;
use warnings;
use English;

use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use Data::Dumper;

# The instance of the corresponding Backend/Tool class
my %instance_of       :ATTR( :get<instance> );
# a hash of commands and their allowed parameters    
my %command_params_of :ATTR( :get<command_params> :set<command_params> );

sub START {
    my ($self, $ident, $arg_ref) = @_;

    if (ref $self eq 'OpenXPKI::Crypto::API') {
        # somebody tried to instantiate us, but we are supposed to be abstract.
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_API_IS_ABSTRACT_CLASS',
        );
    }

    if ((! defined $arg_ref->{CLASS}) || ($arg_ref->{CLASS} eq '')) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_API_NEW_MISSING_CLASS',
        );
    }
    my $class = $arg_ref->{CLASS};
    delete $arg_ref->{CLASS};

    eval "require $class";
    if ($EVAL_ERROR ne '') {
        ##! 4: "compilation of driver " . $class . " failed\n$EVAL_ERROR"
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_API_EVAL_ERROR',
            params  => {
                error_message => $EVAL_ERROR,
            },
        );
    }

    $instance_of{$ident} = $class->new($arg_ref);
}

sub __init_command_params { # implemented in the children classes,
                            # fills the command_params hash
}

sub command { # this is typically used as $token->command()
    my $self = shift;
    my $arg_ref = shift;
    my $ident = ident $self;

    ## the following is done so that the order of the dump is
    ## sorted, which allows us to censor the debug output more
    ## effectively ...
    $Data::Dumper::Sortkeys = 1;
    ##! 16: 'arg_ref: ' . Dumper($arg_ref)
    my $command = $arg_ref->{COMMAND};

    ## FIXME: actually we check only for the allowed parameter
    ## FIXME: if we want to make this a real API enforcer then we have to
    ## FIXME: check the content too.
    ## FIXME: perhaps Sergei or Julia could do this?
    ## Note that this non-trivial ...

    foreach my $param (keys %{$arg_ref}) {
        next if ($param eq "COMMAND");
        ## FIXME: missing parameters must be detected by the command itself
        $self->__check_command_param ({
            PARAMS       => $arg_ref,
            PARAM_PATH   => [ $param ],
            COMMAND      => $command,
            COMMAND_PATH => [ $param ],
        });
    }

    return $instance_of{$ident}->command($arg_ref);
}

sub __check_command_param : PRIVATE {
    ##! 2: 'start'
    my $self = shift;
    my $arg_ref = shift;
    my $ident = ident $self;

    if (! defined $arg_ref->{COMMAND}) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_CRYPTO_API_COMMAND_NO_COMMAND_SPECIFIED',
            );
    }

    ## we need a hash ref with path to actual hash ref
    ## we need the command and the actual parameter path

    my $params = $arg_ref->{PARAMS};
    foreach my $key (@{$arg_ref->{PARAM_PATH}}) {
        if (exists($params->{$key})) {
            $params = $params->{$key};
        }
        else {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_API_CHECK_COMMAND_PARAM_PARAM_PATH_MISMATCH',
                params  =>  {
                    PARAM      => $arg_ref->{PARAMS},
                    PARAM_PATH => join(', ', @{$arg_ref->{PARAM_PATH}}),
                },
            );
        }
    }

    my $command_params = $self->get_command_params();
    if (! defined $command_params || ref $command_params ne 'HASH') {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_CRYPTO_API_COMMAND_NO_COMMAND_PARAMS',
            );
    }

    my $cmd = $command_params->{$arg_ref->{COMMAND}};
    ##! 16: 'cmd: ' . $cmd
    foreach my $key (@{$arg_ref->{COMMAND_PATH}})
    {
        ## check if the used parameter is legal (parameter => 0)
        if (not exists $cmd->{$key}) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_API_COMMAND_ILLEGAL_PARAM',
                params  => { COMMAND      => $arg_ref->{COMMAND},
                             COMMAND_PATH => join (', ', @{$arg_ref->{COMMAND_PATH}})
                           },
            );
        }
        $cmd = $cmd->{$key};
    }

    ## this is only a check for the existence
    if (ref $cmd eq '') {
        return 1;
    }

    ## if we have an array which we can check then do it
    if (ref $cmd eq 'ARRAY') {
        if (not grep (/^$params$/, @{$cmd})) {
            OpenXPKI::Exception->throw (
                message => 'I18N_OPENXPKI_CRYPTO_BACKEND_API_COMMAND_ILLEGAL_VALUE',
                params  => {COMMAND => $arg_ref->{COMMAND},
                            PARAM   => join (', ', @{$arg_ref->{PARAM_PATH}}),
                            VALUE   => $params});
        } else {
            return 1;
        }
    }

    ## if we have a hash here then there is substructure in the config
    if (ref $cmd    and ref $cmd    eq 'HASH' and
        ref $params and ref $params eq 'HASH') {
        my $next = undef;

        ## first try to identify the correct hash
        foreach my $key (keys %{$cmd}) {
            my $name = $key;
               $name =~ s/:.*$//;
            my $value = $key;
               $value =~ s/^[^\:]*://;
            my @path = @{$arg_ref->{PARAM_PATH}};
            pop @path;
            push @path, $name;
            my $root = $arg_ref->{PARAMS};
            foreach my $elem (@path) {
                if (exists $root->{$elem}) {
                    $root = $root->{$elem};
                }
            }
            if ($root eq $value) {
                $next = $key;
                last;
            }
        }

        ## use the default if present and nothing else is found
        if (not defined $next and exists $cmd->{''}) {
            $next = '';
        }
        if (not defined $next and exists $cmd->{':'}) {
            $next = ':';
        }

        ## restart the check
        foreach my $key (keys %{$params}) {
            $self->__check_command_param ({
                PARAMS       => $arg_ref->{PARAMS},
                PARAM_PATH   => [ @{$arg_ref->{PARAM_PATH}}, $key ],
                COMMAND      => $arg_ref->{COMMAND},
                COMMAND_PATH => [ @{$arg_ref->{COMMAND_PATH}}, $next, $key ],
            });
        }

        ## anything looks ok
        return 1;
    }

    ## no more checks to perform and no error detected
    ## nevertheless there is a wrong config
    OpenXPKI::Exception->throw (
        message => 'I18N_OPENXPKI_CRYPTO_BACKEND_API_COMMAND_WRONG_CONFIG',
        params  => {COMMAND => $arg_ref->{COMMAND}});
}


sub login
{
    my $self  = shift;
    my $ident = ident $self;

    if (@_)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_LOGIN_ILLEGAL_PARAM");
    }
    $self->get_instance()->login();
}

sub logout
{
    my $self = shift;
    my $ident = ident $self;

    if (@_)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_LOGOUT_ILLEGAL_PARAM");
    }
    $self->get_instance()->logout();
}

sub online
{
    my $self = shift;
    my $ident = ident $self;

    if (@_)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_ONLINE_ILLEGAL_PARAM");
    }
    $self->get_instance()->online();
}

sub key_usable
{
    my $self = shift;
    my $ident = ident $self;

    if (@_)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_KEY_USABLE_ILLEGAL_PARAM");
    }
    $self->get_instance()->key_usable();
}

sub get_certfile
{
    my $self = shift;
    my $ident = ident $self;

    if (@_)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_CERTFILE_ILLEGAL_PARAM");
    }
    $self->get_instance()->get_certfile();
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::API - API for cryptographic functions - abstract superclass.

=head1 Description   

This is the ABSTRACT superclass for crypto APIs, such as
OpenXPKI::Crypto::Backend::API, OpenXPKI::Crypto::Tool::SCEP::API, ...
As an abstract superclass, it just implements basic command validation,
more functionality has to be implemented in the specific subclasses.
Note that it can not be instantiated.

=head1 Functions
     
=head2 START
 
This constructor (see Class::Std) tries to create an instance of the class
passed by the named parameter 'CLASS'. This is supposed to be the corresponding
Backend or Tool class, e.g. OpenXPKI::Backend::OpenSSL

=head2 command

This checks whether valid command parameters are present and then excutes a
command on the instance mentioned above.

=head2 __init_command_params

This method is empty here, it has to be implemented by the the
corresponding API sub-classes. It fills the command_params hash
with the appropriate content, i.e. allowed functions and their
parameters.

=head2 __check_command_param

This private method checks the validity of the command parameters. It only
checks keys, not values, i.e. the content of a passed parameter might still
be inapropriate for the requested operation.


=head1 See also:

OpenXPKI::Crypto::Backend::API - API for generic crypto backends
OpenXPKI::Tool::SCEP::API      - API for the SCEP tool

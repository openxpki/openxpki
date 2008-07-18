## OpenXPKI::Crypto::Backend::OpenSSL
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Backend::OpenSSL;
use base qw( OpenXPKI::Crypto::Toolkit );
	
use strict;
use warnings;
use English;

use OpenXPKI::Crypto::Backend::OpenSSL::Config;
use OpenXPKI::Crypto::Backend::OpenSSL::XS;
use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Debug;
use OpenXPKI::Exception;

my %xs_of     :ATTR; # the XS object
my %config_of :ATTR; # the Config object

use Data::Dumper;

sub START {
    ##! 16: 'OpenSSL start'
}

sub __init_local {
    my $self = shift;
    my $ident = ident $self;
    
    $xs_of{$ident} = OpenXPKI::Crypto::Backend::OpenSSL::XS->new();
    $self->__init_config ();
}

sub __init_config {
    my $self = shift;
    my $ident = ident $self;
    
    $config_of{$ident} = OpenXPKI::Crypto::Backend::OpenSSL::Config->new({
                          TMP => $self->get_tmp_dir(),
                          XS  => $xs_of{$ident},
                      });
}

sub __instantiate_engine {
    ##! 16: 'start'
    my $self = shift;
    my $ident = ident $self;

    my $engine = shift;

    ##! 16: "engine: $engine"

    my $engine_obj = eval {
        $engine->new(
            %{$self->get_params()},
            XS => $xs_of{$ident},
        )
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        OpenXPKI::Exception->throw (
            message  => "I18N_OPENXPKI_BACKEND_OPENSSL_INIT_ENGINE_NEW_FAILED",
            children => [ $exc ]);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    }
    $self->set_engine($engine_obj);
    $config_of{$ident}->set_engine($engine_obj);
    ##! 16: 'end'
}

sub __instantiate_cli {
    ##! 16: 'start'
    my $self = shift;
    my $ident = ident $self;
    my $cli_class = shift;
    my $cli_obj;
    
    eval {
        $cli_obj = $cli_class->new({
                               ENGINE => $self->get_engine(),
                               SHELL  => $self->get_shell(),
                               TMP    => $self->get_tmp_dir(),
                               CONFIG => $config_of{$ident},
                            });
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
        OpenXPKI::Exception->throw(
            message  => 'I18N_OPENXPKI_BACKEND_OPENSSL_INSTANTIATE_CLI_FAILED',
            children => [ $exc ]);
    } elsif ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_BACKEND_OPENSSL_EVAL_ERROR',
            params => {
                'EVAL_ERROR' => $EVAL_ERROR,
            },
        );
    }
    $self->set_cli($cli_obj);
    ##! 16: 'end'
}

sub __init_command {
    ##! 16: 'start'
    my $self = shift;
    my $ident = ident $self;

    foreach my $key (["TMP", "TMP"], ["RANDFILE", "RANDOM_FILE"]) {
        if (not exists $self->get_params()->{$key->[0]}) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TOOLKIT_MISSING_COMMAND_PARAM",
                params  => {"PARAM" => $key->[0]});
        }
        $self->get_command_params()->{$key->[1]} = $self->get_params()->{$key->[0]};
    }

    $self->get_command_params()->{ENGINE} = $self->get_engine();
    $self->get_command_params()->{CONFIG} = $config_of{$ident};
    $self->get_command_params()->{XS}     = $xs_of{$ident};
    ##! 16: 'end'
}

sub __prepare_cli {
    my $self = shift;
    my $ident = ident $self;
    my $cmds = shift;
    
    $self->get_cli()->prepare({
        COMMAND => $cmds,
        CONFIG  => $config_of{$ident},
    });
}


###########################
##     BEGIN XS code     ##
###########################

sub get_object
{
    ##! 1: "start"
    my $self  = shift;
    my $ident = ident $self;
    return $xs_of{$ident}->get_object(@_);
}

sub get_object_function
{
    ##! 1: "start"
    my $self  = shift;
    my $ident = ident $self;
    return $xs_of{$ident}->get_object_function(@_);
}

sub free_object
{
    ##! 1: "start"
    my $self  = shift;
    my $ident = ident $self;
    return $xs_of{$ident}->free_object(@_);
}

#########################
##     END XS code     ##
#########################


1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL - OpenSSL cryptographic backend

=head1 Description

This is the basic class to provide OpenXPKI with an OpenSSL based
cryptographic token. Beside the documented function all functions
in the class OpenXPKI::Crypto::Backend::OpenSSL::Engine are
available here too because we map these engine specific functions
directly to the engine (via AUTOLOAD).

=head1 Functions

=head2 new

is the constructor. It requires five basic parameters which are
described here. The other parameters are engine specific and
are described in the related engine documentation. Please see
OpenXPKI::Crypto::Backend::OpenSSL::Engine for more details.

=over

=item * RANDFILE (file to store the random informations)

=item * SHELL (the OpenSSL binary)

=item * TMP (the used temporary directory which must be private)

=back

=head2 command

execute an OpenSSL command. You must specify the name of the command
as first parameter followed by a hash with parameter. Example:

  $token->command ({COMMAND => "create_key", TYPE => "RSA", ...});

=head1 XS functions

We support some library functions via our XS module. Please see
our XS module for more informations.

=over

=item * get_object

=item * get_object_function

=item * free_object

=back

=head1 Engine functions

The OpenSSL engines which are supported provide some functions to
get more detailed infos about the used security token. Please see
our engine module for more informations.

=over

=item * online

=item * key_usable

=item * login

=item * logout

=item * get_certfile

=item * get_chainfile

=back

=head1 See Also

OpenXPKI::Crypto::Backend::OpenSSL::XS and OpenXPKI::Crypto::Backend::OpenSSL::Engine

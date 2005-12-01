## OpenXPKI::Server.pm 
##
## Written by Michael Bell for the OpenXPKI project 2005
## Copyright (C) 2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::Server;
use base qw(Net::Server::Fork);

## used modules

use English;
use OpenXPKI qw(debug);
use OpenXPKI::Exception;
use OpenXPKI::Server::Init;
use OpenXPKI::Server::API;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {DEBUG => 0};

    bless $self, $class;

    my $keys = { @_ };

    ## get parameters

    $self->{"DEBUG"}          = $keys->{DEBUG};
    $self->{"CONFIG"}         = $keys->{CONFIG};

    ## dump out startup configuration

    foreach my $key (keys %{$keys})
    {
        if ($key ne "CONFIG" and $key ne "DEBUG")
        {
            $self->debug ("IGNORED:  $key ::= $keys->{$key}");
        } else {
            $self->debug ("ACCEPTED: $key ::= $keys->{$key}");
        }
    }

    ## initialization

    my $init = OpenXPKI::Server::Init->new (DEBUG => $self->{DEBUG});
    $self->{xml_config}   = $init->get_xml_config   (CONFIG => $self->{"CONFIG"});
    $init->init_i18n       (CONFIG => $self->{xml_config});
    $init->redirect_stderr (CONFIG => $self->{xml_config});
    $self->{crypto_layer} = $init->get_crypto_layer (CONFIG => $self->{xml_config});
    $self->{pki_realm}    = $init->get_pki_realms   (CONFIG => $self->{xml_config},
                                                     CRYPTO => $self->{crypto_layer});
    $self->{log}          = $init->get_log (CONFIG => $self->{xml_config});
    $self->{db}           = $init->get_dbi (CONFIG => $self->{xml_config},
                                            LOG    => $self->{log});

    ## all is ready now so make the API available

    $self->{"api"} = OpenXPKI::Server::API->new (DEBUG  => $self->{DEBUG},
                                                 SERVER => $self);

    ## group access is allowed

    $self->{umask} = umask 0007;

    ## load the user interfaces

    $self->{ui_list} = $init->get_user_interfaces (
                           CONFIG => $self->{xml_config},
                           API    => $self->{api});

    ## start the server

    my %params = $init->get_server_config (CONFIG => $self->{xml_config});
    unlink ($params{port});
    $self->run (%params);
}

sub process_request
{
    my $self = shift;

    ## recover from umask of Net::Server->run
    umask $self->{umask};

    my $line = readline (*STDIN);

    ## initialize user interface module

    my $class = $line;
    $class =~ s/^.* //s; ## filter something like START etc.
    $class =~ s/\n$//s;
    if (not $self->{ui_list}->{$class})
    {
        print STDOUT "OpenXPKI::Server: $class unsupported.\n";
        $self->{log}->log (MESSAGE  => "$class unsupported.",
                           PRIORITY => "fatal",
                           FACILITY => "system");
        return undef;
    }
    $self->{ui} = $self->{ui_list}->{$class};

    ## update pre-initialized variables

    eval { $self->{db}->connect() };
    if ($EVAL_ERROR)
    {
        print STDOUT $EVAL_ERROR->message();
        $self->{log}->log (MESSAGE  => "Database connection failed. ".
                                       $EVAL_ERROR->message(),
                           PRIORITY => "fatal",
                           FACILITY => "system");
        return undef;
        
    }

    ## use user interface

    $self->{ui}->init();
    $self->{ui}->run();
}

################################################
##                 WARNING                    ##
################################################
##                                            ##
## Before you change the code please read the ##
## following explanation and be sure that you ##
## understand it.                             ##
##                                            ##
## The basic design idea is that if there is  ##
## an error then it must be impossible that a ##
## deeper layer can be reached. This will be  ##
## guaranteed by the following rules:         ##
##                                            ##
## 1. Never use eval to handle thrown         ##
##    exceptions.                             ##
##                                            ##
## 2. If you use eval to catch an exception   ##
##    then the eval block must include all    ##
##    lower layers.                           ##
##                                            ##
## The result is that if a layer throws an    ##
## exception then it is impossible that a     ##
## lower is reached.                          ##
##                                            ##
################################################

sub command
{
}

1;
__END__

=head1 Description

This is the main server class of OpenXPKI. If you want to start an
OpenXPKI server then you must instantiate this class. Please always
remember that an instantiation of this module is a startup of a
trustcenter.

=head1 Functions

=head2 new

starts the server. It needs some parameters to configure the server
but if they are correct then an exec will be performed. The parameters
are the following ones:

=over

=item * DAEMON_USER

=item * DAEMON_GROUP

=item * CONFIG

=item * DEBUG

=back

All parameters are required, except of the DEBUG parameter.

=head2 process_request

is the function which is called by Net::Server to make the
work. The only parameter is the class instance. The
communication is handled via STDIN and STDOUT.

The class selects the user interfaces and checks the
pre-initialized variables. If all of this is fine then
the user interface will be initialized and started.

=head2 command

is normal layer stack where the user interfaces can execute
commands.

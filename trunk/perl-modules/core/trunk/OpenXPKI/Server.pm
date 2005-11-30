## OpenXPKI::Server.pm 
##
## Written by Michael Bell for the OpenCA project 2005
## Migrated to the OpenXPKI Project 2005
## Copyright transfered from Michael Bell to The OpenXPKI Project in 2005
## Copyright (C) 2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::Server;
use base qw(Net::Server::Fork);

## used modules

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

    ## start the server

    my %params = $init->get_server_config (CONFIG => $self->{xml_config});
    unlink ($params{port});
    $self->run (%params);
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

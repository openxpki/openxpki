## OpenXPKI::Server::ACL.pm
##
## Written by Michael Bell 2006
## cleaned up a bit to support multiple PKI realms
## by Alexander Klink 2007
## Copyright (C) 2006 by The OpenXPKI Project

package OpenXPKI::Server::ACL;

use strict;
use warnings;
use utf8;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Data::Dumper;

## constructor and destructor stuff

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = shift;
    ##! 1: "start"

    return undef if (not $self->__load_config ($keys));

    ##! 1: "end"
    return $self;
}

########################################################################
##                          identify the user                         ##
########################################################################

# Moved to Workflow::Factory
sub authorize_workflow {
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_HAS_MOVED',
    );
}


#FIXME - ACL - needs concept and implementation
sub authorize
{
    my $self = shift;
    my $keys = shift;

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_NOT_IMPLEMENTED',
    );
    return 1;
}

sub get_roles
{
    my $self  = shift;
    return CTX('config')->get_keys('auth.roles');
}

sub get_servers
{
    #FIXME - ACL - new to find a new place for server definitons
    my $self  = shift;
    return $self->{SERVER};
}

1;
__END__

=head1 Name

OpenXPKI::Server::ACL

=head1 Description

The ACL module implements the authorization for the OpenXPKI core system.

=head1 Functions

=head2 new

is the constructor of the module.
The constructor loads all ACLs of all PKI realms. Every PKI realm must include
an ACL section in its configuration. This configuration includes a definition
of all servers, all supported roles and all permissions.

=head2 authorize

is the function which grant the right to execute an activity. The function
needs two parameters ACTIVITY and AFFECTED_ROLE. The activity is the activity
which is performed by the workflow engine. The affected role is the role of
the object which is handled by the activity. If you create a request for
a certificate with the role "RA Operator" then the affected role is
"RA Operator".

The other needed parameters will be automatically determined via the active
session. It is not necessary to specify a PKI realm or the role of the logged
in user.

If the access is granted then function returns a true value. If the access
is denied then an exception is thrown.

=head2 get_roles

returns all available roles for the actual PKI realm.

=head2 get_servers

returns a hashref that lists all servers by PKI realm

## OpenXPKI::Workflow::Factory
##
## Written 2007 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project
package OpenXPKI::Workflow::Factory;

use strict;
use warnings;

use base qw( Workflow::Factory );
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

sub instance {
    my $class = ref $_[0] || $_[0];
    return bless( {} => $class );
}

sub fetch_workflow {
    my $self = shift;
    my $wf = $self->SUPER::fetch_workflow(@_);
    # the following both checks whether the user is allowed to
    # read the workflow at all and deletes context entries from $wf if
    # the configuration mandates it
    CTX('acl')->authorize_workflow({
        ACTION   => 'read',
        WORKFLOW => $wf,
        FILTER   => 1,
    });

    return $wf;
}

sub fetch_unfiltered_workflow {
    my $self = shift;
    my $wf = $self->SUPER::fetch_workflow(@_);
    CTX('acl')->authorize_workflow({
        ACTION   => 'read',
        WORKFLOW => $wf,
        FILTER   => 0,
    });
    CTX('log')->log(
        MESSAGE  => 'Unfiltered access to workflow ' . $wf->id . ' by ' . CTX('session')->get_user() . ' with role ' . CTX('session')->get_role(),
        PRIORITY => 'info',
        FACILITY => 'audit',
    );

    return $wf;
}

1;
__END__

=head1 Name

OpenXPKI::Workflow::Factory - OpenXPKI specific workflow factory

=head1 Description

This is the OpenXPKI specific subclass of Workflow::Factory.
We need an OpenXPKI specific subclass because Workflow currently
enforces that a Factory is a singleton. In OpenXPKI, we want to have
several factory objects (one for each version and each PKI realm).
The most important difference between Workflow::Factory and
OpenXPKI::Workflow::Factory is in the instance() class method, which
creates only one global instance in the original and a new one for
each call in the OpenXPKI version.

In addition, the fetch_workflow() method has been modified to do ACL
checks before returning the workflow to the caller. Typically, it also
'censors' the workflow context by removing certain workflow context
entries. Unfiltered access is possible via fetch_unfiltered_workflow()
- please note that this is sort of an ACL circumvention and should only
be used if really necessary (and should only be used to create a temporary
object that is used to retrieve the relevant entries).

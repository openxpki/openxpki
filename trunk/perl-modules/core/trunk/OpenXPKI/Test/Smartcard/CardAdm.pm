# OpenXPKI::Test::Smartcard::CardAdmin
#
# Written 2012 by Scott Hardin for the OpenXPKI project
#
# The Smartcard Admin workflow is used to manage the details of a card
# as stored in LDAP. The following actions are supported
#
# modify_user   Create, modify or delete the association of a user to a card
# modify_status Modify the status of the card
# fail_workflow Set the state of a workflow to FAILURE
#
# Note: this workflow assumes that a card may belong to no more than 1
# individual.
#
# IMPORTANT:
# Set the environment variable DESTRUCTIVE_TESTS to a true value to
# have the LDAP data purged and loaded from the LDIF file.

use strict;
use warnings;

use lib qw(     /usr/local/lib/perl5/site_perl/5.8.8/x86_64-linux-thread-multi
    /usr/local/lib/perl5/site_perl/5.8.8
    /usr/local/lib/perl5/site_perl
    ../../lib
);

package OpenXPKI::Test::Smartcard::CardAdm;

use Carp;
use English;
use Data::Dumper;
use Moose;

extends 'OpenXPKI::Test::More';

sub wftype { return 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_CARDADM' }

my ( $msg, $wf_id, $client );

###################################################
# These routines represent individual tasks
# done by a user. If there is an error in a single
# step, undef is returned. The reason is in $@ and
# on success, $@ contains Dumper($msg) if $msg is
# not normally returned.
#
# Each routine takes care of login and logout.
###################################################

# fetch_card_info
#
# usage: $t->fetch_card_info( USER, PASS, NAMED-PARAMS );
#
# where USER is the admin user executing the workflow.
#
# The additional parameters are passed in named-parameter format, where
# the following keys are supported:
#
# owner     Search LDAP using email
# token_id  Search LDAP using token_id
# end_state Workflow state expected after executing (default is 'MAIN')
#
sub fetch_card_info {
    my $self   = shift;
    my $user   = shift;
    my $pass   = shift;
    my %params = @_;

    $@ = 'No errors';

    my $end_state = 'MAIN';

    # skim the end_state parameter from the list since it is not intended
    # for the workflow itself, but for this helper routine. Yes, I know
    # I should probably pass the params in an anon has and have a second
    # param for something like this.
    if ( defined $params{'end_state'} ) {
        $end_state = $params{'end_state'};
        delete $params{'end_state'};

        #            $self->diag("DEBUG: setting end_state to '$end_state'");
    }

    #    warn "# connecting as $u/$p\n";
    my ( $id, $msg );

   #    $self->diag("fetch_card_info() disconnecting previous connection...");
    $self->disconnect();

    #    $self->diag("fetch_card_info() connecting as $user/$pass...");
    if ( not $self->connect( user => $user, password => $pass ) ) {
        $@ = "Error connecting as '$user': $@";
        return;
    }

    #    $self->diag("fetch_card_info() creating workflow instance...");
    if ( not $self->create( $self->wftype, {%params} ) ) {
        $@ = "Error creating workflow instance: " . $@;

#            $self->diag( "Error creating workflow in fetch_card_info(): params=", join( ', ', %params ) );
        return;
    }

    if ( not $self->state eq $end_state ) {
        $@
            = "Error - new workflow in wrong state: "
            . $self->state
            . " (expected $end_state)";
        return;
    }

    return $self;
}

sub fetch_card_info_ok {
    my $self     = shift;
    my $params   = shift || [];
    my $testname = shift || 'fetch card info';

    my $result = $self->fetch_card_info( @{$params} );
    return $self->ok( $result, $testname );
}

sub fetch_card_info_nok {
    my $self     = shift;
    my $params   = shift || [];
    my $testname = shift || 'fetch card info';

    my $result = $self->fetch_card_info( @{$params} );
    return $self->ok( ( not $result ), $testname );
}

# puk_upload
#
# usage: $t->puk_upload( USER, PASS, TOKEN, PUK );
#
# where USER is the admin user executing the workflow.
#
# The additional parameters are passed in named-parameter format, where
# the following keys are supported:
#
# token_id  token id
# _puk     puk for given token
#
sub puk_upload {
    my $self  = shift;
    my $user  = shift;
    my $pass  = shift;
    my $token = shift;
    my $puk   = shift;

    $@ = 'No errors';

    #    warn "# connecting as $u/$p\n";
    my ( $id, $msg );

    if ( not $self->connect( user => $user, password => $pass ) ) {
        $@ = "Error connecting as '$user': $@";
        return;
    }

    if (not $self->create(
            'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PUK_UPLOAD',
            { token_id => $token, _puk => $puk }
        )
        )
    {
        $@ = "Error creating workflow instance: " . $@;
        return;
    }

    return $self;
}

sub validate_card_info {
    my ( $self, $ref ) = @_;

    foreach my $key (qw( smartcard_status ldap_workflow_creator )) {
        if ( $self->param($key) ne $ref->{$key} ) {
            $@
                = "Error - wrong val for context param '" 
                . $key . ": "
                . 'expected: '
                . $ref->{$key}
                . ', got: ', $self->param($key);
            return;
        }
    }
    return $self;
}

# modify_user
#
# usage: $t->modify_user( USER, PASS, TOKENID, NEW_USER [, WFPARAMS ] );
#
# where USER is the admin user executing the workflow.
# If NEW_USER is undefined, the current association
# is deleted.
#
# WFPARAMS is a list of named-parameters passed to the execute
#
sub modify_user {
    my ( $self, $u, $p, $t, $nu, @params ) = @_;
    my ( $id, $msg );

    if ( not $self->fetch_card_info( $u, $p, token_id => $t ) ) {
        return;
    }

    if (not $self->execute(
            'scadm_modify_user', { token_id => $t, new_user => $nu, @params }
        )
        )
    {
        $@ = "Error executing 'scadm_modify_user': " . $@;
        return;
    }

    if ( not $self->state eq 'SUCCESS' ) {
        $@ = "Error - workflow in wrong state: " . $self->state;
        return;
    }

    return $self;

}

# modify_status
#
# usage: $t->modify_status( USER, PASS, TOKENID, NEW_STATUS );
#
# where USER is the admin user executing the workflow.
#
sub modify_status {
    my ( $self, $u, $p, $t, $ns ) = @_;

    #    $self->diag("u=$u, p=$p, t=$t, ns=$ns");
    my ( $id, $msg );

    #    $self->diag("Fetching card info...");
    if ( not $self->fetch_card_info( $u, $p, token_id => $t ) ) {
        return;
    }

    #    $self->diag("Executing scadm_modify_status...");
    if (not $self->execute(
            'scadm_modify_status', { token_id => $t, new_status => $ns }
        )
        )
    {
        $@ = "Error executing 'scadm_modify_status': " . $@;
        return;
    }

    #    $self->diag("Checking that state is 'SUCCESS'");
    if ( not $self->state eq 'SUCCESS' ) {
        $@ = "Error - workflow in wrong state: " . $self->state;
        return;
    }

    return $self;

}

# kill_workflow
#
# usage: $t->kill_workflow( USER, PASS, WFID );
#
# Note: this is done on an existing CARDADM workflow
# Note 2: WFID may be a comma-separated list, too.
sub kill_workflow {
    my ( $self, $u, $p, $id ) = @_;

    #        $self->diag("kill_workflow() id=$id");

    if (not $self->execute( 'scadm_kill_workflow', { target_wf_id => $id } ) )
    {
        $@ = "Error executing 'scadm_kill_workflow': " . $@;
        return;
    }

    if ( not $self->state eq 'SUCCESS' ) {
        $@ = "Error - workflow in wrong state: " . $self->state;
        return;
    }

    return $self;
}

# get_unblock_response
#
# usage: $t->get_unblock_response( USER, PASS, TOKEN, CHALLENGE )
sub get_unblock_response {
    my ( $self, $u, $p, $token, $chall ) = @_;

    if ( not $self->fetch_card_info( $u, $p, token_id => $token ) ) {
        return;
    }

    if (not $self->execute(
            'scadm_get_unblock_response',
            { token_id => $token, unblock_challenge => $chall }
        )
        )
    {
        $@ = "Error executing 'scadm_get_unblock_response': " . $@;
        return;
    }

    if ( not $self->state eq 'SUCCESS' ) {
        $@ = "Error - workflow in wrong state: " . $self->state;
        return;
    }

    return $self;
}

sub get_unblock_response_ok {
    my $self     = shift;
    my $params   = shift || [];
    my $testname = shift || 'get unblock response';

    my $result = $self->get_unblock_response( @{$params} );
    return $self->ok( $result, $testname );
}

# user_abort - a graceful way of saying "Thanks, but no thanks!"
#
sub user_abort {
    my ($self) = @_;

    if ( not $self->execute( 'scadm_user_abort', ) ) {
        $@ = "Error executing 'scadm_user_abort': " . $@;
        return;
    }

    if ( not $self->state eq 'FAILURE' ) {
        $@ = "Error - workflow in wrong state: " . $self->state;
        return;
    }

    return $self;
}

sub user_abort_ok {
    my $self     = shift;
    my $params   = shift || [];
    my $testname = shift || 'user abort';

    my $result = $self->user_abort( @{$params} );
    return $self->ok( $result, $testname );
}

1;

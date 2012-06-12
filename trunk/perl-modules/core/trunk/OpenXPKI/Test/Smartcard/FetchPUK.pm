# OpenXPKI::Test::Smartcard::FetchPUK
#
# Written 2012 by Scott Hardin for the OpenXPKI project
#
# The Smartcard Fetch PUK workflow is used to get the PUK of a card.
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

package OpenXPKI::Test::Smartcard::FetchPUK;

use Carp;
use English;
use Data::Dumper;
use Moose;

extends 'OpenXPKI::Test::More';

sub wftype { return 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_FETCH_PUK' }

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

# fetch_puk takes user, pass and a named-parameter list
# containing the token_id
sub fetch_puk {
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

#    $self->diag("fetch_puk() entered - user=$user, pass=$pass, token_id=" . $params{token_id});

    if ( not $self->initialize_workflow( $user, $pass, token_id => $params{token_id} ) ) {
        $@ = "Error creating Fetch PUK workflow: $@";
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

# $obj->fetch_puk_ok( [ PARAMS ], TESTNAME );
sub fetch_puk_ok {
    my $self     = shift;
    my $params   = shift || [];
    my $testname = shift || 'fetch puk';

#    $self->diag("fetch_puk_ok(): params=", join(', ', @{ $params } ));
    my $result = $self->fetch_puk( @{$params} );
    return $self->ok( $result, $testname );
}

sub nack_fetch_puk {
    my $self = shift;
    my %params = @_;

    my $end_state = 'FAILURE';
    my $error_reason = $params{error_reason} || 'aborted by test routine';

    # skim the end_state parameter from the list since it is not intended
    # for the workflow itself, but for this helper routine. Yes, I know
    # I should probably pass the params in an anon has and have a second
    # param for something like this.
    if ( defined $params{'end_state'} ) {
        $end_state = $params{'end_state'};
        delete $params{'end_state'};

        #            $self->diag("DEBUG: setting end_state to '$end_state'");
    }

    if ( not $self->execute( 'scfp_puk_fetch_err', { error_reason => $error_reason } ) ) {
        $@ = "ACK Fetch PUK failed: $@";
        return;
    }

    if ( not $self->state eq $end_state ) {
        $@
            = "Error - workflow in wrong state after exec: "
            . $self->state
            . " (expected $end_state)";
        return;
    }

    return $self;
}

sub ack_fetch_puk {
    my $self = shift;
    my %params = @_;

    my $end_state = 'SUCCESS';

    # skim the end_state parameter from the list since it is not intended
    # for the workflow itself, but for this helper routine. Yes, I know
    # I should probably pass the params in an anon has and have a second
    # param for something like this.
    if ( defined $params{'end_state'} ) {
        $end_state = $params{'end_state'};
        delete $params{'end_state'};

        #            $self->diag("DEBUG: setting end_state to '$end_state'");
    }

    if ( not $self->execute( 'scfp_ack_fetch_puk' ) ) {
        $@ = "ACK Fetch PUK failed: $@";
        return;
    }

    if ( not $self->state eq $end_state ) {
        $@
            = "Error - workflow in wrong state after exec: "
            . $self->state
            . " (expected $end_state)";
        return;
    }

    return $self;
}

# $obj->ack_fetch_puk_ok( [ PARAMS ], TESTNAME );
sub ack_fetch_puk_ok {
    my $self     = shift;
    my $params   = shift || [];
    my $testname = shift || 'ack fetch puk';

    my $result = $self->ack_fetch_puk( @{$params} );
    return $self->ok( $result, $testname );
}


# $obj->nack_fetch_puk_ok( [ PARAMS ], TESTNAME );
sub nack_fetch_puk_ok {
    my $self     = shift;
    my $params   = shift || [];
    my $testname = shift || 'nack fetch puk';

    my $result = $self->nack_fetch_puk( @{$params} );
    return $self->ok( $result, $testname );
}

1;

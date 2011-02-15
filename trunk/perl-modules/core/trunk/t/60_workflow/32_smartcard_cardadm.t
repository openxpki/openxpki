#!perl
#
# 32_smartcard_cardadm.t - tests for cardadm workflow
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

use strict;
use warnings;
use Carp;
use English;
use Data::Dumper;

package OpenXPKI::Tests::More::SmartcardCardadm;
use base qw( OpenXPKI::Tests::More );
sub wftype { return 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_CARDADM' }

#my $pidfile     = $instancedir . '/var/openxpki/openxpki.pid';

my $wf_type = 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_CARDADM';
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
#
sub fetch_card_info {
    my $self   = shift;
    my $user   = shift;
    my $pass   = shift;
    my %params = @_;

    $@ = 'No errors';

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
        $self->diag("params=", join(', ', %params));
        return;
    }

    if ( not $self->state eq 'MAIN' ) {
        $@
            = "Error - new workflow in wrong state: "
            . $self->state
            . " (expected MAIN)";
        return;
    }

    return $self;
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
    my $self   = shift;
    my $user   = shift;
    my $pass   = shift;
    my $token = shift;
    my $puk = shift;

    $@ = 'No errors';

    #    warn "# connecting as $u/$p\n";
    my ( $id, $msg );

    if ( not $self->connect( user => $user, password => $pass ) ) {
        $@ = "Error connecting as '$user': $@";
        return;
    }

    if (not $self->create( 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PUK_UPLOAD', { token_id => $token, _puk => $puk }  ) ) {
        $@ = "Error creating workflow instance: " . $@;
        return;
    }

    return $self;
}

# 


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
    $self->diag("kill_workflow() id=$id");

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

package main;

our $debug = 0;
my $sleep = 0;                # set to '1' to cause pause between transactions
my $realm = 'User TEST CA';

# reuse the already deployed server
my $socketfile = '/var/openxpki/openxpki.socket';

my $tok_id;

my %test_data = (
    selfserve => {
        name => 'selfserve',
        role => 'User',
    },
    user => {
        name  => 'CHANGEME@CHANGEME',
        role  => 'User',
        token => 'gem2_CHANGEME',
    },
    ra1 => {
        name => 'CHANGEME1@CHANGEME',
        role => 'RA Operator',
    },
    ra2 => {
        name => 'CHANGEME2@CHANGEME',
        role => 'RA Operator',
    },
);

# to simplify git merges, set values for test cases here instead
# of in the data structure above
$test_data{user}->{name}   = 'user002@local';
$test_data{user}->{token}  = 'gem2_002';
$test_data{user}->{status} = 'initial';
$test_data{user}->{id}     = 'user002 Miller';

$test_data{ra1}->{name} = 'ra1';
$test_data{ra2}->{name} = 'ra2';

$test_data{'token-ok-1'}->{token}                 = 'gem2_002';
$test_data{'token-ok-1'}->{ldap_workflow_creator} = 'user002@local';
$test_data{'token-ok-1'}->{smartcard_status}      = 'initial';

$test_data{'token-nok-multiuser'}->{token}                 = 'gem2_003';
$test_data{'token-nok-multiuser'}->{ldap_cn}               = 'user003 Miller';
$test_data{'token-nok-multiuser'}->{ldap_workflow_creator} = 'user003@local';
$test_data{'token-nok-multiuser'}->{smartcard_status}      = 'initial';

$test_data{'token-nok-nouser'}->{token}                 = 'gem2_007';
$test_data{'token-nok-nouser'}->{ldap_workflow_creator} = '';
$test_data{'token-nok-nouser'}->{smartcard_status}      = 'initial';

$test_data{'token-nok-noscbentry'}->{token} = 'gem2_xx_doesnt_exist';

$test_data{'token-moduser-orig'}->{token}                 = 'gem2_004';
$test_data{'token-moduser-orig'}->{ldap_cn}               = 'user004 Miller';
$test_data{'token-moduser-orig'}->{ldap_workflow_creator} = 'user004@local';
$test_data{'token-moduser-orig'}->{smartcard_status}      = 'initial';

$test_data{'token-moduser-new'}->{token}                 = 'gem2_004';
$test_data{'token-moduser-new'}->{ldap_cn}               = 'user005 Miller';
$test_data{'token-moduser-new'}->{ldap_workflow_creator} = 'user005@local';
$test_data{'token-moduser-new'}->{smartcard_status}      = 'initial';

$test_data{'token-modstat-orig'}->{token}                 = 'gem2_006';
$test_data{'token-modstat-orig'}->{ldap_cn}               = 'user006 Miller';
$test_data{'token-modstat-orig'}->{ldap_workflow_creator} = 'user006@local';
$test_data{'token-modstat-orig'}->{smartcard_status}      = 'initial';

$test_data{'token-modstat-new'}->{token}            = 'gem2_006';
$test_data{'token-modstat-new'}->{smartcard_status} = 'activated';

$test_data{'token-wf'}->{token} = 'gem2_006';
$test_data{'token-wf'}->{user}  = 'user006@local';
$test_data{'token-wf'}->{pass}  = 'User';

$test_data{'token-unblock-1'}->{token}     = 'gem2_006';
$test_data{'token-unblock-1'}->{challenge} = 'd1e079d6b3d978b8';
$test_data{'token-unblock-1'}->{response}  = '0f177853c832cf85';

$test_data{'token-unblock-2'}->{token}     = 'gem2_007';
$test_data{'token-unblock-2'}->{puk}     = '57d286063e911f12f6dfdff4f00519a0be9717841867660f';
$test_data{'token-unblock-2'}->{challenge} = '9b713f44c8447d93';
$test_data{'token-unblock-2'}->{response}  = '12c57d8c6a6f30ae';



$realm = undef;

############################################################
# START TESTS
############################################################

my $test = OpenXPKI::Tests::More::SmartcardCardadm->new(
    {   socketfile => $socketfile,
        realm      => $realm
    }
) or die "error creating new test instance: $@";

$test->plan( tests => 40 );

$test->diag('##################################################');
$test->diag('# Init tests');
$test->diag('##################################################');

############################################################
# Test Set - The Basics
############################################################

# TEST 1
$test->connect_ok(
    user     => $test_data{user}->{name},
    password => $test_data{user}->{role},
) or die "Need session to continue: $@";

############################################################
# Test Set - ACL
#
# - user may not access wf
# - RA may start wf, fetch ldap, modify user, modify status, fail
#   workflow (implicit from other tests)
############################################################

# TEST: 'User' role should not have permissions to create workflow
$test->fetch_card_info_nok(
    [   $test_data{user}->{name}, $test_data{user}->{role},
        token_id => $test_data{user}->{token}
    ],
    "Create workflow with role 'User'"
) or croak $@;
$test->disconnect();

############################################################
# Test Set - LDAP with user id
#
# x fetch entry for unique user
# x fetch entries for wildcard search
# - fetch entry for unique user ( multiple cards )
# - fetch entry for unknown user ( should return empty list )
############################################################

# TEST: fetch card for given user
$test->fetch_card_info_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        token_owner => $test_data{'token-ok-1'}->{ldap_workflow_creator}
    ],
    "Fetch card by name"
) or croak $@;

# TEST: confirm results
$test->validate_card_info_ok( [ $test_data{'token-ok-1'} ],
    "Check attrs of OK token" )
    or $test->diag($@);

# TEST: fetch card for multiple users
# (workflow fails, but there should be ldap entries in context)
$test->fetch_card_info_nok(
    [   $test_data{ra1}->{name}, $test_data{ra1}->{role},
        token_owner => "user*"
    ],
    "Fetch card by name with wildcard"
) or croak $@;

my $ldap_data = $test->param('_ldap_data');

# TEST: check that we got at least a couple of records
$test->ok( @{$ldap_data} > 3,
    "check that at least 3 ldap records were found" );

# TEST: fetch card for unknown user
# (workflow fails and there should be no ldap entries in context)
$test->fetch_card_info_nok(
    [   $test_data{ra1}->{name}, $test_data{ra1}->{role},
        token_owner => "unknown user"
    ],
    "Fetch card for unknown user"
) or croak $@;

my $ldap_data2 = $test->param('_ldap_data');

# TEST: check that we got no records
$test->ok( @{$ldap_data2} == 0,
    "ldap search for unknown user should return no records" );

############################################################
# Test Set - LDAP with token id
#
# x fetch one card with one user
# x one card with multiple users
# - one user with multiple cards (when searching by userid)
# x card with no user
# x card with no scb entry
# x validate that fields returned is as expected
############################################################

# TEST
$test->fetch_card_info_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        token_id => $test_data{'token-ok-1'}->{token}
    ],
    "Create workflow with role 'RA Operator'"
) or croak $@ . ' - ' . $test->dump;

# TEST - ensure that the record is what we expect
$test->validate_card_info_ok( [ $test_data{'token-ok-1'} ],
    "Check attrs of OK token" )
    or $test->diag($@);

# - one card with multiple users
# TEST - ensure that fetch fails with multiple users
$test->fetch_card_info_nok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        token_id => $test_data{'token-nok-multiuser'}->{token}
    ],
    "Card with multiple users",
) or croak $@;

# TEST - check that the problem actually is the number of smartcard owners
$test->error_is(
    'I18N_OPENXPKI_SERVER_API_SMARTCARD_SC_ANALYZE_SMARTCARD_LDAP_TOO_MANY_SMARTCARD_OWNERS'
);

# TEST
$test->fetch_card_info_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        token_id => $test_data{'token-nok-nouser'}->{token}
    ],
    "Card with no users",
) or croak $@;

# TEST
$test->param_isnt( 'ldap_workflow_creator', undef, 'No user found in LDAP' );

# TEST - card with no scb entry
$test->fetch_card_info_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        token_id => $test_data{'token-nok-noscbentry'}->{token}
    ],
    "Card with no scb entry",
) or croak $@;

# TEST - card with no scb entry has status 'unknown'
$test->param_is( 'smartcard_status', 'unknown',
    'token without LDAP entry has status "unknown"' );

############################################################
# Test Set - Unblock and Personalization Workflows
#
# x validate that other workflows are correctly found
# x kill other workflows
############################################################

$test->disconnect();
$test->connect(
    user     => $test_data{'token-wf'}->{user},
    password => $test_data{'token-wf'}->{pass}
) or croak "Error connecting as anonymous: $@";
$test->create(
    'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK',
    { token_id => $test_data{'token-wf'}->{token} }
) or croak $@;

# TEST - check state of unblock workflow
$test->state_is('HAVE_TOKEN_OWNER') or croak $@;
my $wfid = $test->get_wfid;
$test->diag("WFID for unblock: $wfid");

# TEST - card with workflow
$test->fetch_card_info_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        token_id => $test_data{'token-wf'}->{token}
    ],
    "Card with unblock WF",
) or croak $@;
my @wfs_found
    = grep { not $_->{'WORKFLOW.WORKFLOW_STATE'} =~ /^(SUCCESS|FAILURE)$/ }
    map { @{$_} } map { values %{$_} } ( $test->param('workflows') );
my @wf_ids = map { $_->{'WORKFLOW.WORKFLOW_SERIAL'} } @wfs_found;
$test->is( scalar @wf_ids,
    1, "Expect exactly one foreign workflow to be found" );

my $id = join( ',', @wf_ids );

# TEST - kill all workflows
$test->kill_workflow_ok(
    [ $test_data{ra1}->{name}, $test_data{ra1}->{role}, $id ],
    "Kill unblock/pers workflow " . $id )
    or $test->diag("Error killing workflow: $@");

# TEST - card with workflow
$test->fetch_card_info_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        token_id => $test_data{'token-wf'}->{token}
    ],
    "Card without unblock WF",
) or croak $@;
@wfs_found
    = grep { not $_->{'WORKFLOW.WORKFLOW_STATE'} =~ /^(SUCCESS|FAILURE)$/ }
    map { @{$_} } map { values %{$_} } ( $test->param('workflows') );
@wf_ids = map { $_->{'WORKFLOW.WORKFLOW_SERIAL'} } @wfs_found;
$test->is( scalar @wf_ids, 0, "Expect no foreign workflow to be found" );

############################################################
# Test Set - Functionality
#
# x modify user actually changes which user is assigned to card
# x modify status actually changes status of card
############################################################

# TEST
$test->modify_user_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        $test_data{'token-moduser-orig'}->{token},
        $test_data{'token-moduser-orig'}->{ldap_cn},
    ],
    "Modify user to original name"
) or croak $@;

# TEST
$test->fetch_card_info_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        token_id => $test_data{'token-moduser-orig'}->{token}
    ],
    "Check that user rec to be modified is in original state"
) or croak $@;

# TEST - ensure that the record is what we expect
$test->validate_card_info_ok( [ $test_data{'token-moduser-orig'} ],
    "Check attrs of original user" )
    or $test->diag($@);

# TEST - try assigning to unknown user
$test->fetch_card_info_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        token_id => $test_data{'token-moduser-orig'}->{token}
    ],
    "Fetch user for testing user assign"
) or croak $@;

$test->execute(
    'scadm_modify_user',
    {   token_id => $test_data{'token-moduser-orig'}->{token},
        new_user => '/dev/null'
    }
);

# TEST - check that the last execute "failed properly"
$test->error_is(
    'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_ENTRY_NOT_FOUND',
    "assign card to unknown user should fail"
) or croak $@;

# TEST
$test->modify_user_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        $test_data{'token-moduser-orig'}->{token},
        $test_data{'token-moduser-new'}->{ldap_cn},
    ],
    "Modify user to original name"
) or croak $@;

# TEST
$test->fetch_card_info_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        token_id => $test_data{'token-moduser-new'}->{token}
    ],
    "Check that user rec to be modified is in original state"
) or croak $@;

# TEST - Check that status gets modified to new status
$test->modify_status_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        $test_data{'token-modstat-orig'}->{token},
        $test_data{'token-modstat-new'}->{smartcard_status},
    ],
) or croak $@ . ' - ' . $test->dump();

# TEST - Confirm status
$test->fetch_card_info_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        token_id => $test_data{'token-modstat-new'}->{token}
    ],
    "Retrieve new card status"
) or croak $@;

# TEST
$test->param_is(
    'smartcard_status',
    $test_data{'token-modstat-new'}->{smartcard_status},
    "Confirm new token status mod"
);

# TEST - Change status back to orig
$test->modify_status_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        $test_data{'token-modstat-orig'}->{token},
        $test_data{'token-modstat-orig'}->{smartcard_status},
    ],
) or croak $@ . ' - ' . $test->dump();

# TEST - Confirm status
$test->fetch_card_info_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        token_id => $test_data{'token-modstat-orig'}->{token}
    ],
    "Retrieve new card status"
) or croak $@;

# TEST
$test->param_is(
    'smartcard_status',
    $test_data{'token-modstat-orig'}->{smartcard_status},
    "Confirm orig token status mod"
);

############################################################
# Test Set - Unblock Challenge
#
# - generate response for given card
############################################################

# TEST - Fetch cardadm workflow
$test->get_unblock_response_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        $test_data{'token-unblock-1'}->{token},
        $test_data{'token-unblock-1'}->{challenge},
    ],
    "Retrieve new card status for challenge with default puk"
) or warn $@;
$test->diag("WFID: " . $test->get_wfid());

# TEST
$test->param_is(
    'unblock_response',
    $test_data{'token-unblock-1'}->{response},
    "Confirm unblock response for default puk: " . 
        $test_data{'token-unblock-1'}->{challenge} . '/' .
    $test_data{'token-unblock-1'}->{response}
);

# TEST
$test->puk_upload_ok( 
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        $test_data{'token-unblock-2'}->{token},
        $test_data{'token-unblock-2'}->{puk},
    ],
    "Setting puk for token 2"
) or croak $@;
$test->diag("WFID: " . $test->get_wfid());

# TEST - Fetch cardadm workflow
$test->get_unblock_response_ok(
    [   $test_data{ra1}->{name},
        $test_data{ra1}->{role},
        $test_data{'token-unblock-2'}->{token},
        $test_data{'token-unblock-2'}->{challenge},
    ],
    "Retrieve new card status for challenge with other puk"
) or warn $@;
$test->diag("WFID: " . $test->get_wfid());

# TEST
$test->param_is(
    'unblock_response',
    $test_data{'token-unblock-2'}->{response},
    "Confirm unblock response for challenge with other puk"
);


use strict;
use warnings;
use Carp;
use English;
use Test::More qw(no_plan);

#plan tests => 8;

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

diag("Smartcard Unblock workflow\n");
our $debug = 0;
my $sleep = 0;    # set to '1' to cause pause between transactions

my $realm = 'User TEST CA';

# reuse the already deployed server
#my $instancedir = 't/60_workflow/test_instance';
my $instancedir = '';
my $socketfile  = $instancedir . '/var/openxpki/openxpki.socket';
my $pidfile     = $instancedir . '/var/openxpki/openxpki.pid';

my $tok_id;
my $wf_type     = 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK';
my $wf_type_puk = 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PUK_UPLOAD';
my ( $msg, $wf_id, $client );

my %act_test = (
    selfserve => {
        name => 'selfserve',
        role => 'User',
    },
    user => {
        name   => 'CHANGEME@CHANGEME',
        role   => 'User',
        newpin => '1234',
        token  => 'gem2_CHANGEME',
        puk    => 'CHANGEME',
    },
    auth1 => {
        name => 'CHANGEME@CHANGEME',
        role => 'User',
        code => '',
    },
    auth2 => {
        name => 'CHANGEME@CHANGEME',
        role => 'User',
        code => '',
    },
);

#
# $client = wfconnect( USER, PASS );
#
sub wfconnect {
    my ( $u, $p ) = @_;
    my $c = OpenXPKI::Client->new(
        {
            TIMEOUT    => 100,
            SOCKETFILE => $instancedir . '/var/openxpki/openxpki.socket',
        }
    );
    login(
        {
            CLIENT   => $c,
            USER     => $u,
            PASSWORD => $p,
        }
    ) or croak "Login as $c failed: $@";
    return $client = $c;
}

sub wfdisconnect {
    eval { $client && $client->send_receive_service_msg('LOGOUT'); };
    $client = undef;
}

#
# usage: my $msg = wfexec( ID, ACTIVITY, { PARAMS } );
#
sub wfexec {
    my ( $id, $act, $params ) = @_;
    my $msg;

    croak("Unable to exec action '$act' on closed connection")
        unless defined $client;

    $msg = $client->send_receive_command_msg(
        'execute_workflow_activity',
        {   'ID'       => $id,
            'ACTIVITY' => $act,
            'PARAMS'   => $params,
            'WORKFLOW' => $wf_type,
        },
    );
    return $msg;

}

#
# usage: my $state = wfstate( ID );
# Note: $@ contains either error message or Dumper($msg)
#
sub wfstate {
    my ($id) = @_;
    my ( $msg, $state );
    my $disc = 0;
    $@ = '';

    unless ($client) {
        $disc++;
        unless ( $client
            = wfconnect( $act_test{user}->{name}, $act_test{user}->{role} ) )
        {
            $@ = "Failed to connect as " . $act_test{user}->{name};
            return;
        }
    }
    $msg = $client->send_receive_command_msg( 'get_workflow_info',
        { 'WORKFLOW' => $wf_type, 'ID' => $id, } );
    if ( is_error_response($msg) ) {
        $@ = "Error running get_workflow_info: " . Dumper($msg);
        return;
    }
    $@ = Dumper($msg);
    if ($disc) {
        wfdisconnect();
    }
    return $msg->{PARAMS}->{WORKFLOW}->{STATE};
}

#
# usage: my $param = wfparam( ID, PARAM );
# Note: $@ contains either error message or Dumper($msg)
#
sub wfparam {
    my ( $id, $name ) = @_;
    my ( $msg, $state );
    my $disc = 0;
    $@ = '';

    unless ($client) {
        $disc++;
        unless ( $client
            = wfconnect( $act_test{user}->{name}, $act_test{user}->{role} ) )
        {
            $@ = "Failed to connect as " . $act_test{user}->{name};
            return;
        }
    }
    $msg = $client->send_receive_command_msg( 'get_workflow_info',
        { 'WORKFLOW' => $wf_type, 'ID' => $id, } );
    if ( is_error_response($msg) ) {
        $@ = "Error running get_workflow_info: " . Dumper($msg);
        return;
    }
    $@ = Dumper($msg);
    if ($disc) {
        wfdisconnect();
    }
    diag( "msg=" . Dumper($msg) );
    return $msg->{PARAMS}->{WORKFLOW}->{STATE};
}

###################################################
# The wftask_* routines represent individual tasks
# done by a user. If there is an error in a single
# step, undef is returned. The reason is in $@ and
# on success, $@ contains Dumper($msg) if $msg is
# not normally returned.
#
# Each routine takes care of login and logout.
###################################################
#
# usage: my $id = wftask_create( USER, PASS, TOKENID, AUTH1, AUTH2 );
#
sub wftask_create {
    my ( $u, $p, $t, $a1, $a2 ) = @_;
    my ( $id, $msg );

    unless ( $client = wfconnect( $u, $p ) ) {
        $@ = "Failed to connect as $u";
        return;
    }

    $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {   PARAMS   => { token_id => $t },
            WORKFLOW => $wf_type,
        }
    );
    if ( is_error_response($msg) ) {
        $@ = "Error creating workflow instance: " . Dumper($msg);
        return;
    }

    $id = $msg->{PARAMS}->{WORKFLOW}->{ID};

    unless ( $msg->{PARAMS}->{WORKFLOW}->{STATE} eq 'HAVE_TOKEN_OWNER' ) {
        $@ = "Error - new workflow in wrong state: " . Dumper($msg);
        return;
    }

    $msg = wfexec( $id, 'store_auth_ids',
        { auth1_id => $a1, auth2_id => $a2 } );
    if ( is_error_response($msg) ) {
        $@ = "Error storing auth IDs: " . Dumper($msg);
        return;
    }
    unless ( $msg->{PARAMS}->{WORKFLOW}->{STATE} eq 'PEND_ACT_CODE' ) {
        $@ = "Error - new workflow in wrong state: " . Dumper($msg);
        return;
    }

    wfdisconnect();

    #	eval {
    #	    $msg = $client->send_receive_service_msg('LOGOUT');
    #	};

    return $id;
}

sub wftask_puk_upload {
    my ( $u, $p, $tok, $puk ) = @_;
    my ( $id, $msg );

    unless ( $client = wfconnect( $u, $p ) ) {
        $@ = "Failed to connect as $u";
        return;
    }

    $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {   PARAMS   => { token_id => $tok, _puk => $puk },
            WORKFLOW => $wf_type_puk,
        }
    );
    if ( is_error_response($msg) ) {
        $@ = "Error creating puk upload workflow instance: " . Dumper($msg);
        return;
    }
    return 1;
}

#
# usage: my $code = wftask_getcode( ID, USER, PASS );
#
sub wftask_getcode {
    my ( $id, $u, $p ) = @_;

    my ( $ret, $msg );
    unless ( $client = wfconnect( $u, $p ) ) {
        $@ = "Failed to connect as $u";
        return;
    }
    sleep 1 if $sleep;

    $msg = $client->send_receive_command_msg( 'get_workflow_info',
        { 'WORKFLOW' => $wf_type, 'ID' => $id, } );
    if ( is_error_response($msg) ) {
        $@ = "Error running get_workflow_info: " . Dumper($msg);
        return;
    }
    sleep 1 if $sleep;

    unless ( $msg->{PARAMS}->{WORKFLOW}->{STATE} eq 'PEND_ACT_CODE' ) {
        $@ = "Error: workflow state must be PEND_ACT_CODE to get code";
        diag( $@, Dumper($msg) );
        return;
    }

    #	$msg = wfexec( $id, 'scpu_generate_activation_code', { _user => $u }, );
    $msg = wfexec( $id, 'scpu_generate_activation_code', {}, );
    if ( is_error_response($msg) ) {
        $@ = "Error running scpu_generate_activation_code: " . Dumper($msg);
        return;
    }
    sleep 1 if $sleep;

    $ret = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_password};
    diag( "$id/$u code: " . $ret );
    wfdisconnect();

    #	eval {
    #	    $msg = $client->send_receive_service_msg('LOGOUT');
    #	};
    return $ret;
}

#
# usage: my $ret = wftask_verifycodes( ID, USER, PASS, CODE1, CODE2, PIN1, PIN2 );
#
sub wftask_verifycodes {
    my ( $id, $u, $p, $ac1, $ac2, $pin1, $pin2 ) = @_;
    my ( $ret, $msg, $state );

    unless ( $client = wfconnect( $u, $p ) ) {
        $@ = "Failed to connect as $u";
        return;
    }

    $state = wfstate($id) or return;

    unless ( $state eq 'PEND_PIN_CHANGE' ) {
        $@ = "Error - wrong state ($state) for pin change";
        return;
    }

    $msg = wfexec(
        $id,
        'post_codes_and_pin',
        {   _auth1_code => $ac1,
            _auth2_code => $ac2,
            _new_pin1   => $pin1,
            _new_pin2   => $pin2,
        }
    );
    if ( is_error_response($msg) ) {
        $@ = "Error running post_codes_and_pin: " . Dumper($msg);
        return;
    }

    $state = wfstate($wf_id);
    unless ( $state eq 'CAN_FETCH_PUK' ) {
        $@ = "Error - wrong state ($state) for fetching puk";
        return;
    }

    $msg = wfexec( $wf_id, 'fetch_puk', {} );
    if ( is_error_response($msg) ) {
        $@ = "Error running fetch_puk: " . Dumper($msg);
        return;
    }

    $state = wfstate($wf_id);
    unless ( $state eq 'CAN_WRITE_PIN' ) {
        $@ = "Error - wrong state ($state) for pin change";
        return;
    }

    # Wrap it up by changing state to success
    $msg = wfexec( $wf_id, 'write_pin_ok', {} );
    if ( is_error_response($msg) ) {
        $@ = "Error running write_pin_ok: " . Dumper($msg);
        return;
    }

    $state = wfstate($wf_id);
    unless ( $state eq 'SUCCESS' ) {
        $@ = "Error - wrong state ($state) for finish";
        return;
    }

    wfdisconnect();

    #	eval {
    #	    $msg = $client->send_receive_service_msg('LOGOUT');
    #	};

    return 1;
}

############################################################
# START TESTS
############################################################

diag('##################################################');
diag('# Init tests');
diag('##################################################');

TODO: {
    local $TODO = 'need to find path of PID file';
    ok( -e $pidfile, "PID file exists" );
}

ok( -e $socketfile, "Socketfile exists" );

#
# Add PUKs to datapool
#
ok( wftask_puk_upload(
        $act_test{user}->{name},  $act_test{user}->{role},
        $act_test{user}->{token}, $act_test{user}->{puk},
    ),
    'upload PUK'
) or die "PUK Upload failed: $@";

diag('##################################################');
diag('# Walk through a single workflow session');
diag('##################################################');

# Note: if anything in this section fails, just die immediately
# because continuing with the other tests then makes no sense.

ok( $client = wfconnect( $act_test{user}->{name}, $act_test{user}->{role} ),
    "login successful" ) or die "login not successful";

$msg = $client->send_receive_command_msg(
    'create_workflow_instance',
    {   'PARAMS'   => { token_id => $act_test{user}->{token}, },
        'WORKFLOW' => $wf_type,
    },
);

ok( !is_error_response($msg),
    'Successfully created unblock workflow for token_id '.
    $act_test{user}->{role} )
    or die("Unable to create unblock workflow: ", Dumper($msg));

$wf_id = $msg->{PARAMS}->{WORKFLOW}->{ID};

is( $msg->{PARAMS}->{WORKFLOW}->{STATE},
    'HAVE_TOKEN_OWNER', 'Workflow state HAVE_TOKEN_OWNER' )
    or die("State after create must be HAVE_TOKEN_OWNER: ", Dumper($msg));

$msg = wfexec(
    $wf_id,
    'store_auth_ids',
    {   auth1_id => $act_test{auth1}->{name},
        auth2_id => $act_test{auth2}->{name},
    },
);

ok( !is_error_response($msg), 'Successfully executed store_auth_ids' )
    or die( "Error executing store_auth_ids: ", Dumper($msg) );

is( $msg->{PARAMS}->{WORKFLOW}->{STATE},
    'PEND_ACT_CODE', 'Workflow store_auth_ids OK' )
    or die( "State after store_auth_ids must be PEND_ACT_CODE: ", Dumper($msg) );

# Logout to be able to re-login as the auth users
wfdisconnect();

foreach my $a (qw( auth1 auth2 )) {
    my $code = wftask_getcode( $wf_id, $act_test{$a}->{name},
        $act_test{$a}->{role} );
    croak "get code for $a failed: $@." unless defined $code;
    $act_test{$a}->{code} = $code;
}

unless (
    $client
    = wfconnect( $act_test{user}->{name}, $act_test{user}->{role} ),
    "login successful"
    )
{
    croak "Error connecting to server as ", $act_test{user}->{name};
}

is( wfstate($wf_id), 'PEND_PIN_CHANGE', 'State after fetching codes' )
    or die("State after fetching codes must be PEND_PIN_CHANGE: " . $@);

# Provide correct codes and pins
$msg = wfexec(
    $wf_id,
    'post_codes_and_pin',
    {   _auth1_code => $act_test{auth1}->{code},
        _auth2_code => $act_test{auth2}->{code},
        _new_pin1   => '1234',
        _new_pin2   => '1234',
    }
);

ok( !is_error_response($msg), 'Successfully ran post_codes_and_pin' )
    or die( "Error running post_codes_and_pin: ", Dumper($msg) );

is( wfstate($wf_id), 'CAN_FETCH_PUK', 'Workflow state after correct pin' )
    or die("State after post_codes_and_pin must be CAN_FETCH_PUK: ", $@, Dumper($msg) );

$msg = wfexec( $wf_id, 'fetch_puk', {} );

my $got_puk = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_puk};
is( $got_puk, $act_test{user}->{puk}, 'fetched puk should match ours' )
    or die( "Error from fetch_puk: ", Dumper($msg) );

is( wfstate($wf_id), 'CAN_WRITE_PIN', 'Workflow state after correct pin' )
    or die("State after fetch_puk must be CAN_WRITE_PIN: ", $@, Dumper($msg) );

#is ( wfparam( $wf_id, '_puk' ), $act_test{user}->{puk},
#       "check puk returned from datapool") or diag($@);

# Wrap it up by changing state to success
$msg = wfexec( $wf_id, 'write_pin_ok', {} );
ok( !is_error_response($msg), 'Successfully ran write_pin_ok' )
    or die( "Error write_pin_ok MSG: ", Dumper($msg) );

is( wfstate($wf_id), 'SUCCESS', 'Workflow state after write_pin_ok' )
    or die("State after write_pin_ok must be SUCCESS:", $@);


diag('##################################################');
diag('# Test for various possible errors');
diag('##################################################');

############################################################
# Create workflow that fails due to invalid token owner
############################################################

ok( $client = wfconnect( $act_test{user}->{name}, $act_test{user}->{role} ),
    "login successful" );

$tok_id = $act_test{user}->{token} . '-1';

$msg = $client->send_receive_command_msg(
    'create_workflow_instance',
    {   'PARAMS'   => { token_id => $tok_id, },
        'WORKFLOW' => $wf_type,
    },
);

ok( is_error_response($msg),
    'Test with invalid token - msg should be error' );
is( $msg->{LIST}->[0]->{LABEL},
    'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_ENTRY_NOT_FOUND',
    'Check that login failed due to missing LDAP entry'
);

############################################################
# Create workflow and cancel at HAVE_TOKEN_OWNER
############################################################
$tok_id = $act_test{user}->{token};

$msg = $client->send_receive_command_msg(
    'create_workflow_instance',
    {   'PARAMS'   => { token_id => $tok_id, },
        'WORKFLOW' => $wf_type,
    },
);
ok( !is_error_response($msg), 'Successfully created unblock workflow for token_id '. $tok_id ) or
diag("1 MSG: ", Dumper($msg));


$wf_id = $msg->{PARAMS}->{WORKFLOW}->{ID};

#diag("wf_id: ", $wf_id);
is( $msg->{PARAMS}->{WORKFLOW}->{STATE},
    'HAVE_TOKEN_OWNER', 'Workflow state HAVE_TOKEN_OWNER' ) or
diag("MSG: ", Dumper($msg));

$msg = $client->send_receive_command_msg(
    'execute_workflow_activity',
    {   'ID'       => $wf_id,
        'ACTIVITY' => 'user_abort',
        'PARAMS'   => {},
        'WORKFLOW' => $wf_type,
    },
);
ok( !is_error_response($msg), 'Successfully executed user_abort' )
    or diag( "2 MSG: ", Dumper($msg) );
is( $msg->{PARAMS}->{WORKFLOW}->{STATE}, 'FAILURE', 'Workflow user_abort OK' )
    or diag( "3 MSG: ", Dumper($msg) );

############################################################
# Provide wrong activation codes
############################################################
$wf_id = wftask_create(
    $act_test{user}->{name},  $act_test{user}->{role},
    $act_test{user}->{token}, $act_test{auth1}->{name},
    $act_test{auth2}->{name}
);
croak $@ unless defined $wf_id;

# Get activation codes
foreach my $a (qw( auth1 auth2 )) {
    my $code = wftask_getcode( $wf_id, $act_test{$a}->{name},
        $act_test{$a}->{role} );
    croak $@ unless defined $code;
    $act_test{$a}->{code} = $code;
}

# Purposefully provide wrong activation codes to force error
ok( !wftask_verifycodes(
        $wf_id,
        $act_test{user}->{name},
        $act_test{user}->{role},
        _auth1_code => $act_test{auth2}->{code},
        _auth2_code => $act_test{auth1}->{code},
        _new_pin1   => $act_test{user}->{newpin},
        _new_pin2   => $act_test{user}->{newpin},
    ),
    'Purposefully provide wrong codes to force error'
);

is( wfstate($wf_id), 'PEND_PIN_CHANGE', 'Workflow state after wrong pin' )
    or diag($@);

# Now, provide the correct details for the post
ok( wftask_verifycodes(
        $wf_id,                   $act_test{user}->{name},
        $act_test{user}->{role},  $act_test{auth1}->{code},
        $act_test{auth2}->{code}, $act_test{user}->{newpin},
        $act_test{user}->{newpin},
    ),
    'Verify codes and pin using correct codes'
);

is( wfstate($wf_id), 'SUCCESS', 'Workflow state after write_pin_ok' )
    or diag($@);

############################################################
# Create new workflow to test failure after three invalid code attempts
############################################################
$wf_id = wftask_create(
    $act_test{user}->{name},  $act_test{user}->{role},
    $act_test{user}->{token}, $act_test{auth1}->{name},
    $act_test{auth2}->{name}
);
croak 'Create wf failed: ', $@ unless defined $wf_id;

# Get activation codes
foreach my $a (qw( auth1 auth2 )) {
    my $code = wftask_getcode( $wf_id, $act_test{$a}->{name}, 'User' );
    croak 'get code failed: ', $@ unless defined $code;
    $act_test{$a}->{code} = $code;
}

# Verify codes and pin -- USING INVALID SWAP OF AUTH CODES
for ( my $i = 0; $i < 3; $i++ ) {
    ok( !wftask_verifycodes(
            $wf_id,                   $act_test{user}->{name},
            $act_test{user}->{role},  $act_test{auth2}->{code},
            $act_test{auth1}->{code}, '1234',
            '1234'
        ),
        'Verify codes and pin using wrong codes'
    );
}

#diag("4");
unless ( $client
    = wfconnect( $act_test{user}->{name}, $act_test{user}->{role} ) )
{
    croak "Failed to connect as " . $act_test{user}->{name};
}

my $state = wfstate($wf_id)
    or croak $@;
is( $state, 'FAILURE',
    "Workflow $wf_id should fail due to too many pin attempts" );

# LOGOUT
wfdisconnect();


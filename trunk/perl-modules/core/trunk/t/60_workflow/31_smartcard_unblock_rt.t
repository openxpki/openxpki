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

# reuse the already deployed server
#my $instancedir = 't/60_workflow/test_instance';
my $instancedir = '';
my $socketfile  = $instancedir . '/var/openxpki/openxpki.socket';
my $pidfile     = $instancedir . '/var/openxpki/openxpki.pid';

my $tok_id;
my $wf_type = 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK';
my ( $msg, $wf_id, $client );

my %act_test = (
    selfserve => {
        name => 'selfserve',
        role => 'User',
    },
    user => {
        name   => 'user002@local',
        role   => 'User',
        newpin => '1234',
        token  => 'gem2_002',
    },
    auth1 => {
        name => 'user003@local',
        role => 'User',
        code => '',
    },
    auth2 => {
        name => 'user004@local',
        role => 'User',
        code => '',
    },
);

#
# $client = wfconnect( USER, PASS [, REALM] );
#
sub wfconnect {
    my ( $u, $p, $r ) = @_;
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
        {
            'ID'       => $id,
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
        unless ( $client =
            wfconnect( $act_test{user}->{name}, $act_test{user}->{role} ) )
        {
            $@ = "Failed to connect as " . $act_test{user}->{name};
            return;
        }
    }
    $msg =
      $client->send_receive_command_msg( 'get_workflow_info',
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
        {
            PARAMS   => { token_id => $t },
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

    $msg =
      wfexec( $id, 'store_auth_ids', { auth1_id => $a1, auth2_id => $a2 } );
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

    $msg =
      $client->send_receive_command_msg( 'get_workflow_info',
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
        {
            _auth1_code => $ac1,
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

$wf_id = wftask_create(
    $act_test{user}->{name},  $act_test{user}->{role},
    $act_test{user}->{token}, $act_test{auth1}->{name},
    $act_test{auth2}->{name}
);
croak $@ unless defined $wf_id;

# Get activation codes
foreach my $a ( qw( auth1 auth2 ) ) {
    my $code =
      wftask_getcode( $wf_id, $act_test{$a}->{name}, $act_test{$a}->{role} );
    croak $@ unless defined $code;
    $act_test{$a}->{code} = $code;
}


# Now, provide the correct details for the post
ok(
    wftask_verifycodes(
        $wf_id,                   $act_test{user}->{name},
        $act_test{user}->{role},  $act_test{auth1}->{code},
        $act_test{auth2}->{code}, $act_test{user}->{newpin},
        $act_test{user}->{newpin},
    ),
    'Verify codes and pin using correct codes'
);

is( wfstate($wf_id), 'SUCCESS', 'Workflow state after write_pin_ok' )
  or diag($@);

# LOGOUT
wfdisconnect();


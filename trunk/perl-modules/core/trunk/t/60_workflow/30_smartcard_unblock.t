use strict;
use warnings;
use Carp;
use English;

use Data::Dumper;

package OpenXPKI::Tests::More::SmartcardUnblock;
use base qw( OpenXPKI::Tests::More );
sub wftype { return 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK' }

my %act_test = (
    selfserve => {
        name => 'selfserve',
        role => 'User',
    },
    user => {
        name   => 'martin.bartosch@db.com',
        role   => 'User',
        newpin => '1234',
        token  => 'gem2_123456',
        puk    => '2234',
    },
    auth1 => {
        name => 'scott.hardin@db.com',
        role => 'User',
        code => '',
    },
    auth2 => {
        name => 'arkadius.litwinczuk@db.com',
        role => 'User',
        code => '',
    },
);
sub puk_upload {
    my ( $self, $tok, $puk ) = @_;
    my ( $id, $msg );
    my $wf_type_puk = 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PUK_UPLOAD';

    if ( !$self->create( $wf_type_puk, { token_id => $tok, _puk => $puk } ) )
    {
        $@ = "Error creating puk upload workflow instance: $@";
        return;
    }
    return 1;
}

#
# usage: my $code = $test->get_code( USER, PASS );
#
sub get_code {
    my ( $self, $u, $p ) = @_;
    warn "Entered get_code($u, $p)" if $self->get_verbose();


    $self->connect( user => $u, password => $p )
        or return;

    my $state = $self->state()
        or return;

    unless ( $state =~ /^(PEND_ACT_CODE|PEND_PIN_CHANGE)$/ ) {
        $@
            = "Error: workflow state must be PEND_ACT_CODE or PEND_PIN_CHANGE to get code";
        return;
    }

    $self->execute( 'generate_activation_code', {} )
        or return;

    my $ret = $self->param('_password');
    $ret = '<undef>' unless defined $ret;
    $self->diag( $self->get_wfid(), "/$u code: " . $ret );

    $self->disconnect();

    return $ret;
}

###################################################
# These routines represent individual tasks
# done by a user. If there is an error in a single
# step, undef is returned. The reason is in $@ and
# on success, $@ contains Dumper($msg) if $msg is
# not normally returned.
#
# Each routine takes care of login and logout.
###################################################

# create_request covers the steps on the first page of the flowchart
# document. The user supplies the authorizing persons and the next
# step is for the authorizing persons to fetch their codes.
#
# On error, C<undef> is returned and the reason is in C<$@>.
#
# usage: $test->create_request( USER, PASS, TOKENID, AUTH1, AUTH2 );
#
sub create_request {
    my ( $self, $u, $p, $t, $a1, $a2 ) = @_;
    my ( $id, $msg );

    if ( not $self->connect() ) {
        $@ = "Failed to connect as anonymous";
        return;
    }

    if ( not $self->create( $self->wftype, { token_id => $t } ) ) {
        $@ = "Error creating workflow instance: ";    # . $self->dump;
        return;
    }

    if ( not $self->state eq 'HAVE_TOKEN_OWNER' ) {
        $@ = "Error - new workflow in wrong state: " . $self->state;
        return;
    }

    if (not $self->execute(
            'store_auth_ids', { auth1_id => $a1, auth2_id => $a2 }
        )
        )
    {
        $@ = "Error storing auth IDs";    # . $self->dump;
        return;
    }

    if ( not $self->state eq 'PEND_ACT_CODE' ) {
        $@ = "Error - new workflow in wrong state: " . $self->state;
        return;
    }

    $self->disconnect();

    return $self;
}

# Check auth codes
#
# usage: $test->verify_codes( USER, PASS, CODE1, CODE2 );
#
sub verify_codes {
    my ( $self, $u, $p, $ac1, $ac2 ) = @_;
    my ( $ret, $msg, $state );

    if ( not $self->connect() ) {
        $@ = "Failed to connect as anonymous";
        return;
    }

    if ( not $self->state eq 'PEND_PIN_CHANGE' ) {
        $@ = "Error - wrong state (" . $self->state . ") for pin change";
        return;
    }

    if (not $self->execute(
            'post_codes',
            {   _auth1_code => $ac1,
                _auth2_code => $ac2,
            }
        )
        )
    {
        $@ = "Error running post_codes: " . $self->dump;
        return;
    }

    if ( not $self->state eq 'CAN_FETCH_PUK' ) {
        $@ = "Error - wrong state (" . $self->state . ") for fetching puk";
        return;
    }

    if ( not $self->execute( 'fetch_puk', {} ) ) {
        $@ = "Error running fetch_puk: " . $self->dump;
        return;
    }

    if ( not $self->state eq 'CAN_WRITE_PIN' ) {
        $@ = "Error - wrong state (" . $self->state . ") for pin change";
        return;
    }

    if ( not $self->execute( 'write_pin_ok', {} ) ) {
        $@ = "Error running write_pin_ok: " . $self->dump;
        return;
    }

    if ( not $self->state eq 'SUCCESS' ) {
        $@ = "Error - wrong state (" . $self->state . ") for finish";
        return;
    }

    $self->disconnect();

    return $self;
}

package main;

my $sleep = 0;    # set to '1' to cause pause between transactions

my $realm       = 'User TEST CA';
my $instancedir = '';
my $socketfile  = $instancedir . '/var/openxpki/openxpki.socket';
my $tok_id;
my $wf_type = 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK';
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
    auth3 => {
        name => 'CHANGEME@CHANGEME',
        role => 'User',
        code => '',
    },
);

# DATA FOR USING IN MY VM TEST GUEST
$act_test{user}->{name}  = 'user002@local';
$act_test{user}->{token} = 'gem2_002';
$act_test{user}->{puk}   = '2234';
$act_test{auth1}->{name} = 'user003@local';
$act_test{auth2}->{name} = 'user004@local';
$act_test{auth3}->{name} = 'user005@local';
$realm                   = undef;

# DATA FOR USING IN MY TEST ON DCA04
$act_test{user}->{name} = 'martin.bartosch@db.com';
$act_test{user}->{token} = 'gem2_094F88ECF273ABE6';
$act_test{user}->{puk} = '2234';
$act_test{auth1}->{name} = 'scott.hardin@db.com';
$act_test{auth2}->{name} = 'arkadius.litwinczuk@db.com';
$act_test{auth3}->{name} = 'martin.sander@db.com';
my $do_puk_upload = 1;  # not needed in dca04 env

############################################################
# START TESTS
############################################################

my $test = OpenXPKI::Tests::More::SmartcardUnblock->new(
    {   socketfile => $socketfile,
        realm      => $realm
    }
) or die "error creating new test instance: $@";

$test->plan( tests => 44 );

$test->diag('##################################################');
$test->diag('# Init tests');
$test->diag('##################################################');

$test->ok( -e $socketfile, "Socketfile exists" );

$test->connect_ok(
    user     => $act_test{user}->{name},
    password => $act_test{user}->{role},
) or die "Need session to continue: $@";

#
# Add PUKs to datapool
#
$test->ok(
    $test->puk_upload( $act_test{user}->{token}, $act_test{user}->{puk}, ),
    'upload PUK' )
    or die "PUK Upload failed: $@";

$test->disconnect();

$test->diag('##################################################');
$test->diag('# Walk through a single workflow session');
$test->diag('##################################################');

$test->connect_ok() or die "Need session to continue: $@";

# Note: if anything in this section fails, just die immediately
# because continuing with the other tests then makes no sense.
$test->create_ok( $wf_type, { token_id => $act_test{user}->{token}, } )
    or die( "Unable to create unblock workflow: ", $@ );

$test->state_is( 'HAVE_TOKEN_OWNER', 'Workflow state HAVE_TOKEN_OWNER' )
    or die( "State after create must be HAVE_TOKEN_OWNER: ", $test->dump() );

$test->execute_ok(
    'store_auth_ids',
    {   auth1_id => $act_test{auth1}->{name},
        auth2_id => $act_test{auth2}->{name},
    }
) or die( "Error executing store_auth_ids: ", $test->dump() );

$test->state_is('PEND_ACT_CODE')
    or die( "State after store_auth_ids must be PEND_ACT_CODE: ",
    $test->dump() );

# Logout to be able to re-login as the auth users
$test->disconnect();

#$test->set_verbose(1);
foreach my $a (qw( auth1 auth2 )) {
    my $code
        = $test->get_code( $act_test{$a}->{name}, $act_test{$a}->{role} );
    croak "get code for $a failed: $@." unless defined $code;
    $act_test{$a}->{code} = $code;
}

#$test->set_verbose(0);

$test->connect_ok() or die "Need session to continue: $@";

# At this point, the user has re-started the session and should get
# the current workflow for the inserted token id

my @workflows = sort {
    $b->{'WORKFLOW.WORKFLOW_SERIAL'} <=> $a->{'WORKFLOW.WORKFLOW_SERIAL'}
    }
    grep { not $_->{'WORKFLOW.WORKFLOW_STATE'} =~ /^(SUCCESS|FAILURE)$/ }
    $test->search( 'token_id', $act_test{user}->{token} );

# assume that it's the first one!
$test->is( $workflows[0]->{'WORKFLOW.WORKFLOW_SERIAL'},
    $test->get_wfid, 'Workflow ID matches our ID' )
    or
    die( "Workflow ID returned for token_id does not match our workflow ID: ",
    $@, $test->dump() );

$test->state_is( 'PEND_PIN_CHANGE', 'State after fetching codes' )
    or die( "State after fetching codes must be PEND_PIN_CHANGE: " . $@ );

# Provide correct codes and pins
$test->execute_ok(
    'post_codes',
    {   _auth1_code => $act_test{auth1}->{code},
        _auth2_code => $act_test{auth2}->{code},
    }
) or die( "Error running post_codes: ", $test->dump() );

$test->state_is( 'CAN_FETCH_PUK', 'State after post_codes pin' )
    or die( "State after post_codes must be CAN_FETCH_PUK: " . $@ );

$test->execute_ok( 'fetch_puk', {} );

$test->param_is(
    '_puk',
    $act_test{user}->{puk},
    'fetched puk should match ours'
) or die( 'Error from fetch_puk: ', $test->dump() );

$test->state_is( 'CAN_WRITE_PIN', 'Workflow state after fetch_puk' )
    or
    die( "State after fetch_puk must be CAN_WRITE_PIN: ", $@, $test->dump() );

# Wrap it up by changing state to success

$test->execute_ok( 'write_pin_ok', {} )
    or die( 'error write_pin_ok: ', $test->dump );

$test->state_is( 'SUCCESS', 'Workflow state after write_pin_ok' )
    or die( 'State after write_pin_ok must be SUCCESS: ', $test->dump );

$test->diag('##################################################');
$test->diag('# Test for various possible errors');
$test->diag('##################################################');

############################################################
# Create workflow that fails due to invalid token owner
############################################################

$test->connect_ok() or die "Need session to continue: $@";

$tok_id = $act_test{user}->{token} . '-1';

$test->create_nok(
    $wf_type,
    { token_id => $tok_id, },
    'Test with invalid token - create() should fail'
) or die( "Create WF was unexpectedly successful: ", $@ );

$test->is(
    $test->get_msg()->{LIST}->[0]->{LABEL},
    'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_ENTRY_NOT_FOUND',
    'Check that login failed due to missing LDAP entry'
);

############################################################
# Create workflow and cancel at HAVE_TOKEN_OWNER
############################################################
$tok_id = $act_test{user}->{token};

$test->create_ok( $wf_type, { token_id => $tok_id, }, )
    or die( "Create WF failed: ", $@ );

$test->state_is('HAVE_TOKEN_OWNER')
    or die( 'Fresh workflow in wrong state', $test->dump() );

$test->execute_ok( 'user_abort', { error_code => 'user chickened out' } )
    or die( 'Error executing user_abort: ', $test->dump() );

$test->state_is( 'FAILURE', 'Check that is correct after user_abort' )
    or die( 'Wrong state after user_abort', $test->dump() );

############################################################
# Provide wrong activation codes
############################################################

$test->create_request_ok(
    [   $act_test{user}->{name},  $act_test{user}->{role},
        $act_test{user}->{token}, $act_test{auth1}->{name},
        $act_test{auth2}->{name}
    ],
    'Create request for wrong act codes'
) or croak $@;

foreach my $a (qw( auth1 auth2 )) {
    my $code
        = $test->get_code( $act_test{$a}->{name}, $act_test{$a}->{role} );
    croak "get code for $a failed: $@." unless defined $code;
    $act_test{$a}->{code} = $code;
}

$test->connect_ok() or die "Need session to continue: $@";

# Purposefully provide wrong activation codes to force error
$test->verify_codes_nok(
    [   $act_test{user}->{name},
        $act_test{user}->{role},
        _auth1_code => $act_test{auth2}->{code},
        _auth2_code => $act_test{auth1}->{code},
    ],
    'Purposefully provide wrong codes to force error'
);

$test->connect_ok() or die "Need session to continue: $@";

$test->state_is( 'PEND_PIN_CHANGE', 'Check that is correct after wrong auth' )
    or die( 'Wrong state after user_abort', $test->dump() );

# Now, provide the correct details for the post
$test->verify_codes_ok(
    [   $act_test{user}->{name},  $act_test{user}->{role},
        $act_test{auth1}->{code}, $act_test{auth2}->{code}
    ],
    'Verify codes using correct codes'
);

$test->connect_ok() or die "Need session to continue: $@";

$test->state_is( 'SUCCESS', 'Workflow state after correct codes' )
    or die( 'Workflow state after writing correct codes', $test->dump() );

############################################################
# Create new workflow with card owner == auth user and confirm fail
############################################################
$test->create_request_nok(
    [   $act_test{user}->{name},  $act_test{user}->{role},
        $act_test{user}->{token}, $act_test{user}->{name},
        $act_test{auth2}->{name}
    ],
    'Workflow should fail if card owner == auth user'
);

############################################################
# Create new workflow and test that we can fetch the act codes again
############################################################
$test->create_request_ok(
    [   $act_test{user}->{name},  $act_test{user}->{role},
        $act_test{user}->{token}, $act_test{auth1}->{name},
        $act_test{auth2}->{name}
    ],
    'Create workflow request'
) or croak 'Create wf failed: ', $@;

# Get activation codes
foreach my $a (qw( auth1 auth2 )) {
    my $code
        = $test->get_code( $act_test{$a}->{name}, $act_test{$a}->{role} );
    croak "get code for $a failed: $@." unless defined $code;
    $act_test{$a}->{code} = $code;
}

# Get activation codes again
foreach my $a (qw( auth1 auth2 )) {
    my $code
        = $test->get_code( $act_test{$a}->{name}, $act_test{$a}->{role} );
    croak "get code for $a failed: $@." unless defined $code;
    $act_test{$a}->{code} = $code;
}

# Now, provide the correct details for the post
$test->verify_codes_ok(
    [   $act_test{user}->{name},  $act_test{user}->{role},
        $act_test{auth1}->{code}, $act_test{auth2}->{code}
    ],
    'Verify codes and pin after re-fetching codes'
);

$test->connect_ok() or die "Need session to continue: $@";

$test->state_is( 'SUCCESS', 'Workflow state after write_pin_ok' )
    or die( 'Workflow state after writing write_pin_ok', $test->dump() );

############################################################
# Create new workflow and test that we can fetch the act codes again
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

# Get activation codes again
foreach my $a (qw( auth1 auth2 )) {
    my $code = wftask_getcode( $wf_id, $act_test{$a}->{name}, 'User' );
    croak 'get code failed: ', $@ unless defined $code;
    $act_test{$a}->{code} = $code;
}

# Now, provide the correct details for the post
ok( wftask_verifycodes(
        $wf_id,                   $act_test{user}->{name},
        $act_test{user}->{role},  $act_test{auth1}->{code},
        $act_test{auth2}->{code}, $act_test{user}->{newpin},
        $act_test{user}->{newpin},
    ),
    'Verify codes and pin after re-fetching codes'
);

is( wfstate($wf_id), 'SUCCESS', 'Workflow state after write_pin_ok' )
    or diag($@);

#diag("4");
#unless ( $client
#    = wfconnect( $act_test{user}->{name}, $act_test{user}->{role} ) )
#{
#    croak "Failed to connect as " . $act_test{user}->{name};
#}
#
#my $state = wfstate($wf_id)
#    or croak $@;
#is( $state, 'FAILURE',
#    "Workflow $wf_id should fail due to too many pin attempts" );

############################################################
# Create new workflow to test failure after three invalid code attempts
############################################################
$test->create_request_ok(
    [   $act_test{user}->{name},  $act_test{user}->{role},
        $act_test{user}->{token}, $act_test{auth1}->{name},
        $act_test{auth2}->{name}
    ]
) or croak 'Create wf failed: ', $@;

# Get activation codes
foreach my $a (qw( auth1 auth2 )) {
    my $code
        = $test->get_code( $act_test{$a}->{name}, $act_test{$a}->{role} );
    croak "get code for $a failed: $@." unless defined $code;
    $act_test{$a}->{code} = $code;
}

# Verify codes and pin -- USING INVALID SWAP OF AUTH CODES
for ( my $i = 0; $i < 3; $i++ ) {
    $test->verify_codes_nok(
        [   $act_test{user}->{name},  $act_test{user}->{role},
            $act_test{auth2}->{code}, $act_test{auth1}->{code}
        ],
        'Verify codes and pin using wrong codes'
    );
}

$test->connect_ok() or die "Need session to continue: $@";

$test->state_is( 'FAILURE',
    'Workflow should fail due to too many auth attempts' )
    or die( 'Workflow state after writing write_pin_ok', $test->dump() );

# LOGOUT
$test->disconnect();


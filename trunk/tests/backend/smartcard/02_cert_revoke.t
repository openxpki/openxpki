#!/usr/bin/perl
#
# 02_cert_revoke.t - tests for soap-based cert revoke
#
#
# The SOAP interface is used by the badge office to revoke the certificates 
# for a given card.
#
# This test script does a couple of debug calls and then sends a revoke request
# for various scenarios. 
#
# IMPORTANT:
# Set the environment variable DESTRUCTIVE_TESTS to a true value to
# have the LDAP data purged and loaded from the LDIF file.
#
# SETUP:
#
# To run this, you need to do the following in advance:
#
# - Generate CSR for TLS Client certificate
#
#	mkdir -p ca
#	openssl req -new -nodes -keyout ca/tls-client.key -out ca/tls-client.csr -newkey rsa:2048
#
# - Get a TLS Client certificate
# - Download new PEM to ca/tls-client.pem
# - Download chain to ca/tls-chain.pem

use strict;
use warnings;

use lib qw(     /usr/local/lib/perl5/site_perl/5.8.8/x86_64-linux-thread-multi
    /usr/local/lib/perl5/site_perl/5.8.8
    /usr/local/lib/perl5/site_perl
    ../../lib
);
use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;
use Test::More;

use TestCfg;
use SOAP::Lite;

my $dirname = dirname($0);

our @cfgpath = ( $dirname . '/../../../config/tests/backend/smartcard', $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '02_cert_revoke.cfg', \%cfg, @cfgpath );
#$testcfg->load_ldap( '02_cert_revoke.ldif', @cfgpath );

# Check for missing config params
foreach my $ent ( qw(
		core:test_ids core:soap_proxy_uri
		certs:client_cert_file
		certs:client_key_file
		certs:trusted_ca_certs_dir
) ) {
	my ($a, $b) = split(/:/, $ent, 2);
	if ( not $cfg{$a}{$b} ) {
		die "Config missing param '$b' for section '$a'";
	}
}

my @test_ids = split(/\s*[,;]\s*/, $cfg{core}{test_ids}) ;

$ENV{http_proxy} = "";
$ENV{https_proxy} = "";

$ENV{HTTPS_CA_DIR} = $cfg{certs}{trusted_ca_certs_dir};

if ($cfg{core}{use_client_authentication}) {
	$ENV{HTTPS_CERT_FILE} = $cfg{certs}{client_cert_file};
	$ENV{HTTPS_KEY_FILE} = $cfg{certs}{client_key_file};
}

diag("SOAP URI: " . $cfg{core}{soap_uri});
diag("SOAP Proxy: " . $cfg{core}{soap_proxy_uri});

my %params = ();
if ( $cfg{core}{soap_uri} ) {
	$params{uri} = $cfg{core}{soap_uri};
}
if ( $cfg{core}{soap_proxy_uri} ) {
	$params{proxy} = $cfg{core}{soap_proxy_uri};
}
my $server = SOAP::Lite->new( %params );
if ( not $server ) {
	die "Error creating new SOAP::Lite instance: $@";
}

is($server->true->result, 1, 'check true test');
is($server->false->result, 0, 'check false test');
is($server->echo('one')->result, 'one', 'check echo method');

foreach my $id (@test_ids) {
	my $return = $server->RevokeSmartcard($id);
	my $result = $return->result;
#	my $result = $server->RevokeSmartcard($id);
	if ( not defined $result ) {
		die "Error: result not defined (", ref($return), ") - ", $return->faultstring;
	}
	
	print "RevokeSmartcard($id): ";
	if ( $result == 0 ) {
		print "SUCCESS\n";
	}
	else {
		print "ERROR\n";
	}
}

die "still needs work";

our $debug = 0;
my $sleep = 0;    # set to '1' to cause pause between transactions


############################################################
# START TESTS
############################################################

my $test = OpenXPKI::Tests::More->new(
    {   
#        socketfile => $socketfile,
#        realm      => $realm
    }
) or die "error creating new test instance: $@";

if ( not @test_ids ) {
    die "No test IDs specified in configuration file";
}

$test->plan( tests => scalar @test_ids );

$test->diag('##################################################');
$test->diag('# Init tests');
$test->diag('##################################################');

############################################################
# Test Set - The Basics
############################################################

SKIP: {

    $test->skip( "The Basics", 1 ) unless $cfg{tests}{basics};

    # TEST 1
    $test->connect_ok(
        user     => $cfg{user}{name},
        password => $cfg{user}{role},
    ) or die "Need session to continue: $@";

}

############################################################
# Test Set - ACL
#
# - user may not access wf
# - RA may start wf, fetch ldap, modify user, modify status, fail
#   workflow (implicit from other tests)
############################################################

SKIP: {

    $test->skip( "ACL", 1 ) unless $cfg{tests}{acl};

    # TEST: 'User' role should not have permissions to create workflow
    $test->fetch_card_info_nok(
        [   $cfg{user}{name}, $cfg{user}{role},
            token_id => $cfg{'t-acl'}{token}
        ],
        "Create workflow with role 'User'"
    ) or croak $@;
    $test->disconnect();

}

############################################################
# Test Set - LDAP with user id
#
# x fetch entry for unique user
# x fetch entries for wildcard search
# x fetch entry for unknown user ( should return empty list )
# - fetch entry for unique user ( multiple cards )
############################################################

SKIP: {

    $test->skip( "LDAP with UID", 9 ) unless $cfg{tests}{ldapuid};

    # TEST: fetch card for given user
    $test->fetch_card_info_ok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_owner => $cfg{'t-ldap-uid-1'}{ldap_workflow_creator}
        ],
        "Fetch card by name"
    ) or croak $@;

    # TEST: confirm results
    $test->validate_card_info_ok( [ $cfg{'t-ldap-uid-1'} ],
        "Check attrs of OK token by uid" )
        or $test->diag($@);

    # TEST: fetch card for multiple users
    # (workflow fails, but there should be ldap entries in context)
    $test->fetch_card_info_nok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_owner => $cfg{'t-ldap-uid-2'}{token_owner}
        ],
        "Fetch card by name with wildcard"
    ) or croak $@;

    my $ldap_data = $test->param('_ldap_data');

    # TEST: check that we got at least a couple of records
    $test->ok( @{$ldap_data} >= 3,
        "check that at least 3 ldap records were found" );

    # TEST: fetch card for unknown user
    # (workflow fails and there should be no ldap entries in context)
    $test->fetch_card_info_nok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_owner => $cfg{'t-ldap-uid-3'}{token_owner}
        ],
        "Fetch card for unknown user"
    ) or croak $@;

    my $ldap_data2 = $test->param('_ldap_data');

    # TEST: check that we got no records
    $test->ok( @{$ldap_data2} == 0,
        "ldap search for unknown user should return no records" );

    # TEST: fetch multiple cards for given user
    # Note: a user may have more than one card, but only one
    # may be active

#    $test->fetch_card_info_ok(
#        [   $cfg{cm1}{name}, $cfg{cm1}{role},
#            token_owner => $cfg{'t-ldap-uid-4'}{token_owner},
#            end_state   => 'HAVE_MULTI_TOKEN_IDS',
#        ],
#        "Fetch multiple cards for user"
#    ) or croak $@;

    # TEST: fetch multiple cards for given user
    $test->fetch_card_info_ok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_owner => $cfg{'t-ldap-uid-4'}{token_owner},
            end_state   => 'FAILURE',
        ],
        "Fetch multiple cards for user"
    ) or croak $@;

    # TEST
    $test->param_is('error_code', 'Multi Token IDs');

    # check that multiple token ids were found
    my $ids = $test->array(qw( multi_ids ));
    my @expected_ids = split( /\s*,\s*/, $cfg{'t-ldap-uid-4'}{token_ids} );

    # TEST
    $test->is(
        $ids->count,
        scalar @expected_ids,
        'Check number of tokens found for user'
    );

}

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

SKIP: {

    $test->skip( "LDAP with Token", 10 ) unless $cfg{tests}{ldaptok};

    # TEST
    $test->fetch_card_info_ok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_id => $cfg{'t-ldap-token-1'}{token}
        ],
        "Fetch token info by token id"
    ) or croak $@ . ' - ' . $test->dump;

    # TEST - ensure that the record is what we expect
    $test->validate_card_info_ok( [ $cfg{'t-ldap-token-1'} ],
        "Check attrs of OK token by token id" )
        or $test->diag($@);

    # - one card with multiple users
    # TEST - ensure that fetch fails with multiple users
    $test->fetch_card_info_nok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_id => $cfg{'t-ldap-token-2'}{token}
        ],
        "Card with multiple users",
    ) or croak $@;

    # TEST - check that the problem actually is the number of smartcard owners
    $test->error_is(
        'I18N_OPENXPKI_SERVER_API_SMARTCARD_SC_ANALYZE_SMARTCARD_LDAP_TOO_MANY_SMARTCARD_OWNERS'
    );

    # TEST
    $test->fetch_card_info_ok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_id => $cfg{'t-ldap-token-3'}{token}
        ],
        "Card with no users",
    ) or croak $@;

    # TEST
    $test->param_isnt( 'ldap_workflow_creator', undef,
        'No user found in LDAP' );

    # TEST - card with no scb entry
    $test->fetch_card_info_ok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_id => $cfg{'t-ldap-token-4'}{token}
        ],
        "Card with no scb entry",
    ) or croak $@;

    # TEST - card with no scb entry has status 'unknown'
    $test->param_is( 'smartcard_status', 'unknown',
        'token without LDAP entry has status "unknown"' );


# TEST - card with upper-case token ID
$test->fetch_card_info_ok(
    [   $cfg{cm1}{name}, $cfg{cm1}{role},
        token_id => $cfg{'t-ldap-token-5'}{token}
    ],
    "Card with upper-case token ID",
) or croak $@;

# TEST - check card owner for above token
$test->param_is(
    'ldap_mail',
    $cfg{'t-ldap-token-5'}{ldap_mail},
    'token with uc id has ldap_mail ' . $cfg{'t-ldap-token-5'}{ldap_mail}
);

}

$test->diag( "UC TEST WF: ", $test->get_wfid() );

############################################################
# Test Set - Unblock and Personalization Workflows
#
# x validate that other workflows are correctly found
# x kill other workflows
############################################################

SKIP: {

    $test->skip( "Unblock WF", 6 ) unless $cfg{tests}{unblockwf};

    $test->disconnect();
    $test->connect(
        user     => $cfg{'t-wf-1'}{user},
        password => $cfg{'t-wf-1'}{pass}
        )
        or croak "Error connecting as user '"
        . $cfg{'t-wf-1'}{user} . "': $@";
    $test->create(
        'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK',
        { token_id => $cfg{'t-wf-1'}{token} }
    ) or croak $@;

    # TEST - check state of unblock workflow
    $test->state_is('HAVE_TOKEN_OWNER') or croak $@;
    my $wfid = $test->get_wfid;

    #$test->diag("WFID for unblock: $wfid");

    # TEST - card with workflow
    $test->fetch_card_info_ok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_id => $cfg{'t-wf-1'}{token}
        ],
        "Card with unblock WF",
    ) or croak $@;

    #$test->diag("Card with unblock WF - wfid=" . $test->get_wfid);
    #$test->diag("param workflows: " . Dumper($test->param('_workflows')));
    my @wfs_found
        = grep { not $_->{'WORKFLOW.WORKFLOW_STATE'} =~ /^(SUCCESS|FAILURE)$/ }
        map { @{$_} } map { values %{$_} } ( $test->param('_workflows') );
    my @wf_ids = map { $_->{'WORKFLOW.WORKFLOW_SERIAL'} } @wfs_found;

    # TEST
    $test->is( scalar @wf_ids,
        1, "Expect exactly one foreign workflow to be found" );

    my $id = join( ',', @wf_ids );

    # TEST - kill all workflows
    $test->kill_workflow_ok(
        [ $cfg{cm1}{name}, $cfg{cm1}{role}, $id ],
        "Kill unblock/pers workflow " . $id
    ) or $test->diag("Error killing workflow: $@");

    # TEST - card without workflow
    $test->fetch_card_info_ok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_id => $cfg{'t-wf-2'}{token}
        ],
        "Card without unblock WF",
    ) or croak $@;
    @wfs_found
        = grep { not $_->{'WORKFLOW.WORKFLOW_STATE'} =~ /^(SUCCESS|FAILURE)$/ }
        map { @{$_} } map { values %{$_} } ( $test->param('workflows') );
    @wf_ids = map { $_->{'WORKFLOW.WORKFLOW_SERIAL'} } @wfs_found;

    # TEST
    $test->is( scalar @wf_ids, 0, "Expect no foreign workflow to be found" );

}

############################################################
# Test Set - Modifications
#
# x modify user actually changes which user is assigned to card
# x modify status actually changes status of card
############################################################

SKIP: {

    $test->skip( "Mods", 8 ) unless $cfg{tests}{mods};

    # TEST
    #$test->modify_user_ok(
    #    [   $cfg{cm1}{name},
    #        $cfg{cm1}{role},
    #        $cfg{'t-mod-1'}{token},
    #        $cfg{'t-mod-1'}{ldap_cn},
    #    ],
    #    "Modify user to original name"
    #) or croak $@;

    # TEST
    $test->fetch_card_info_ok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_id => $cfg{'t-mod-1'}{token}
        ],
        "Check that user rec to be modified is in original state"
    ) or croak $@;

    # TEST - ensure that the record is what we expect
    $test->validate_card_info_ok( [ $cfg{'t-mod-1'} ],
        "Check attrs of original user" )
        or $test->diag($@);

## TEST - try assigning to unknown user
    #$test->fetch_card_info_ok(
    #    [   $cfg{cm1}{name},
    #        $cfg{cm1}{role},
    #        token_id => $cfg{'t-mod-1'}{token}
    #    ],
    #    "Fetch user for testing user assign"
    #) or croak $@;

    $test->execute(
        'scadm_modify_user',
        {   token_id => $cfg{'t-mod-1'}{token},
            new_user => $cfg{'t-mod-1'}{bogus_user}
        }
    );

    # TEST - check that the last execute "failed properly"
    $test->error_is(
        'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_ENTRY_NOT_FOUND',
        "assign card to unknown user should fail"
    ) or croak $@;

    # TEST
    $test->modify_user_ok(
        [   $cfg{cm1}{name},        $cfg{cm1}{role},
            $cfg{'t-mod-2'}{token}, $cfg{'t-mod-2'}{ldap_cn},
        ],
        "Modify user to new name"
    ) or croak $@;

    # TEST
    $test->fetch_card_info_ok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_id => $cfg{'t-mod-2'}{token}
        ],
        "Check that user rec to be modified is in new state"
    ) or croak $@;

    # TEST - Check that status gets modified to new status
    $test->modify_status_ok(
        [   $cfg{cm1}{name},        $cfg{cm1}{role},
            $cfg{'t-mod-2'}{token}, $cfg{'t-mod-2'}{smartcard_status},
        ],
    ) or croak $@ . ' - ' . $test->dump();

    # TEST - Confirm status
    $test->fetch_card_info_ok(
        [   $cfg{cm1}{name}, $cfg{cm1}{role},
            token_id => $cfg{'t-mod-2'}{token}
        ],
        "Retrieve new card status"
    ) or croak $@;

    # TEST
    $test->param_is(
        'smartcard_status',
        $cfg{'t-mod-2'}{smartcard_status},
        "Confirm new token status mod"
    );

## TEST - Change status back to orig
    #$test->modify_status_ok(
    #    [   $cfg{cm1}{name},
    #        $cfg{cm1}{role},
    #        $cfg{'token-modstat-orig'}{token},
    #        $cfg{'token-modstat-orig'}{smartcard_status},
    #    ],
    #) or croak $@ . ' - ' . $test->dump();

    # TEST - Confirm status
    #$test->fetch_card_info_ok(
    #    [   $cfg{cm1}{name},
    #        $cfg{cm1}{role},
    #        token_id => $cfg{'token-modstat-orig'}{token}
    #    ],
    #    "Retrieve new card status"
    #) or croak $@;

    # TEST
    #$test->param_is(
    #    'smartcard_status',
    #    $cfg{'token-modstat-orig'}{smartcard_status},
    #    "Confirm orig token status mod"
    #);

}

############################################################
# Test Set - Unblock Challenge
#
# - generate response for given card
############################################################

SKIP: {

    $test->skip( "Unblock Challenge", 5 ) unless $cfg{tests}{unblockchall};

    # TEST - Fetch cardadm workflow
    $test->get_unblock_response_ok(
        [   $cfg{cm1}{name},
            $cfg{cm1}{role},
            $cfg{'t-unblock-chall-1'}{token},
            $cfg{'t-unblock-chall-1'}{challenge},
        ],
        "Retrieve new card status for challenge with default puk"
    ) or warn $@;
#    $test->diag( "WFID: " . $test->get_wfid() );

    # TEST
    $test->param_is( 'unblock_response', $cfg{'t-unblock-chall-1'}{response},
              "Confirm unblock response for default puk: "
            . $cfg{'t-unblock-chall-1'}{challenge} . '/'
            . $cfg{'t-unblock-chall-1'}{response} );

    # TEST
    $test->puk_upload_ok(
        [   $cfg{cm1}{name},
            $cfg{cm1}{role},
            $cfg{'t-unblock-chall-2'}{token},
            $cfg{'t-unblock-chall-2'}{puk},
        ],
        "Setting puk for token 2"
    ) or croak $@;
#    $test->diag( "WFID: " . $test->get_wfid() );

    # TEST - Fetch cardadm workflow
    $test->get_unblock_response_ok(
        [   $cfg{cm1}{name},
            $cfg{cm1}{role},
            $cfg{'t-unblock-chall-2'}{token},
            $cfg{'t-unblock-chall-2'}{challenge},
        ],
        "Retrieve new card status for challenge with other puk"
    ) or warn $@;
#    $test->diag( "WFID: " . $test->get_wfid() );

    # TEST
    $test->param_is(
        'unblock_response',
        $cfg{'t-unblock-chall-2'}{response},
        "Confirm unblock response for challenge with other puk"
    );

}



#!/usr/bin/perl
#
# 02_cert_revoke.t - tests for soap-based cert revoke
#
# DEGUGGING: Set DEBUG_TEST env var to true for verbose output
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

use lib qw(     /usr/local/lib/perl5
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

my $debug = $ENV{DEBUG_TEST};

############################################################
# TEST FRAMEWORK
############################################################

# test() run a set of tests
# Named-parameters; id, description, tests, setup, teardown, plan
my $test_plan = 0;

sub test {
    my %args = @_;

    my $id    = $args{id}          || 'NO_ID';
    my $desc  = $args{description} || 'generic test';
    my $block = $args{tests}       || die "Error: test() - no tests set";
    my $plan  = $args{plan};

    if ($plan) {
        $test_plan += $plan;
    }

    print "\n----- $id - $desc \n";
    if ( ref( $args{setup} ) eq 'CODE' ) {
        $args{setup}->();
    }
    $block->();
    if ( ref( $args{teardown} ) eq 'CODE' ) {
        $args{teardown}->();
    }
}

############################################################
# CONFIGURATION
############################################################

my $dirname = dirname($0);

our @cfgpath =
  ( $dirname . '/../../../../config/tests/backend/smartcard', $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '02_cert_revoke.cfg', \%cfg, @cfgpath );

#$testcfg->load_ldap( '02_cert_revoke.ldif', @cfgpath );

# Check for missing config params
foreach my $ent (
    qw(
    core:set_2_names core:soap_proxy_uri
    certs:client_cert_file
    certs:client_key_file
    certs:trusted_ca_certs_dir
    )
  )
{
    my ( $a, $b ) = split( /:/, $ent, 2 );
    if ( not $cfg{$a}{$b} ) {
        die "Config missing param '$b' for section '$a'";
    }
}

my @set_2_names = split( /\s*[,;]\s*/, $cfg{core}{set_2_names} );

$ENV{http_proxy}  = "";
$ENV{https_proxy} = "";

$ENV{HTTPS_CA_DIR} = $cfg{certs}{trusted_ca_certs_dir};

if ( $cfg{core}{use_client_authentication} ) {
    $ENV{HTTPS_CERT_FILE} = $cfg{certs}{client_cert_file};
    $ENV{HTTPS_KEY_FILE}  = $cfg{certs}{client_key_file};
}

if ($debug) {
    diag( "HTTPS_CERT_FILE=", $ENV{HTTPS_CERT_FILE} );
    diag( "HTTPS_KEY_FILE=",  $ENV{HTTPS_KEY_FILE} );
    diag( "HTTPS_CA_DIR: " . $cfg{certs}{trusted_ca_certs_dir} );
    diag( "SOAP URI: " . $cfg{core}{soap_uri} );
    diag( "SOAP Proxy: " . $cfg{core}{soap_proxy_uri} );
}

my %params = ();
if ( $cfg{core}{soap_uri} ) {
    $params{uri} = $cfg{core}{soap_uri};
}
if ( $cfg{core}{soap_proxy_uri} ) {
    $params{proxy} = $cfg{core}{soap_proxy_uri};
}
my $server = SOAP::Lite->new(%params);
if ( not $server ) {
    die "Error creating new SOAP::Lite instance: $@";
}

############################################################
# RUN TESTS
############################################################

test(
    id          => 'SC_CR_01',
    description => 'Verify basic SOAP functionality',
    plan        => 3,
    tests       => sub {
        is( $server->true->result,        1,     'check true test' );
        is( $server->false->result,       0,     'check false test' );
        is( $server->echo('one')->result, 'one', 'check echo method' );
    },
);

test(
    id          => 'SC_CR_02',
    description => 'Tests for Cert Revoke',
    plan        => scalar(@set_2_names) * ( $cfg{core}{logfile} ? 2 : 1 ),
    tests       => sub {
        my $return;
        my $result;
        my $fault;
        my $token;

        # this is a poke at the crypto colleagues... ;-)
        # (this is just an informal, short-lived id)
        my @chars = ( 'a' .. 'f', 0 .. 9 );

        foreach my $name (@set_2_names) {
            my $reqid = join( '', @chars[ map { rand @chars } ( 1 .. 32 ) ] );

            $token  = $cfg{$name}{id};
            $return = $server->RevokeSmartcard( $token, $reqid );
            $result = $return->result();
#            $fault  = $return->faultstring();
            is( $result, $cfg{$name}{result}, "test result $name - $token" );
#            is( $fault,  $cfg{$name}{fault},  "test fault $name - $token" );

            if ( $cfg{core}{logfile} ) {
                my $FILE;
                my @log = ();
                open( $FILE, '<', $cfg{core}{logfile} )
                  or die "Error opening ", $cfg{core}{logfile}, ": $!";
                while (<$FILE>) {
                    if (m/SOAP CardRevoke reqid=([0-9a-fA-F]+): (.+)/) {
                        chomp;
                        push @log, $2 if $reqid eq $1;
                    }
                }
                is(
                    join( "\n", @log ),
                    $cfg{$name}{loginfo},
                    "test log $name - $token"
                );
            }
        }
    },
);

done_testing($test_plan);


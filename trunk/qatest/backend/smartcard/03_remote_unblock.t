#!/usr/bin/perl
#
# 03_remote_unblock.t - tests for smartcard remote unblock
#
# IMPORTANT:
# Set the environment variable DESTRUCTIVE_TESTS to a true value to
# have the LDAP data purged and loaded from the LDIF file.
#
# The test data is read from 03_remote_unblock.cfg, which has the
# following format:
#
#

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

our @cfgpath
    = ( $dirname . '/../../../../config/qatest/backend/smartcard', $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '03_remote_unblock.cfg', \%cfg, @cfgpath );

#my @test_ids = split( /\s*[,;]\s*/, $cfg{core}{test_ids} );

our $debug = 0;

package OpenXPKI::TestX::CardAdm;
use Moose;
extends 'OpenXPKI::Test::Smartcard::CardAdm';

sub setup {
    my $self = shift;
    $self->connect(
        user       => $cfg{user}{name},
        password   => $cfg{user}{role},
        socketfile => $self->socketfile,
        realm      => $self->realm
    ) or die "Need session to continue: $@";
}

sub request {
    my $self = shift;
    $self->fetch_card_info( $cfg{user}{name}, $cfg{user}{role}, @_ );
}

package main;

############################################################
# START TESTS
############################################################

Log::Log4perl->easy_init( { level => 'ERROR' } );

my $test = OpenXPKI::TestX::CardAdm->new(
    {   socketfile => $cfg{instance}{socketfile},
        realm      => $cfg{instance}{realm},
    }
) or die "error creating new test instance: $@";

#if ( not @test_ids ) {
#    die "No test IDs specified in configuration file";
#}
#
#$test->plan( tests => scalar @test_ids );

$test->group(
    reqid       => 'SC_RU_00',
    description => 'Verify test config data',
    setup       => undef,
    tests       => sub {
        my $errs = 0;
        foreach my $entry (qw( core:val1 core:val2 )) {
            my ( $a, $b ) = split( /:/, $entry, 2 );
            ok( exists $cfg{$a}{$b}, "Config section $a, param $b" )
                or $errs++;
        }
        die "ERROR: unable to continue with config errors" if $errs;

    },
    teardown => undef,
);

############################################################
# Test Set - ACL
#
# - user may not access wf
# - RA may start wf, fetch ldap, modify user, modify status, fail
#   workflow (implicit from other tests)
############################################################

SKIP: {
    $test->skip( "ACL", 1 ) unless $cfg{tests}{acl};

    $test->group(
        reqid       => 'FR_SC_RU_acl',
        description => 'ACLs',
        tests       => sub {
            my $self = shift;

            # TEST: 'User' role should not have permissions to create workflow
            $self->fetch_card_info_nok(
                [   $cfg{FR_SC_RU_acl}{name},
                    $cfg{FR_SC_RU_acl}{role},
                    token_id => $cfg{'t-acl'}{token}
                ],
                "Create workflow with role 'User'"
            ) or croak $@;
            $self->disconnect();
        },
        teardown => undef,
    );
}

SKIP: {
    $test->skip( "SC_RU_02", 1 ) unless $cfg{tests}{SC_RU_02};

    $test->group(
        reqid       => 'SC_RU_02',
        description => 'data entry - input must be case insensitive',
        tests       => sub {
            my $self = shift;
            $self->fetch_card_info_ok(
                [   $cfg{user}{name},
                    $cfg{user}{role},
                    token_owner => $cfg{'SC_RU_02'}{user1}
                ],
                "Create workflow with token for user '"
                    . $cfg{SC_RU_02}{user1} . "'",
            ) or croak $@;
            $self->diag( "WFID: " . $self->wfid() );
            $self->state_is( 'MAIN',
                'Confirm that regular request works a first time' );
            $self->user_abort();

            # Try a second time
            $self->fetch_card_info( $cfg{user}{name}, $cfg{user}{role},
                token_owner => $cfg{'SC_RU_02'}{user1} );

        #            $self->request( token_owner => $cfg{'SC_RU_O2'}{user1} );
            $self->diag( "WFID: " . $self->wfid() );
            $self->state_is( 'MAIN',
                'Confirm that regular request works a second time' );
            $self->user_abort();
            $self->state_is( 'FAILURE',
                'Confirm that second workflow is terminated' );

            # Try a third time
            $self->fetch_card_info( $cfg{user}{name}, $cfg{user}{role},
                token_owner => $cfg{'SC_RU_02'}{user1} );
            $self->diag( "WFID: " . $self->wfid() );
            $self->state_is( 'MAIN',
                'Confirm that regular request works a third time' );
            $self->user_abort();
            $self->state_is( 'FAILURE',
                'Confirm that third workflow is terminated' );

        },
        teardown => sub {
            my $self = shift;
            $self->disconnect();
        },
    );
}

SKIP: {
    $test->skip( "SC_RU_02.1", 1 ) unless $cfg{tests}{'SC_RU_02.1'};

    $test->group(
        reqid       => 'SC_RU_02.1',
        description => 'data entry - input with multiple cards',
        tests       => sub {
            my $self = shift;
            $self->fetch_card_info_nok(
                [   $cfg{user}{name},
                    $cfg{user}{role},
                    token_owner => $cfg{'SC_RU_02.1'}{user1}
                ],
                "Create workflow with token for user '"
                    . $cfg{'SC_RU_02.1'}{user1} . "'",
            );
            $self->diag( "WFID: " . $self->wfid() );
            $self->param_is(
                'error_code',
                'Multi Token IDs',
                'Confirm that multi-card detected correctly'
            );
            $self->state_is( 'FAILURE',
                'Confirm that multi-card detected correctly' );
        },
        teardown => sub {
            my $self = shift;
            $self->disconnect();
        },
    );
}

#$test->group(
#    reqid       => 'SC_RU_02.2',
#    description => 'data entry - entry of token_id must be case insensitive',
#    tests       => sub {
#        my $self = shift;
#        my ($tok);
#
#
#        $tok = $cfg{'SC_RU_02.2'}{token};
#        $self->fetch_card_info_ok(
#            [   $cfg{user}{name}, $cfg{user}{role},
#                token_id => $tok,
#            ],
#            "upper/lower - token_id='$tok'",
#        ) or $self->diag($@);
#        $self->user_abort();
#
#    }
#);

$test->group(
    reqid       => 'SC_RU_nn',
    description => 'Baseline assumption: Sanity Checks',
    setup       => sub { $_[0]->setup() },
    tests       => sub {
        my $self = shift;
        my ( $wfid, $msg );
        $self->fetch_card_info( $cfg{user}{name}, $cfg{user}{role},
            token_id => undef );
        $wfid = $self->wfid() || '<n/a>';
        $self->param_is(
            'error_code',
            'No Token Found',
            'confirm that no data was provided' . " (wfid=$wfid)"
        );
        $self->state_is( 'FAILURE',
            'Confirm WF state when token_id is undef' . " (wfid=$wfid)" );

        $self->fetch_card_info( $cfg{user}{name}, $cfg{user}{role},
            token_id => 'user@openxpki.org' );
        $msg = $self->msg();
        $wfid = $self->wfid() || '<n/a>';
        $self->is( $msg->{SERVICE_MSG}, 'ERROR',
            "SERVICE_MSG for using email address as token_id (wfid=$wfid)" );
        $self->is(
            $msg->{LIST}->[0]->{LABEL},
            'I18N_OPENXPKI_SERVER_API_INVALID_PARAMETER',
            "LABEL for using email address as token_id (wfid=$wfid)"
        );

        $self->fetch_card_info( $cfg{user}{name}, $cfg{user}{role},
            token_id => 'dead@beef' );
        $msg = $self->msg();
        $wfid = $self->wfid() || '<n/a>';
        $self->is( $msg->{SERVICE_MSG}, 'ERROR',
            "SERVICE_MSG for using 'dead beef' as token_id (wfid=$wfid)" );
        $self->is(
            $msg->{LIST}->[0]->{LABEL},
            'I18N_OPENXPKI_SERVER_API_INVALID_PARAMETER',
            "LABEL for using 'dead beef' as token_id (wfid=$wfid)"
        );
    },
    teardown => sub {
        my $self = shift;
        $self->disconnect();
    },
);

#$test->group(
#    reqid       => 'SC_RU_nn',
#    description => 'Application entry point',
#    setup       => sub { $_[0]->setup() },
#    tests       => sub {
#        my $self  = shift;
#        my $id    = $self->reqid();
#        my $test2 = OpenXPKI::TestX::CardAdm->new( user => 'Anonymous' );
#        is( $@, 'Error: access denied', 'fail if user not authed' );
#
#        $self->fetch_card_info( $cfg{user}{name}, $cfg{user}{role},
#            token_id => uc( $cfg{$id}{tokenid} ) );
#        ok( not $self->error, "request token_id " . $cfg{$id}{tokenid} );
#    },
#    teardown => undef,
#);

############################################################
# Test Set - Unblock Challenge
#
# - generate response for given card
############################################################

    $test->group(
        tests => sub {
            my $self = shift;

            # TEST - Fetch cardadm workflow
            $self->get_unblock_response_ok(
                [   $cfg{user}{name},
                    $cfg{user}{role},
                    $cfg{'t-unblock-chall-1'}{token},
                    $cfg{'t-unblock-chall-1'}{challenge},
                ],
                "Retrieve new card status for challenge with default puk"
            ) or warn $@;

            #    $self->diag( "WFID: " . $self->get_wfid() );

            # TEST
            $self->param_is(
                'unblock_response',
                $cfg{'t-unblock-chall-1'}{response},
                "Confirm unblock response for default puk: "
                    . $cfg{'t-unblock-chall-1'}{challenge} . '/'
                    . $cfg{'t-unblock-chall-1'}{response}
            );

            # TEST
            $self->puk_upload_ok(
                [   $cfg{cm1}{name},
                    $cfg{cm1}{role},
                    $cfg{'t-unblock-chall-2'}{token},
                    $cfg{'t-unblock-chall-2'}{puk},
                ],
                "Setting puk for token 2"
            ) or croak $@;

            #    $self->diag( "WFID: " . $self->get_wfid() );

            # TEST - Fetch cardadm workflow
            $self->get_unblock_response_ok(
                [   $cfg{cm1}{name},
                    $cfg{cm1}{role},
                    $cfg{'t-unblock-chall-2'}{token},
                    $cfg{'t-unblock-chall-2'}{challenge},
                ],
                "Retrieve new card status for challenge with other puk"
            ) or warn $@;

            #    $self->diag( "WFID: " . $self->get_wfid() );

            # TEST
            $self->param_is(
                'unblock_response',
                $cfg{'t-unblock-chall-2'}{response},
                "Confirm unblock response for challenge with other puk"
            );
        },
    );

$test->done_testing();

#!/usr/bin/perl
#
# 01_fetch_puk.t - tests for smartcard fetch puk
#
# The fetch puk workflow is used by CardSSO to get the PUK for the
# given token_id. ACLs or other validation shall ensure that only
# the current owner of the token is able to fetch the PUK.
#
# IMPORTANT:
# Set the environment variable DESTRUCTIVE_TESTS to a true value to
# have the LDAP data purged and loaded from the LDIF file.
#
# The test data is read from 01_fetch_puk.cfg, which has the
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

use OpenXPKI::Test::Smartcard::FetchPUK;
use OpenXPKI::Test::Smartcard::PUKUpload;

use TestCfg;

my $dirname = dirname($0);

our @cfgpath
    = ( $dirname . '/../../../../config/qatest/backend/smartcard', $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '01_fetch_puk.cfg', \%cfg, @cfgpath );

our $debug = 0;

package main;

############################################################
# START TESTS
############################################################

Log::Log4perl->easy_init( { level => 'ERROR' } );

my $test_pukupload = OpenXPKI::Test::Smartcard::PUKUpload->new(
    {   socketfile => $cfg{instance}{socketfile},
        realm      => $cfg{instance}{realm},
    }
) or die "error creating new PUKUpload instance: $@";

$test_pukupload->group(
    reqid       => 'SC_FP_00',
    description => 'PUK Upload',
    setup       => undef,
    tests       => sub {
        my $self     = shift;
        my $testsval = $cfg{pukupload}{tests};

        my @testnames = ();
        if ( ref($testsval) eq 'ARRAY' ) {
            @testnames = @{$testsval};
        }
        elsif ($testsval) {
            @testnames = split( /\s*,\s*/, $testsval );
        }
        foreach my $testname (@testnames) {
            if ( defined $cfg{$testname}{token_set_puk} ) {
                $self->puk_upload_ok(
                    [   $cfg{pukupload}{user},
                        $cfg{pukupload}{role},
                        $cfg{$testname}{token_id},
                        $cfg{$testname}{token_set_puk},
                    ],
                    "Setting PUK for token " . $cfg{$testname}{token_id}
                ) or croak $@;
            }
        }
    }
);

my $test = OpenXPKI::Test::Smartcard::FetchPUK->new(
    {   socketfile => $cfg{instance}{socketfile},
        realm      => $cfg{instance}{realm},
    }
) or die "error creating new test instance: $@";

$test->group(
    reqid       => 'SC_FP_01',
    description => 'Verify positive test case',
    setup       => undef,
    tests       => sub {
        my $self = shift;

        $self->fetch_puk_ok(
            [   $cfg{test_01}{user}, $cfg{test_01}{role},
                token_id => $cfg{test_01}{token_id}
            ],
            'Fetch PUK test_01'
        ) or $self->diag($@);

        $self->state_is( 'MAIN', 'State of test_01 is MAIN' )
            or $self->diag($@);

        my $puks = $self->array('_puk');

        #        $self->diag('$puks=' . $puks);

        $self->is(
            $puks->count(),
            $cfg{test_01}{token_puk_count},
            'Number of puks for test_01'
        );
        for ( my $i = 0; $i < $puks->count(); $i++ ) {
            $self->is(
                $puks->value($i),
                $cfg{test_01}{ 'token_puk_' . $i },
                "Value of puk $i for test_01"
            );
        }

        $self->ack_fetch_puk_ok( [ $cfg{test_01}{user}, $cfg{test_01}{role} ],
            'Ack fetch PUK test_01' )
            or $self->diag($@);

        $self->state_is( 'SUCCESS', 'State of test_01 is SUCCESS' )
            or $self->diag($@);
    }
);

$test->group(
    reqid       => 'SC_FP_02',
    description => 'Verify positive test case with nack',
    setup       => undef,
    tests       => sub {
        my $self = shift;

        my $error_reason = 'test nack';

        $self->fetch_puk_ok(
            [   $cfg{test_01}{user}, $cfg{test_01}{role},
                token_id => $cfg{test_01}{token_id}
            ],
            'Fetch PUK test_01'
        ) or $self->diag($@);

        $self->state_is( 'MAIN', 'State of test_01 is MAIN' )
            or $self->diag($@);

        my $puks = $self->array('_puk');

        #        $self->diag('$puks=' . $puks);

        $self->is(
            $puks->count(),
            $cfg{test_01}{token_puk_count},
            'Number of puks for test_01'
        );
        for ( my $i = 0; $i < $puks->count(); $i++ ) {
            $self->is(
                $puks->value($i),
                $cfg{test_01}{ 'token_puk_' . $i },
                "Value of puk $i for test_01"
            );
        }

        $self->nack_fetch_puk_ok(
            [   $cfg{test_01}{user}, $cfg{test_01}{role},
                error_reason => $error_reason
            ],
            'Nack fetch PUK test_01'
        ) or $self->diag($@);

        $self->state_is( 'FAILURE', 'State of test_01 is FAILURE' )
            or $self->diag($@);

        $self->param_is( 'error_reason', $error_reason );

    }
);

$test->group(
    reqid => 'SC_FP_03',
    description =>
        'WF hangs at INITIALIZED when the token_id is unknown',
    setup => undef,
    tests => sub {
        my $self = shift;

        $self->fetch_puk_nok(
            [   $cfg{test_03}{user}, $cfg{test_03}{role},
                token_id => $cfg{test_03}{token_id}
            ],
            'Fetch PUK test_03'
        ) or $self->diag($@);

        $self->state_is( 'INITIALIZED', 'State of test_03 is INITIALIZED' )
            or $self->diag($@);

    }
);

$test->group(
    reqid       => 'SC_FP_04',
    description => 'Fail when workflow creator differs from token owner',
    setup       => undef,
    tests       => sub {
        my $self = shift;

        $self->fetch_puk_ok(
            [   $cfg{test_04}{user}, $cfg{test_04}{role},
                token_id => $cfg{test_04}{token_id}
            ],
            'Fetch PUK test_04'
        ) or $self->diag($@);

        $self->state_is( 'FAILURE', 'State of test_04 is FAILURE' )
            or $self->diag($@);

        my $puks = $self->array('_puk');

        #        $self->diag('$puks=' . $puks);

        $self->is(
            $puks->count(),
            $cfg{test_04}{token_puk_count},
            'Number of puks for test_04'
        );
        for ( my $i = 0; $i < $puks->count(); $i++ ) {
            $self->is(
                $puks->value($i),
                $cfg{test_01}{ 'token_puk_' . $i },
                "Value of puk $i for test_04"
            );
        }

    }
);


done_testing();


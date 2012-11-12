# --perl--
#
# This script tests the Enrollment Workflow definitions.
#
# Of course, it uses some JPFM to try to handle the tests. Basically,
# each of the inputs is a boolean flag. Then, we iterate through ALL
# possibilities by using an integer from 0 to 2 ** number_of_flags
# and using the integer as a bitmask.
#
# To confirm that the result is correct for the given input, the
# list of rules is compared, as well. This means that each rule
# will be checked for the integer value where the relevant flags
# are set. All other flags are ignored, and this is checked, too.
#
# Because this script tests the workflow XML itself, it feeds in it's
# own flags as input and all conditions that normally access OpenXPKI
# condition classes are mocked to check these flags directly. This
# ensures that the logic in the XML itself is correct.
#
# Note: this uses the workflow directly and NOT the OpenXPKI API.
#
# RUNNING THIS SCRIPT
#
# By default, this script just runs through the tests and tries _all_
# possible iterations for the input flags. This results in quite a few
# tests.
#
# To test specific flag combinations, use the FLAGS environment variable
# and specify exactly which values should be tested:
#
#   FLAGS="8187,8191" perl t/60_workflow/36_enrollment.t
#
# To check for tests resulting in SUCCESS that have no rule for the case,
# set CHECK_FALSE_OK to a true value:
#
#   CHECK_FALSE_OK=1 perl t/60_workflow/36_enrollment.t
#
# vim: syntax=perl
#
# This testing works on the following flags:
#
# num_active_certs
# p_max_active_certs
# in_renew_window
#
# ABOUT THE WORKFLOW FLAGS
#
# The Perl classes used by the Conditions, Actions, etc. do useful
# things like check that the transaction id is valid. To simplify
# testing the logic of the workflow, these flags are passed via the
# optional parameters with the prefix 'f_'.
#

use strict;
use warnings;

use Test::More;
use vars qw( $cfgbase );
use Data::Dumper;

require Workflow::Factory;
require Workflow::Persister::DBI;

# base name used to find config files
BEGIN {
    $cfgbase = $0;
    $cfgbase =~ s/\.t$/.d/;
    $cfgbase =~ s/\.t-(\d+)-of-(\d+)$/.d/;
}

eval { use lib ( $cfgbase . '/mocklib' ) };

my $debug                = $ENV{TEST_DEBUG}         || 0;
my $show_ok_with_no_rule = $ENV{CHECK_FALSE_OK}     || 0;
my $xmldir               = $ENV{TEST_ENROLL_XMLDIR} || $cfgbase;

my $LOG_FILE  = 'workflow_tests.log';
my $CONF_FILE = $cfgbase . '/log4perl.conf';

require Log::Log4perl;
if ($debug) {
    if ( -f $LOG_FILE ) {
        unlink($LOG_FILE);
    }
    Log::Log4perl::init($CONF_FILE);
}

my $wf_namespace = 'enroll_';

# This is just a shortcut for use in all but the initial
# rules to specify that the request is valid.
my @valid_flags = (
    f_valid_csr            => 1,
    f_valid_scep_tid       => 1,
    signer_signature_valid => 1,    # true when cert crypto is OK
    signer_validity_ok   => 1,    # true when within validity dates
    scep_uniq_id_ok   => 1,   # true when serialize of unique id is ok
);

# fields that we pass to Initialize that are actually passed as flags
# for this testing routine.
my @mock_fields = qw( _pkcs7 pkcs10 scep_tid signer_cert );

my @rules = (

    ##################################################
    # Confirm that invalid requests fail
    # (All other sections will include these flags
    # set to 'true')
    ##################################################
    {   text  => 'fail if csr invalid',
        flags => { f_valid_csr => 0, },
        state => 'FAILURE',
    },
    {   text  => 'fail if transaction id invalid',
        flags => { f_valid_scep_tid => 0, },
        state => 'FAILURE',
    },
    {   text  => 'fail if signature crypt invalid',
        flags => { signer_signature_valid => 0, },
        state => 'FAILURE',
    },
    {   text   => 'fail if signer cert validity NOK',
        policy => { p_allow_expired_signer => 0, },
        flags  => { signer_validity_ok => 0, },
        state  => 'FAILURE',
    },
    {   text   => 'fail if serialize of uniq id NOK',
        flags  => { scep_uniq_id_ok => 0, },
        state  => 'FAILURE',
    },

    ##################################################
    # Initial Enrollment
    #
    # Note: the rules for initial enrollment MUST have
    # the flag num_active_certs set to 0, otherwise
    # it is a renewal.
    ##################################################
    {   text  => 'init enroll: untrusted',
        flags => {
            @valid_flags,
            num_active_certs  => 0,
            signer_trusted  => 0,
            signer_on_behalf  => 0,
            valid_chall_pass  => 0,
            valid_kerb_authen => 0,
            num_manual_authen => 0,
        },
        state => 'FAILURE',
    },

    {   text  => 'init enroll: chall pass',
        flags => {
            @valid_flags,
            num_active_certs            => 0,
            valid_chall_pass            => 1,
            eligible_for_initial_enroll => 1,
            signer_trusted            => 0,
            signer_sn_matches_csr       => 1,
            have_all_approvals => 1,
        },
        state => 'SUCCESS',
    },

    {   text  => 'init enroll: kerberos',
        flags => {
            @valid_flags,
            num_active_certs            => 0,
            valid_kerb_authen           => 1,
            eligible_for_initial_enroll => 1,
            signer_trusted            => 0,
            signer_sn_matches_csr       => 1,
            have_all_approvals => 1,
        },
        state => 'SUCCESS',
    },

    {   text  => 'init enroll: manual authen',
        flags => {
            @valid_flags,
            num_active_certs            => 0,
            num_manual_authen           => 1,
            eligible_for_initial_enroll => 1,
            signer_trusted            => 0,
            signer_sn_matches_csr       => 1,
            have_all_approvals => 1,
        },
        state => 'SUCCESS',
    },

    {   text  => 'init enroll: on behalf',
        flags => {
            @valid_flags,
            num_active_certs            => 0,
            signer_on_behalf            => 1,
            signer_trusted            => 1,
            signer_sn_matches_csr       => 0,
            eligible_for_initial_enroll => 1,
            have_all_approvals => 1,

        },
        state => 'SUCCESS',
    },

    {   text  => 'init enroll: allow anon enroll',
        flags => {
            @valid_flags,
            num_active_certs            => 0,
            eligible_for_initial_enroll => 1,
            signer_trusted            => 0,
            signer_sn_matches_csr       => 1,
            have_all_approvals => 1,
        },
        policy => { p_allow_anon_enroll => 1, },
        state  => 'SUCCESS',
    },

    ##################################################
    # Renewal of Existing Certificate
    #
    # Note: If the client tries to renew a cert
    # with an expired/revoked signature cert, the
    # condition is caught above in the 'validation'
    # checks.
    ##################################################
    {   text => 'renewal: untrusted',
        flags =>
            { @valid_flags, signer_trusted => 0, num_active_certs => 1, },
        state => 'FAILURE',
    },
    {   text  => 'renewal: on behalf',
        flags => {
            @valid_flags,
            signer_sn_matches_csr => 0,
            num_active_certs      => 1,
        },
        state => 'FAILURE',
    },

    # This case should actually be caught above in the
    # validity test
    {   text  => 'renewal: expired cert',
        flags => {
            @valid_flags,
            signer_trusted      => 1,
            signer_sn_matches_csr => 1,
            num_active_certs      => 1,
            signer_validity_ok  => 0,
        },
        state => 'FAILURE',
    },
    {   text  => 'renewal: outside window',
        flags => {
            @valid_flags,
            signer_trusted      => 1,
            signer_sn_matches_csr => 1,
            num_active_certs      => 1,
            in_renew_window       => 0,
        },
        state => 'FAILURE',
    },

    {   text  => 'renewal: self-sign',
        flags => {
            @valid_flags,
            signer_trusted      => 0,
            valid_chall_pass      => 1,
            signer_sn_matches_csr => 1,
            num_active_certs      => 1,
            in_renew_window       => 1,
            eligible_for_renewal  => 1,
        },
        state => 'FAILURE',
    },

    {   text  => 'renewal: trusted cert deleted',
        flags => {
            @valid_flags,
            signer_trusted      => 1,
            signer_sn_matches_csr => 1,
            num_active_certs      => 0,
            in_renew_window       => 1,
            eligible_for_renewal  => 1,
        },
        state => 'FAILURE',
    },

    {   text  => 'don\'t have all approvals',
        flags => {
            @valid_flags,
            have_all_approvals      => 0,
        },
        state => 'FAILURE',
    },


    {   text  => 'renewal: correct',
        flags => {
            @valid_flags,
            signer_trusted      => 1,
            signer_sn_matches_csr => 1,
            num_active_certs      => 1,
            in_renew_window       => 1,
            eligible_for_renewal  => 1,
            have_all_approvals => 1,
        },
        state => 'SUCCESS',
    },

);

my @policies = (
    {   name   => 'generic device ca',
        params => {
            p_allow_anon_enroll => 0,
            p_allow_man_authen  => 0,
            p_max_active_certs  => 1,
        },
    },
);

# the number of flags defines the number of tests ( 2 ** $num_flags )
# to run
my %flags = ();
foreach my $ent (@rules) {
    foreach my $f ( keys %{ $ent->{flags} } ) {
        $flags{$f}++;
    }
}
my @flags = sort keys %flags;

# reset %flags so the value is the index
{
    my $i = 0;
    %flags = map { $_, $i++ } @flags;
}

# figure out masks for each rule
foreach my $rule (@rules) {
    my $mask1 = 0;
    my $mask0 = 0;

    foreach my $flag ( keys %{ $rule->{flags} } ) {
        if ( $rule->{flags}->{$flag} ) {
            $mask1 += 2**$flags{$flag};
        }
        elsif ( defined $rule->{flags}->{$flag} ) {
            $mask0 += 2**$flags{$flag};
        }
    }
    $rule->{mask1} = $mask1;
    $rule->{mask0} = $mask0;
}

my $bits = scalar(@flags);

# This little snippet causes a CSV output of the rules for importing into
# Excel or Pages
if ( $ARGV[0] && lc( $ARGV[0] ) eq 'csv' ) {
    my @grid = ();

    @grid = map { [$_] } '', @flags, 'State';

    foreach my $rule (

        #        reverse
        sort {
                   ( $a->{mask1} <=> $b->{mask1} )
                or ( $a->{mask0} <=> $b->{mask0} )
        } @rules
        )
    {
        my $text = $rule->{text} || '';
        $text =~ s/\\/\\\\/g;
        $text =~ s/"/\\"/g;

        $grid[0] ||= [];
        push @{ $grid[0] }, $text;

        for ( my $i = 0; $i < $bits; $i++ ) {
            $grid[ $i + 1 ] ||= [];
            if ( exists $rule->{flags}->{ $flags[$i] } ) {
                push @{ $grid[ $i + 1 ] },
                    $rule->{flags}->{ $flags[$i] } ? 'yes' : 'no';
            }
            else {
                push @{ $grid[ $i + 1 ] }, ' ';
            }
        }
        push @{ $grid[ $bits + 1 ] }, $rule->{state};

    }
    foreach my $row (@grid) {
        print '"', join( '","', @{$row} ), '"', "\n";
    }
    exit;
}

warn "# bits of happiness: $bits\n";
#plan tests => 21;

my $workflow_conf  = $xmldir . '/workflow_def_enrollment.xml';
my $action_conf    = $xmldir . '/workflow_activity_enrollment.xml';
my $condition_conf = $xmldir . '/workflow_condition_enrollment.xml';
my $validator_conf = $xmldir . '/workflow_validator_enrollment.xml';

my $factory = Workflow::Factory->instance;

my @persisters = (
    {   name  => 'OpenXPKI',
        class => 'Workflow::Persister::DBI',
        dsn   => 'DBI:Mock:',
        user  => 'DBTester',
    }
);

diag("add mock persister") if $debug;
$factory->add_config( persister => \@persisters, );

diag("add workflow, action, condition") if $debug;
diag("  workflow conf: $workflow_conf") if $debug;
$factory->add_config_from_file(
    workflow  => $workflow_conf,
    action    => $action_conf,
    condition => $condition_conf,
);

# NAME: run_flagtest( POLICY, FLAGVAL );
sub run_flagtest {
    my $policy  = shift;
    my $flagval = shift;

    # figure out flags to set
    my $args = {};
    for ( my $j = 0; $j < $bits; $j++ ) {
        if ( ( 2**$j ) & ($flagval) ) {
            $args->{ $flags[$j] } = 1;
        }
        else {
            $args->{ $flags[$j] } = 0;
        }
    }

    #    print '$args: ', Dumper($args), "\n";

    ############################################################
    # !! run actual test with workflow here !!
    # for now, though, we mock the result
    ############################################################
    # Instantiate a new workflow...
    my $workflow
        = $factory->create_workflow('I18N_OPENXPKI_WF_TYPE_ENROLLMENT');
    my $context = $workflow->context();

    #        diag( "    Workflow ID: ", $workflow->id() )    if $debug > 3;
    #        diag( " Workflow State: ", $workflow->state() ) if $debug > 3;

    ## Pass initial vars
    #foreach my $arg (
    #    qw( signature_ok scep_tid csr pki_operation signer_cert blah )
    #    )
    #{
    #    $context->param( $arg, 'dummy' );
    #}

    # pass the mock data to the initialize (required fields that we mock
    # with the flags below)
    foreach my $arg (@mock_fields) {
        $context->param( $arg, 1 );
    }

    # Set default policy
    foreach my $p ( keys %{ $policy->{params} } ) {
        $context->param( $p, $policy->{params}->{$p} );
    }

    # Add our mock_test parameters
    foreach my $arg ( keys %{$args} ) {

       #            diag( "Adding '$arg' to context [" . $args->{$arg} . "]" )
       #                if $debug > 4;
        $context->param( $arg, $args->{$arg} );
    }

    # Add context params that are based on the flags to be set
    if ( $args->{f_valid_csr} ) {
        $context->param( cert_subject => 'Test Subject' );
    }

    # Then execute it and see what happens
    $workflow->execute_action( $wf_namespace . 'initialize' );

    my $end_state = $workflow->state();

    ############################################################
    # Check that result is correct for each rule
    ############################################################
    my $errs             = 0;
    my $oks              = 0;
    my $found_rule_match = 0;

    foreach my $rule (@rules) {

        # Filter out rules where the policy doesn't match
        if ( ref( $rule->{policy} ) eq 'HASH' ) {
            my $skip_rule = 0;
            foreach my $pname ( keys %{ $rule->{policy} } ) {
                my $p1 = $policy->{$pname}         || 0;    # if undef, then 0
                my $p2 = $rule->{policy}->{$pname} || 0;    # if undef, then 0

                if ( $p1 != $p2 ) {

           #                    diag( "Skip case because of policy '$pname': "
           #                            . $rule->{text} )
           #                        if $debug;
                    $skip_rule++;
                    last;
                }
            }
            next if $skip_rule;
        }

        if (    ( ( $rule->{mask1} & $flagval ) == $rule->{mask1} )
            and ( !( $rule->{mask0} & $flagval ) ) )
        {
            $found_rule_match++;

            if (
                is( $end_state, $rule->{state},
                    '[Flags=' . $flagval . '] ' . $rule->{text}
                )
            ) {
                $oks++;
            }
            else {
                ;
                
                $errs++;
                diag( "    WFID: ", $workflow->id() );
                diag( " CONTEXT: ", Dumper($context) ) if $debug >= 2;
                diag( "    ARGS: ", Dumper($args) ) if $debug >= 2;
                diag( "   FLAGS: ", Dumper( $rule->{flags} ) )
                    if $debug >= 2;
                diag( "       I: ", $flagval )       if $debug >= 2;
                diag( "   MASK0: ", $rule->{mask0} ) if $debug >= 2;
                diag( "   MASK1: ", $rule->{mask1} ) if $debug >= 2;

            }
        }
    }

    if ($show_ok_with_no_rule) {
        if ( not $found_rule_match ) {
            if (not is(
                    $end_state, 'FAILURE',
                    "Test with flags $flagval and no rule should fail"
                )
                )
            {
                diag( "    ARGS: ", Dumper($args) );
            }
        }
    }

   # print a little diag message to translate the input value into flag values

    if ($errs) {
        diag(
            "Input Args: ",
            join( ', ',
                map { $_ . ' => ' . $args->{$_} }
                    reverse sort keys %{$args} )
        );
    }
}

my $total_iterations = 0;

my ($j_index, $j_size) = (0,0);

if ( $0 =~ m/\.t-(\d+)-of-(\d+)/ ) {
    $j_index = $1;
    $j_size = $2;
}

foreach my $policy (@policies) {
    diag( "Testing for policy'" . ( $policy->{name} || '<unnamed>' ) . "'" )
        if $debug;

    if ( exists $ENV{FLAGS} ) {
        foreach my $v ( split( /,/, $ENV{FLAGS} ) ) {
            $total_iterations++;
            run_flagtest( $policy, $v );
        }
    }
    elsif ( $j_size ) {
        my $max = 2**$bits;
        my $chunk_size = int(($max + 1) / $j_size);
        my $start = $chunk_size * ($j_index - 1);
        my $end = ($chunk_size * $j_index) - 1;
        diag("Running iterations $start ... $end\n");

        for ( my $i = $start; $i < $end; $i++ ) {
            $total_iterations++;
            run_flagtest( $policy, $i );
        }
    }

    else {
        for ( my $i = 0; $i < ( 2**$bits ); $i++ ) {
            $total_iterations++;
            run_flagtest( $policy, $i );
        }
    }
}

done_testing;
diag("Ran $total_iterations iteration(s)");

0;


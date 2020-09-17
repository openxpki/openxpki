#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Test::More tests => 4;
use FindBin qw( $Bin );
use File::Temp qw( tempdir );

# CPAN modules
use Test::Deep;
use CGI::Session;

# Project modules
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;
use MockUI;


my $SESSION_DIR = tempdir( CLEANUP => 1 );

my $TESTS = [
    {
        field => {
            type => 'cert_identifier',
            template => "[% USE Certificate %][% value %]<br/>[% Certificate.body(value, 'subject') %]",
        },
        init => sub { shift->insert_testcerts(only => [ 'democa-alice-2' ]) },
        value => sub { shift->certhelper_database->cert('democa-alice-2')->id },
        expected => sub {
            my $cert = shift->certhelper_database->cert('democa-alice-2');
            return {
                format => 'link',
                value => superhashof({
                    label => re($cert->id . '.*' . $cert->db->{subject}),
                }),
            };
        },
    }
];

###############################################################################
###############################################################################

my $known_workflows = {};
sub make_wf_config {
    my ($field_conf) = @_;

    my $wf_type = {};
    do { $wf_type = "testwf".int(rand(2**32)) } while ($known_workflows->{$wf_type});
    $known_workflows->{$wf_type} = 1;

    return {
        type => $wf_type,
        def => {
            "realm.democa.workflow.def.$wf_type" => '
                head:
                    prefix: '.$wf_type.'
                    persister: OpenXPKI
                state:
                    INITIAL:
                        action:
                            - process > SUCCESS
                    SUCCESS:
                        output:
                            - testfield
                action:
                    process:
                        class: OpenXPKI::Server::Workflow::Activity::Noop
                        input:
                            - testfield

                acl:
                    RA Operator:
                        creator: any
            ',
            "realm.democa.workflow.def.$wf_type.field.testfield" => {
                name => 'testfield',
                %{ $field_conf },
            },
        },
    };
}

sub ui_client {
    my ($oxitest) = @_;

    require_ok( 'OpenXPKI::Client::UI' );

    my $session = new CGI::Session(undef, undef, { Directory => $SESSION_DIR });

    my $result;
    my $client = MockUI->new({
        session => $session,
        logger => CTX('log')->system,
        config => { socket => $oxitest->get_config('system.server.socket_file') },
    });

    $client->update_rtoken();

    #
    # Login
    #
    $result = $client->mock_request({ page => 'login' });
    is $result->{main}->[0]->{action}, 'login!password', 'Login form';

    $result = $client->mock_request({
        'action' => 'login!password',
        'username' => 'raop',
        'password' => 'openxpki'
    });
    is $result->{goto}, 'redirect!welcome', 'Login successful';

    $client->update_rtoken();

    return $client;
}

sub maybe_call {
    my ($oxitest, $value) = @_;
    return ref $value eq 'CODE' ? $value->($oxitest) : $value;
}

sub run_tests {
    my ($oxitest, $client, $tests) = @_;

    my $result;
    #
    # Create workflow
    #
    for my $test (@$tests) {
        my $testname = join ", ", map { sprintf "%s '%s'", $_, $test->{field}->{$_} } grep { $test->{field}->{$_} } qw( type format );

        subtest "rendering of field $testname" => sub {
            $result = $client->mock_request({
                'page' => 'workflow!index!wf_type!' . $test->{wf_type},
            });

            #is $result->{page}->{label}, 'testwf_process', 'Workflow parameter input page';

            $result = $client->mock_request({
                'action' => 'workflow!index',
                'testfield' => maybe_call($oxitest, $test->{value}),
                'wf_token' => undef,
            });

            #like $result->{goto}, qr/workflow!load!wf_id!\d+/, 'Got redirect';

            $result = $client->mock_request({
                'page' => $result->{goto},
            });

            my $rendered = $result->{main}->[0]->{content}->{data}->[0];
            cmp_deeply $rendered, superhashof(maybe_call($oxitest, $test->{expected})), "matches expected value"
                or diag explain $rendered;
        };
    }
}

###############################################################################
###############################################################################

my $wf_defs = {};
my @tests_extended;
my @init;

for my $test (@$TESTS) {
    # add init code
    push @init, $test->{init} if $test->{init};

    # add workflow definition
    my $conf = make_wf_config($test->{field});
    $wf_defs->{$_} = $conf->{def}->{$_} for keys %{ $conf->{def} };

    # add 'wf_type' to existing test data
    push @tests_extended, {
        %$test,
        wf_type => $conf->{type},
    };
}

#diag explain $wf_defs;
my $oxitest = OpenXPKI::Test->new(
    with => [ "SampleConfig", "Server", "Workflows" ],
    also_init => "crypto_layer",
    add_config => $wf_defs,
);

# test dependent initializations
$_->($oxitest) for @init;

# create UI client
my $client = ui_client($oxitest);

# tests
run_tests($oxitest, $client, \@tests_extended);

# shutdown
$oxitest->stop_server;
$oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => [ map { $_->{wf_type} } @tests_extended ] });



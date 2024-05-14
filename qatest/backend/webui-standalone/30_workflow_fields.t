#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Test::More;
use FindBin qw( $Bin );
use File::Temp qw( tempdir );

# CPAN modules
use Test::Deep ':v1';
use CGI::Session;

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Client::UI::Workflow'} = 100;

# Project modules
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;
use MockUI;


my $SESSION_DIR = tempdir( CLEANUP => 1 );

my $TESTS = [
    #
    # headings
    #
    {
        field => { format => 'spacer' },
        expected => {
            format => 'head',
            className => 'spacer',
        },
    },

    #
    # format auto-detection
    #
    {
        field => { name => 'pkcs10' },
        value => "dummy",
        expected => {
            format => 'code',
            value => 'dummy',
        },
    },

    {
        field => { type => 'textarea' },
        value => "one\ntwo",
        expected => {
            format => 'nl2br',
            value => "one\ntwo",
        },
    },

    # fixed hash value -> deflist
    {
        field => { value => { one => 1, two => 2 } },
        expected => {
            format => 'deflist',
            value => [ { label => 'one', value => '1' }, { label => 'two', value => '2' } ],
        },
    },

    # fixed array value -> ullist
    {
        field => { value => [ qw( one two ) ] },
        expected => {
            format => 'ullist',
            value => [ qw( one two ) ],
        },
    },

    #
    # Specific formats
    #

    # cert_identifier
    {
        field => {
            type => 'cert_identifier',
            template => '[% USE Certificate %][% value %]<br/>[% Certificate.body(value, "subject") %]',
        },
        value => sub { shift->certhelper_database->cert('democa-alice-2')->id },
        expected => sub {
            my ($oxitest, $value) = @_;
            my $cert = $oxitest->certhelper_database->cert_by_id($value);
            return {
                format => 'link',
                value => superhashof({
                    label => re($cert->id . '.*' . $cert->db->{subject}),
                }),
            };
        },
    },

    #
    # templates generating YAML
    #
    {
        field => {
            format => 'linklist',
            max => 2, # flags the field as "clonable" so backend accepts two input values
            yaml_template => '
              [% USE Certificate %]
              [% IF value %]
                [% FOREACH identifier = value %]
                 - label: "[% Certificate.notafter(identifier) %] / [% identifier %]"
                   page: "#link!to!id![% identifier %]"
                [% END %]
              [% END %]
            ',
        },
        value => sub {
            my $oxitest = shift;
            return [
                $oxitest->certhelper_database->cert('democa-alice-2')->id,
                $oxitest->certhelper_database->cert('democa-signer-2')->id,
            ];
        },
        expected => sub {
            my ($oxitest, $value) = @_;
            return {
                format => 'linklist',
                value => [
                    map { { label => re(qr{.* / $_}), page => "#link!to!id!$_" } } @$value
                ],
            };
        },
    },

];

plan tests => 4 + 2 * scalar(@$TESTS);

###############################################################################
###############################################################################

sub init_oxitest {
    my $oxitest = shift;
    $oxitest->insert_testcerts(only => [ 'democa-signer-2', 'democa-alice-2' ]);
}

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
                name => 'testfield', # may be overwritten by $field_conf
                %{ $field_conf },
            },
        },
    };
}

sub ui_client {
    my ($oxitest) = @_;

    require_ok( 'OpenXPKI::Client::UI' );

    my $session = CGI::Session->new(undef, undef, { Directory => $SESSION_DIR });

    my $result;
    my $client = MockUI->new(
        session => $session,
        logger => CTX('log')->system,
        config => { socket => $oxitest->get_conf('system.server.socket_file') },
    );

    $client->update_rtoken();

    $result = $client->mock_request({
        page => 'login',
    });
    is $result->{main}->[0]->{action}, 'login!realm', 'Login - realm selection'
      or diag explain $result;

    $result = $client->mock_request({
        'action' => 'login!realm',
        'pki_realm' => 'democa',
    });
    is $result->{main}->[0]->{action}, 'login!password', 'Login - password entry'
      or diag explain $result;

    $result = $client->mock_request({
        'action' => 'login!password',
        'username' => 'raop',
        'password' => 'openxpki'
    });
    is $result->{goto}, 'redirect!welcome', 'Login successful'
      or diag explain $result;

    $client->update_rtoken();

    return $client;
}

sub run_tests {
    my ($oxitest, $client, $tests) = @_;

    my $result;
    #
    # Create workflow
    #
    for my $json_request (qw (0 1)) {
        for my $test (@$tests) {
            my $testname = join ", ", map { sprintf "%s='%s'", $_, $test->{field}->{$_} } grep { $test->{field}->{$_} } qw( type format name );
            if (not $testname and my $ref = ref($test->{field}->{value} // '')) {
                $testname = "$ref value";
            }
            subtest sprintf('render %s (%s data)', $testname, $json_request ? 'JSON' : 'form') => sub {
                # start workflow
                $result = $client->mock_request({
                    page => 'workflow!index!wf_type!' . $test->{wf_type},
                });
                is $result->{main}->[0]->{content}->{submit_label}, 'I18N_OPENXPKI_UI_WORKFLOW_SUBMIT_BUTTON', 'Workflow parameter input page'
                  or diag explain $result;

                # send input parameter / run action
                my $fieldname = $test->{field}->{name} // 'testfield';
                my $value = ref $test->{value} eq 'CODE' ? $test->{value}->($oxitest) : $test->{value};

                my $params = {
                    action => 'workflow!index',
                    defined $value ? ( $fieldname => $value ) : (),
                    wf_token => undef,
                };

                $result = $json_request ? $client->mock_json_request($params) : $client->mock_request($params);

                if ($result->{goto}) {
                    note 'Received redirect instruction';
                    $result = $client->mock_request({
                        page => $result->{goto},
                    });
                }

                my $rendered = $result->{main}->[0]->{content}->{data}->[0];
                my $expected = ref $test->{expected} eq 'CODE' ? $test->{expected}->($oxitest, $value) : $test->{expected};

                cmp_deeply $rendered, superhashof($expected), "matches expected value"
                    or diag explain $result;
            };
        }
    }
}

###############################################################################
###############################################################################

my $wf_defs = {};
my @tests_extended;

for my $test (@$TESTS) {
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
    # log_level => 'TRACE',
    # log_class => qr/^OpenXPKI::Client::UI::Request/,
);

# test dependent initializations
init_oxitest($oxitest);

# create UI client
my $client = ui_client($oxitest);

# tests
run_tests($oxitest, $client, \@tests_extended);

# shutdown
$oxitest->stop_server;
$oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => [ map { $_->{wf_type} } @tests_extended ] });



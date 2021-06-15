#!/usr/bin/env perl
#
# Tests the API call 'delete_workflow'
#
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use Try::Tiny;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


try {
    require OpenXPKI::Server::Workflow::Persister::Archiver;
    plan tests => 3;
}
catch {
    plan skip_all => "persister 'Archiver' no available";
};


my $wf_type = "testworkflow".int(rand(2**32));
my $wf_standard = "${wf_type}a";
my $wf_archiver = "${wf_type}b";

#
# Setup test context
#

sub wf_def {
    my %args = @_;
    my $prefix = $args{prefix};
    my $persister = $args{persister} // 'OpenXPKI';
    return ("
        head:
            prefix: $prefix
            persister: $persister

        state:
            INITIAL:
                action: step1 > SUCCESS

            SUCCESS:

        action:
            step1:
                class: OpenXPKI::Server::Workflow::Activity::Noop

        acl:
            MyFairyKing:
                creator: any
                delete: 1

            Liar:
                creator: any
    ");
}

sub create_wf {
    my $wf_type = shift;
    my $result;

    # create workflow (auto-executes 'step1')
    lives_and {
        $result = CTX('api2')->create_workflow_instance(workflow => $wf_type);
        ok ref $result;
    } "create workflow" or die("Could not create workflow");

    my $wf_info = $result->{workflow};
    my $wf_id = $wf_info->{id} or die('Workflow ID not found');

    # get_workflow_info - check 'archive_at'
    lives_and {
        $result = CTX('api2')->get_workflow_info(id => $wf_id);
        cmp_deeply $result->{workflow}, superhashof( {
            'proc_state' => 'finished', # could be 'exception' if things go wrong
            'state' => 'SUCCESS',
        } );
    } "fetch info" or diag explain $result;

    return $wf_id;
}



my $oxitest = OpenXPKI::Test->new(
    with => [ qw( Workflows ) ],
    start_watchdog => 1,
    add_config => {
        "realm.test.workflow.persister.Archiver" => "
            class: OpenXPKI::Server::Workflow::Persister::Archiver
        ",

        "realm.test.workflow.def.$wf_standard" => wf_def(prefix => $wf_standard),
        "realm.test.workflow.def.$wf_archiver" => wf_def(prefix => $wf_archiver, persister => 'Archiver'),
    },
);

my @ids;

subtest "attempt to delete workflow without persister implementation" => sub {
    $oxitest->session->data->role("MyFairyKing");
    my $wf_id = create_wf($wf_standard);
    push @ids, $wf_id;
    throws_ok { CTX('api2')->delete_workflow(id => $wf_id) } qr/support.*deletion/, "fail when trying to delete workflow";
};

subtest "attempt to delete workflow without proper permissions" => sub {
    $oxitest->session->data->role("Liar");
    my $wf_id = create_wf($wf_archiver);
    push @ids, $wf_id;
    throws_ok { CTX('api2')->delete_workflow(id => $wf_id) } qr/permission.*delete/, "fail when trying to delete workflow";
};

subtest "delete workflow" => sub {
    $oxitest->session->data->role("MyFairyKing");
    my $wf_id = create_wf($wf_archiver);
    push @ids, $wf_id;
    lives_ok { CTX('api2')->delete_workflow(id => $wf_id) } "delete";
};

$oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => { '-like' => "$wf_type%" } });
$oxitest->dbi->delete_and_commit(from => 'workflow_attributes', where => { workflow_id => \@ids });

1;

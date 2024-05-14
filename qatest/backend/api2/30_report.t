#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep ':v1';
use Test::Exception;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 7;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( SampleConfig Workflows WorkflowCreateCert )],
);
my $dbi = $oxitest->dbi;

my $now = time();

my $r1_base = {
    report_name => $now.'_test_report',
    description => 'Just a Test Report',
    mime_type => 'text/plain',
    created => $now,
};
my $r1_base_data = [ map { $r1_base->{$_} } qw(report_name created description mime_type) ];
my $r1 =  {
    %{$r1_base},
    pki_realm => 'democa',
    report_value => 'report data'
};
my $r2_base = {
    report_name => $now.'_other_test_report',
    description => 'Just another Test Report',
    mime_type => 'text/plain',
    created => $now+1,
};
my $r2_base_data = [ map { $r2_base->{$_} } qw(report_name created description mime_type) ];
my $r2 = {
    %{$r2_base},
    pki_realm => 'democa',
    report_value => 'report other data'
};

note "Prefix $now";
$dbi->start_txn;
$dbi->insert(into => 'report', values => $r1);
$dbi->insert(into => 'report', values => $r2);
$dbi->commit;

#
# Tests
#

# get_report_list

lives_and {
    my $result = $oxitest->api2_command("get_report_list" => { name => $now.'_%' });
    cmp_deeply $result, [ $r2_base_data, $r1_base_data ];
} "List reports by NAME";

lives_and {
    my $result = $oxitest->api2_command("get_report_list" => { maxage => $now+1 });
    cmp_deeply $result, [ $r2_base_data ];
} "List reports by MAXAGE";

lives_and {
    my $result = $oxitest->api2_command("get_report_list" => { name => $now.'_%', columns => 'report_name, mime_type' });
    cmp_deeply $result, [
        [ $r2_base->{report_name}, $r2_base->{mime_type} ],
        [ $r1_base->{report_name}, $r1_base->{mime_type} ],
    ];
} "List reports and filter columns (string filter)";

lives_and {
    my $result = $oxitest->api2_command("get_report_list" => { name => $now.'_%', columns => [ 'report_name', 'mime_type' ] });
    cmp_deeply $result, [
        [ $r2_base->{report_name}, $r2_base->{mime_type} ],
        [ $r1_base->{report_name}, $r1_base->{mime_type} ],
    ];
} "List reports and filter columns (ArrayRef filter)";


# get_report

lives_and {
    my $result = $oxitest->api2_command("get_report" => { name => $r1_base->{report_name} });
    cmp_deeply $result, $r1_base;
} "Get report by NAME";

lives_and {
    my $result = $oxitest->api2_command("get_report" => { name => $r1_base->{report_name}, format => 'ALL' });
    cmp_deeply $result, $r1;
} "Get report by NAME with all data";

lives_and {
    my $result = $oxitest->api2_command("get_report" => { name => $r1_base->{report_name}, format => 'DATA' });
    cmp_deeply $result, $r1->{report_value};
} "Get only report data by NAME";

$dbi->start_txn;
$dbi->delete(
    from => 'report',
    where => { report_name => { -like => $now.'_%' }}
);
$dbi->commit;

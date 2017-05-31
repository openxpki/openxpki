#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename;

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

# Project modules
use lib qw(../../lib);
use OpenXPKI::Test::More;
use OpenXPKI::Test::DBI;
use TestCfg;
use Test::Deep;
use Test::More;

# Add sample reports
my $dbi = OpenXPKI::Test::DBI->new()->dbi();

#
# Init client
#
our $cfg = {};
TestCfg->new->read_config_path( 'api.cfg', $cfg, dirname($0) );

my $test = OpenXPKI::Test::More->new({
    socketfile => $cfg->{instance}{socketfile},
    realm => $cfg->{instance}{realm},
}) or die "Error creating new test instance: $@";

$test->set_verbose($cfg->{instance}{verbose});
$test->plan( tests => 9 );

my $now = time();

note("Prefix $now");
$dbi->insert(
    into => 'report',
    values => {
        report_name => $now.'_test_report',
        pki_realm => 'ca-one',
        created => $now,
        mime_type => 'text/plain',
        description => 'Just a Test Report',
        report_value => 'report data'
    }
);

$dbi->insert(
    into => 'report',
    values => {
        report_name => $now.'_other_test_report',
        pki_realm => 'ca-one',
        created => $now+1,
        mime_type => 'text/plain',
        description => 'Just another Test Report',
        report_value => 'report other data'
    }
);
$dbi->commit;

$test->connect_ok(
    user => $cfg->{operator}{name},
    password => $cfg->{operator}{password},
) or die "Error - connect failed: $@";

#
# Tests
#
$test->runcmd('get_report_list', { NAME => $now.'_%' });

cmp_deeply $test->get_msg->{PARAMS}, [{
  'report_name' => $now.'_other_test_report',
  'description' => 'Just another Test Report',
  'mime_type' => 'text/plain',
  'created' => $now+1
},
{
  'report_name' => $now.'_test_report',
  'description' => 'Just a Test Report',
  'mime_type' => 'text/plain',
  'created' => $now
}];

$test->runcmd('get_report_list', { MAXAGE => $now+1 });
# only one report, test_report is hidden by maxage
cmp_deeply $test->get_msg->{PARAMS}, [{
  'report_name' => $now.'_other_test_report',
  'description' => 'Just another Test Report',
  'mime_type' => 'text/plain',
  'created' => $now+1
}];

$test->runcmd('get_report_list', { NAME => $now.'_%', COLUMNS => 'report_name, mime_type' });
# only one report, test_report is hidden by maxage
cmp_deeply $test->get_msg->{PARAMS}, [
    [$now.'_other_test_report','text/plain'],
    [$now.'_test_report','text/plain'],
];

$test->runcmd('get_report_list', { NAME => $now.'_%', COLUMNS => [ 'report_name', 'mime_type' ] });
# only one report, test_report is hidden by maxage
cmp_deeply $test->get_msg->{PARAMS}, [
    [$now.'_other_test_report','text/plain'],
    [$now.'_test_report','text/plain'],
];


# get report

$test->runcmd('get_report', { NAME => $now.'_test_report' });

cmp_deeply $test->get_msg->{PARAMS}, {
  'report_name' => $now.'_test_report',
  'description' => 'Just a Test Report',
  'mime_type' => 'text/plain',
  'created' => $now,
};

$test->is($test->get_msg->{PARAMS}->{report_value}, undef);

$test->runcmd('get_report', { NAME => $now.'_test_report', FORMAT => 'ALL' });
cmp_deeply $test->get_msg->{PARAMS}, {
  'report_name' => $now.'_test_report',
  'pki_realm' => 'ca-one',
  'description' => 'Just a Test Report',
  'mime_type' => 'text/plain',
  'created' => $now,
  'report_value' => 'report data',
};


$test->runcmd('get_report', { NAME => $now.'_test_report', FORMAT => 'DATA' });
$test->is($test->get_msg->{PARAMS}, 'report data');

$dbi->delete(
    from => 'report',
    where => { report_name => { -like => $now.'_%' }}
);
$dbi->commit;

$test->disconnect();

#!/usr/bin/perl
use strict;
use warnings;
use utf8;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use DateTime;
use Log::Log4perl qw(:easy);

# Project modules
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;

#
# Init helpers
#

# Import test certificates
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( SampleConfig Workflows WorkflowCreateCert ) ],
);
my $dbdata = $oxitest->certhelper_database;
$oxitest->insert_testcerts;


# Count by PKI realm
my $realm = $dbdata->cert("beta-root-1")->db->{pki_realm};
my $expected_count = scalar($dbdata->cert_names_where(pki_realm => $realm));

lives_and {
    my $result = $oxitest->api2_command(search_cert_count => {
        pki_realm => $realm,
    });
    is $result, $expected_count;
} "Count $expected_count certs by PKI realm";

lives_and {
    my $result = $oxitest->api2_command(search_cert_count => {
        pki_realm => $realm,
        order => 'identifier',
    });
    is $result, $expected_count;
} "Count $expected_count certs by PKI realm with ORDER BY";

# Count by cert attribute
my $uuid = Data::UUID->new->create_str;
$oxitest->create_cert(
    hostname => "acme-$uuid-a.local",
    requestor_realname => "Till $uuid",
    requestor_email => 'till@morning',
);
$oxitest->create_cert(
    hostname => "acme-$uuid-b.local",
    requestor_realname => "Tom $uuid",
    requestor_email => 'tom@morning',
);

lives_and {
    my $result = $oxitest->api2_command(search_cert_count => {
        pki_realm => "_ANY",
        cert_attributes => {
            meta_requestor => { -like => "%$uuid%" },
            meta_email => 'tom@morning',
        },
    });
    is $result, 1;
} "Count certs by certificate attributes";

$oxitest->delete_testcerts; # only deletes those from OpenXPKI::Test::CertHelper::Database

done_testing;

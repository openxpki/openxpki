#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;

# Project modules
use lib "$Bin/../../lib";
use lib "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;



# Init server
my $oxitest = OpenXPKI::Test->new(with => [ qw( SampleConfig Server Workflows WorkflowCreateCert ) ]);

# Create test certificates
$oxitest->create_cert(
    profile => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    hostname => "127.0.0.1",
);
$oxitest->create_cert(
    profile => "I18N_OPENXPKI_PROFILE_TLS_CLIENT",
    hostname => "127.0.0.1",
    application_name => "Joust",
);

# Init client
my $client = $oxitest->new_client_tester;
$client->connect;
$client->init_session;
$client->login("caop");

my $result = $client->send_command_ok('list_used_profiles');

cmp_deeply $result, superbagof(
    superhashof( { value => "I18N_OPENXPKI_PROFILE_TLS_SERVER" } ),
    superhashof( { value => "I18N_OPENXPKI_PROFILE_TLS_CLIENT" } ),
), "Show expected profiles";

done_testing;

#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 5;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( TestRealms CryptoLayer )],
);
$oxitest->insert_testcerts;
my $dbdata = $oxitest->certhelper_database;

# Fetch chain - HASH Format
my $result;
lives_ok {
    $result = $oxitest->api_command("get_chain" => { START_IDENTIFIER => $dbdata->cert("alpha_alice_2")->id, OUTFORMAT => 'HASH' });
} "Fetch certificate chain";

is scalar @{$result->{CERTIFICATES}}, 3, "Chain contains 3 certificates";

is $result->{CERTIFICATES}->[0]->{IDENTIFIER},
    $dbdata->cert("alpha_alice_2")->id,
    "First cert in chain equals requested start cert";

is $result->{CERTIFICATES}->[0]->{AUTHORITY_KEY_IDENTIFIER},
    $result->{CERTIFICATES}->[1]->{SUBJECT_KEY_IDENTIFIER},
    "Server cert was signed by CA cert";

is $result->{CERTIFICATES}->[1]->{AUTHORITY_KEY_IDENTIFIER},
    $result->{CERTIFICATES}->[2]->{SUBJECT_KEY_IDENTIFIER},
    "CA cert was signed by Root cert";

# TODO Test get_chain with BUNDLE => 1

# OUTFORMAT, which can be either 'PEM', 'DER' or 'HASH' (full db result).
# Result:
#    IDENTIFIERS   the chain of certificate identifiers as an array
#    SUBJECT       list of subjects for the returned certificates
#    CERTIFICATES  the certificates as an array of data in outformat
#                  (if requested)
#    COMPLETE      1 if the complete chain was found in the database
#                  0 otherwise
#
# By setting "BUNDLE => 1" you will not get a hash but a PKCS7 encoded bundle
# holding the requested certificate and all intermediates (if found). Add
# "KEEPROOT => 1" to also have the root in PKCS7 container.

$oxitest->delete_testcerts;

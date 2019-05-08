#!/usr/bin/perl

#
# PLEASE KEEP this test in sync with core/server/t/95_openxpkiadm/10_import_certificate.t
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

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
# use OpenXPKI::Debug; BEGIN { $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Database.*'} = 0b1111111 }
use OpenXPKI::Test;

plan tests => 15;

=pod

Test certificate import via API function "import_certificate".

Positional parameters:

=over

=item * B<$test_cert> - Container with certificate data (I<OpenXPKI::Test::CertHelper::Database::Cert>, required)

=item * B<%args> - Arguments to pass to "import_certificate" (I<Hash>, optional)

=back

=cut
sub import_ok {
    my ($oxitest, $test_cert, %args) = @_;
    lives_and {
        # run import
        my $result = $oxitest->api2_command("import_certificate" => {
            data => $test_cert->data,
            %args
        });
        # test result
        is $result->{subject_key_identifier}, $test_cert->subject_key_id;
    } sprintf('Import "%s"%s', $test_cert->label, scalar(%args) ? " with ".join(", ", map { $_." = ".$args{$_} } sort keys %args) : "");
}

=pod

Test certificate import via API function "import_certificate" and expect it to
fail with the given error message.

Positional parameters:

=over

=item * B<$test_cert> - Container with certificate data (I<OpenXPKI::Test::CertHelper::Database::Cert>, required)

=item * B<$error> - Expected error string returned by API (I<Str>, required)

=item * B<%args> - Arguments to pass to "import_certificate" (I<Hash>, optional)

=back

=cut
sub import_failsok {
    my ($oxitest, $test_cert, $error, %args) = @_;
    throws_ok {
        # run import
        $oxitest->api2_command("import_certificate" => {
            data => $test_cert->data,
            %args
        });
    } $error, sprintf('Import "%s"%s: should fail', $test_cert->label, scalar(%args) ? " with ".join(", ", map { $_." = ".$args{$_} } sort keys %args) : "")
}

#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( TestRealms CryptoLayer )],
    #log_level => 'trace',
);
my $dbdata = $oxitest->certhelper_database;
my $cert1_pem = $dbdata->cert("alpha-root-2")->data;
my $cert2_pem = $dbdata->cert("alpha-signer-2")->data;

#
# Tests
#

# Import certificate
lives_and {
    my $result = $oxitest->api2_command("import_certificate" => { data => $cert1_pem });
    is $result->{identifier}, $result->{issuer_identifier};
} "Import and recognize self signed root certificate";

use_ok "OpenXPKI::Crypt::X509";

lives_and {
    my $cert_id = $dbdata->cert("alpha-root-2")->id;
    my $result = $oxitest->api2_command("get_cert" => { identifier => $cert_id, format => 'PEM' });
    my $cert = OpenXPKI::Crypt::X509->new($result); # initialize with PEM data
    is $cert->cert_identifier, $cert_id;
} "Querying imported certificate matches original data";

# Second import should fail
throws_ok {
    $oxitest->api2_command("import_certificate" => { data => $cert1_pem });
} qr/already exists/i,
    "Fail importing same certificate twice";

# ...except if we want to update
lives_and {
    my $result = $oxitest->api2_command("import_certificate" => { data => $cert1_pem, update => 1 });
    is $result->{identifier}, $result->{issuer_identifier};
} "Import same certificate with UPDATE = 1";

# Import second certificate as "REVOKED"
lives_and {
    my $result = $oxitest->api2_command("import_certificate" => { data => $cert2_pem, revoked => 1 });
    is $result->{status}, "REVOKED";
} "Import second certificate as REVOKED";

$oxitest->delete_testcerts;

# unknown issuer
import_failsok($oxitest, $dbdata->cert("gamma-bob-1"), qr/issuer/i);
# unknown issuer with forced import
import_ok     ($oxitest, $dbdata->cert("gamma-bob-1"), force_nochain => 1);
# root certificate
import_ok     ($oxitest, $dbdata->cert("alpha-root-2"));
# cert signed by previously imported root certificate
import_ok     ($oxitest, $dbdata->cert("alpha-signer-2"));
# expired root certificate
import_ok     ($oxitest, $dbdata->cert("alpha-root-1"));
# cert signed with invalid (expired) issuer, i.e. failing chain verification
import_failsok($oxitest, $dbdata->cert("alpha-signer-1"), qr/chain/i);
# cert signed by expired issuer with forced acceptance of failed issuer check
import_ok     ($oxitest, $dbdata->cert("alpha-signer-1"), force_issuer=>1);
# cert signed by expired issuer with disabled issuer check
import_ok     ($oxitest, $dbdata->cert("alpha-alice-1"),  force_noverify=>1);
# known issuer that is not root and triggers chain lookup
import_ok     ($oxitest, $dbdata->cert("alpha-bob-2"));

# Cleanup database
$oxitest->delete_testcerts;

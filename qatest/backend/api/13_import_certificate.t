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
use OpenXPKI::Test;


plan tests => 12;


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
        my $result = $oxitest->api_command("import_certificate" => {
            DATA => $test_cert->data,
            %args
        });
        # test result
        is $result->{SUBJECT_KEY_IDENTIFIER}, $test_cert->subject_key_id;
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
        $oxitest->api_command("import_certificate" => {
            DATA => $test_cert->data,
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
my $cert1_pem = $dbdata->cert("alpha_root_2")->data;
my $cert2_pem = $dbdata->cert("alpha_signer_2")->data;

#
# Tests
#

# Import certificate
lives_and {
    my $result = $oxitest->api_command("import_certificate" => { DATA => $cert1_pem });
    is $result->{IDENTIFIER}, $result->{ISSUER_IDENTIFIER};
} "Import and recognize self signed root certificate";

# Second import should fail
throws_ok {
    $oxitest->api_command("import_certificate" => { DATA => $cert1_pem });
} qr/I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_CERTIFICATE_ALREADY_EXISTS/,
    "Fail importing same certificate twice";

# ...except if we want to update
lives_and {
    my $result = $oxitest->api_command("import_certificate" => { DATA => $cert1_pem, UPDATE => 1 });
    is $result->{IDENTIFIER}, $result->{ISSUER_IDENTIFIER};
} "Import same certificate with UPDATE = 1";

# Import second certificate as "REVOKED"
lives_and {
    my $result = $oxitest->api_command("import_certificate" => { DATA => $cert2_pem, REVOKED => 1 });
    is $result->{STATUS}, "REVOKED";
} "Import second certificate as REVOKED";

$oxitest->delete_testcerts;

import_failsok($oxitest, $dbdata->cert("gamma_bob_1"), qr/I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_FIND_ISSUER/);
import_ok     ($oxitest, $dbdata->cert("gamma_bob_1"), FORCE_NOCHAIN => 1);

import_ok     ($oxitest, $dbdata->cert("alpha_root_2"));
import_ok     ($oxitest, $dbdata->cert("alpha_signer_2"));
import_ok     ($oxitest, $dbdata->cert("alpha_root_1"));
import_failsok($oxitest, $dbdata->cert("alpha_signer_1"), qr/I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_BUILD_CHAIN/);
import_ok     ($oxitest, $dbdata->cert("alpha_signer_1"), FORCE_ISSUER=>1);
import_ok     ($oxitest, $dbdata->cert("alpha_alice_1"),  FORCE_NOVERIFY=>1);

# Cleanup database
$oxitest->delete_testcerts;

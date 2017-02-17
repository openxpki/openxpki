#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename;
use File::Temp qw( tempdir );

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use Test::More;
use Test::Deep;

# Project modules
use lib qw(../../lib);
use OpenXPKI::Test::More;
use DbHelper;
use TestCfg;
use OpenXPKI::Test::CertHelper;

=pod

Test certificate import via API function "import_certificate".

Positional parameters:

=over

=item * B<$test_cert> - Container with certificate data (I<OpenXPKI::Test::CertHelper::PEM>, required)

=item * B<%args> - Arguments to pass to "import_certificate" (I<Hash>, optional)

=back

=cut
sub import_ok {
    my ($tester, $test_cert, %args) = @_;
    # run import
    $tester->runcmd_ok(
        "import_certificate",
        { DATA => $test_cert->data, %args },
        sprintf('Import "%s"%s', $test_cert->label, scalar(%args) ? " with ".join(", ", map { $_." = ".$args{$_} } sort keys %args) : "")
    )
    # catch errors
    or diag "ERROR: ".$tester->error;
    # test result
    my $params = $tester->get_msg->{PARAMS};
    $tester->is(
        ref $params eq 'HASH' ? $params->{SUBJECT_KEY_IDENTIFIER} : "",
        $test_cert->id,
        "Correctly list imported certificate"
    );
}

=pod

Test certificate import via API function "import_certificate" and expect it to
fail with the given error message.

Positional parameters:

=over

=item * B<$test_cert> - Container with certificate data (I<OpenXPKI::Test::CertHelper::PEM>, required)

=item * B<$error> - Expected error string returned by API (I<Str>, required)

=item * B<%args> - Arguments to pass to "import_certificate" (I<Hash>, optional)

=back

=cut
sub import_failsok {
    my ($tester, $test_cert, $error, %args) = @_;
    $tester->runcmd(
        "import_certificate",
        { DATA => $test_cert->data, %args }
    );
    $tester->error_is(
        $error,
        sprintf('Import "%s"%s: should fail', $test_cert->label, scalar(%args) ? " with ".join(", ", map { $_." = ".$args{$_} } sort keys %args) : "")
    );
}

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
$test->plan( tests => 21 );

$test->connect_ok(
    user => $cfg->{operator}{name},
    password => $cfg->{operator}{password},
) or die "Error - connect failed: $@";

#
# Init helpers
#
my $db_helper = DbHelper->new;
my $test_certs = OpenXPKI::Test::CertHelper->new(tester => $test);

my $certs = $test_certs->certs;

#
# Create new test certificates on disk
#
my $cert_pem = OpenXPKI::Test::CertHelper->via_openssl->cert_pem;
my $cert_pem2 = OpenXPKI::Test::CertHelper->via_openssl(commonName => 'test2.openxpki.org')->cert_pem;

#
# Tests
#

# Import certificate
$test->runcmd_ok('import_certificate', { DATA => $cert_pem, }, "Import certificate 1")
    or diag "ERROR: ".$test->error;
$test->is($test->get_msg->{PARAMS}->{IDENTIFIER}, $test->get_msg->{PARAMS}->{ISSUER_IDENTIFIER}, "Certificate is recognized as self-signed");

# Second import should fail
$test->runcmd('import_certificate', { DATA => $cert_pem, });
$test->error_is("I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_CERTIFICATE_ALREADY_EXISTS", "Fail importing same certificate twice");

# ...except if we want to update
$test->runcmd_ok('import_certificate', { DATA => $cert_pem, UPDATE => 1 }, "Import same certificate with UPDATE = 1");

# Import second certificate as "REVOKED"
$test->runcmd_ok('import_certificate', { DATA => $cert_pem2, REVOKED => 1 }, "Import certificate 2 as REVOKED")
    or diag "ERROR: ".$test->error;
$test->is($test->get_msg->{PARAMS}->{STATUS}, "REVOKED", "Certificate should be marked as REVOKED");

import_failsok($test, $certs->{orphan}, "I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_FIND_ISSUER");
import_ok     ($test, $certs->{orphan}, FORCE_NOCHAIN => 1);

import_ok     ($test, $certs->{acme_root});
import_ok     ($test, $certs->{acme_signer});
import_ok     ($test, $certs->{expired_root});
import_failsok($test, $certs->{expired_signer}, "I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_BUILD_CHAIN");
import_ok     ($test, $certs->{expired_signer}, FORCE_ISSUER=>1);

$db_helper->delete_cert_by_id($certs->{expired_signer}->id);
import_ok     ($test, $certs->{expired_signer}, FORCE_NOVERIFY=>1);

# Cleanup database
$db_helper->delete_cert_by_id($test_certs->all_cert_ids);

$test->disconnect;

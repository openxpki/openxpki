use strict;
use warnings;
use Test::More tests => 3;
use English;
# use Smart::Comments;

our %config;
require 't/common.pl';
my $debug = $config{debug};
my $stderr = '2>/dev/null';
#if ($debug) {
#    $stderr = '';
#}

print STDERR "OpenXPKI::Client::SCEP: Create certificates for the SCEP server / CA\n";

use OpenXPKI qw( read_file );
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::Profile::Certificate;

our $cache;
our $basedir;

# create SCEP certificate
SKIP : {
    if (! (`$config{openssl} version` =~ m{\A OpenSSL\ 0\.9\.8 }xms)) {
        skip "OpenSSL 0.9.8 not available.", 3;
    }
    diag("Creating SCEP certificate");
    my $openssl = $config{'openssl'};
    `mkdir -p t/instance/etc/openxpki/ca/scepdummyserver1/`;
    `pwd=1234567890 $openssl genrsa -des -passout env:pwd -out t/instance/etc/openxpki/ca/scepdummyserver1/key.pem 1024 $stderr`;
    `(echo '.'; echo '.'; echo '.'; echo 'OpenXPKI'; echo 'SCEP test server'; echo 'SCEP test server'; echo '.'; echo '.'; echo '.')|pwd=1234567890 openssl req -new -x509 -key t/instance/etc/openxpki/ca/scepdummyserver1/key.pem -passin env:pwd -out t/instance/etc/openxpki/ca/scepdummyserver1/cert.pem $stderr`;
    my $identifier = `openxpkiadm certificate import --config t/instance/etc/openxpki/config.xml --file t/instance/etc/openxpki/ca/scepdummyserver1/cert.pem|tail -1|sed -e 's/  Identifier: //' $stderr`;
    `openxpkiadm certificate alias --config t/instance/etc/openxpki/config.xml --realm I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA --alias testscepserver1 --identifier $identifier $stderr`;
    ok(1);

    # create CA certificate
    diag("Creating CA certificate");
    `mkdir -p t/instance/etc/openxpki/ca/testdummyca1/`;
    `pwd=1234567890 $openssl genrsa -des -passout env:pwd -out t/instance/etc/openxpki/ca/testdummyca1/cakey.pem 1024 $stderr`;
    `(echo '.'; echo '.'; echo '.'; echo 'OpenXPKI'; echo 'SCEP testing CA'; echo 'SCEP testing CA'; echo '.'; echo '.'; echo '.')|pwd=1234567890 $openssl req -new -key t/instance/etc/openxpki/ca/testdummyca1/cakey.pem -passin env:pwd -out t/instance/csr.pem $stderr`;
    `mkdir t/instance/demoCA`;
    `touch t/instance/demoCA/index.txt`;
    `echo 01 > t/instance/demoCA/serial`;
    `cd t/instance; pwd=1234567890 $openssl ca -selfsign -in csr.pem -keyfile etc/openxpki/ca/testdummyca1/cakey.pem -passin env:pwd -utf8 -outdir . -policy policy_anything -batch -extensions v3_ca -preserveDN -out cacert.pem $stderr`;
    open CACERT_IN, "<", "t/instance/cacert.pem";
    open CACERT_OUT, ">", "t/instance/etc/openxpki/ca/testdummyca1/cert.pem";
    my $cert;
    while (<CACERT_IN>) {
        if ($_ =~ /^-----BEGIN/) {
            $cert = 1;
        }
        next if (! $cert);
        print CACERT_OUT $_;
    }
    close CACERT_IN;
    close CACERT_OUT;
    $identifier = `openxpkiadm certificate import --config t/instance/etc/openxpki/config.xml --file t/instance/etc/openxpki/ca/testdummyca1/cert.pem|tail -1|sed -e 's/  Identifier: //' $stderr`;
    `openxpkiadm certificate alias --config t/instance/etc/openxpki/config.xml --realm I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA --alias testdummyca1 --identifier $identifier $stderr`;
    ok(1);

    `patch -p0 < t/config.xml.diff`;

    diag("Starting OpenXPKI Server.");
    my $args = '';
    $args = "--debug 150" if ($debug);
    if (system("openxpkictl --config $config{config_file} $args start $stderr >/dev/null") != 0) {
        unlink $config{socket_file};
        BAIL_OUT("Could not start OpenXPKI.");
    }

    if (! ok(-e $config{socket_file})) {
        unlink $config{socket_file};
        BAIL_OUT("Server did not start (no socket file)");
    }
}

1;

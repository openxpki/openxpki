#!/usr/bin/perl
use strict;
use warnings;

# CPAN modules
use Test::More tests => 10;
use Test::Exception;
use DateTime;


use_ok "OpenXPKI::Crypt::CRL";

my $crl = "-----BEGIN X509 CRL-----\nMIICTTCCATUCAQEwDQYJKoZIhvcNAQELBQAwWTETMBEGCgmSJomT8ixkARkWA09S\nRzEYMBYGCgmSJomT8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRkwFwYD\nVQQDDBBBTFBIQSBTaWduaW5nIENBFw0xNzA0MjUxMTQ0MDhaGA8yMDY3MDQyNTEx\nNDQwOFowFDASAgEBFw03MDAxMDEwMDAwMDBaoIGPMIGMMH4GA1UdIwR3MHWAFEyR\nZsjqV6Yj2/JGkP1s620OXo2ioVqkWDBWMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgw\nFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxFjAUBgNVBAMM\nDUFMUEhBIFJvb3QgQ0GCAQkwCgYDVR0UBAMCARcwDQYJKoZIhvcNAQELBQADggEB\nADFfaBkH131sF2pksnlScDbDppNVp4gVBN/pVGBJWf2c9R3cKA7qL/sKkDUKGZTm\nK5GD1KJ+knWmtzhfMBH+Brf1zk+VT+8fWGILlMg6bKyAy4WNK02hZUJC6UoDl4CA\nF3VZpNt8CHlFvtWOCyTgIxK8MECJcRRY1l8G9TWsrvBXov3fR/yo2FfuKrm5cqj3\nKz0a4iJbMYzoixn3ySykQiBf4kmNDlB3/MgvAYPwyl2QNC4SnYnr4YUX0onT+Xn/\n7ZUU8jOGDFrShkJeMZFndi2HLUXNXFhJtJm8TFQjAUiYZw+Hy4uDuY9f7UKnapd+\nIOrEI9p27uDUzerqP/yh1QI=\n-----END X509 CRL-----\n";

my $cryptCrl;
lives_ok {
    $cryptCrl = OpenXPKI::Crypt::CRL->new($crl);
} 'CRL parsed';

## check that all required functions are available and work
#diag explain $cryptCrl->parsed();

is $cryptCrl->issuer, "CN=ALPHA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG", "Issuer";
is $cryptCrl->version, 2, "Version";
is $cryptCrl->authority_key_id, "4C:91:66:C8:EA:57:A6:23:DB:F2:46:90:FD:6C:EB:6D:0E:5E:8D:A2", "Authority Key Identifier";
is $cryptCrl->crl_number, 23, "CRL number";
lives_and { is(DateTime->from_epoch(epoch => $cryptCrl->last_update)->iso8601, "2017-04-25T11:44:08") } "Last Update";
lives_and { is(DateTime->from_epoch(epoch => $cryptCrl->next_update)->iso8601, "2067-04-25T11:44:08") } "Next Update";
is $cryptCrl->itemcnt, 1, "No. of certificates";
lives_and { is(DateTime->from_epoch(epoch => $cryptCrl->items->{1}->[0])->iso8601, "2070-01-01T00:00:00") } "Cert no. 1 Revocation Date";

1;

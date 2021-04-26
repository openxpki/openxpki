use strict;
use warnings;
use Test::More;

plan tests => 8;

use_ok "OpenXPKI::Crypt::X509";

## define a test object
my $example_certificate = '-----BEGIN CERTIFICATE-----
MIIB6jCCAZGgAwIBAgIUAzOGaDL9MVh6C+YChqwrQmKDm04wCgYIKoZIzj0EAwIw
HjEcMBoGA1UEAwwTRXhhbXBsZSBjZXJ0aWZpY2F0ZTAeFw0yMDA0MTcxMzI5Mjda
Fw0yMDA1MTcxMzI5MjdaMB4xHDAaBgNVBAMME0V4YW1wbGUgY2VydGlmaWNhdGUw
WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAARt47IstyihcXvZgJpyO7UzDkP73z6l
6MFwznfFSN0aFCnxYWWWJqlu7eV/weKsS9oG/K136U2YoaXBqHQ4fETno4GsMIGp
MIGmBgNVHREEgZ4wgZukXTBbMQswCQYDVQQGEwJVUzEuMA0GA1UECgwGQmFyT3Jn
MA0GA1UECgwGRm9vT3JnMA4GA1UECwwHQmF6VW5pdDEcMBoGA1UEAwwTRXhhbXBs
ZSBjb21tb24gbmFtZYIPZG5zLmV4YW1wbGUuY29tgRFlbWFpbEBleGFtcGxlLmNv
bYcE20F1jocQcEYrOeMjiycv73JsEZeafjAKBggqhkjOPQQDAgNHADBEAiB8nyFx
/o3yY6GTMjGu3PpSaPS6J+6IvsprqR7ELWvJIQIgAZgxJuOg1egVzArsxWBMATbt
40ogDLlti/K+xBB886Y=
-----END CERTIFICATE-----';

## test object creation
my $x509 = OpenXPKI::Crypt::X509->new($example_certificate);
ok(1, 'certificate parsed');

is($x509->pem, $example_certificate, 'certificate has not been mangled in any way');
is($x509->get_subject, 'CN=Example certificate', 'subject is as expected');
is_deeply($x509->get_subject_alt_name,
    [
        [
            'dirName',
            {
                rdnSequence => [
                    [
                        {
                            value => { printableString => 'US' },
                            type => '2.5.4.6'
                        }
                    ],
                    [
                        {
                            value => { utf8String => 'BarOrg' },
                            type => '2.5.4.10'
                        },
                        {
                            type => '2.5.4.10',
                            value => { utf8String => 'FooOrg' }
                        },
                        {
                            type => '2.5.4.11',
                            value => { utf8String => 'BazUnit' }
                        }
                    ],
                    [
                        {
                            type => '2.5.4.3',
                            value => { utf8String => 'Example common name' }
                        }
                    ]
                ]
            }
        ],
        [ 'DNS', 'dns.example.com' ],
        [ 'email', 'email@example.com' ],
        [ 'IP', "219.65.117.142" ],
        [ 'IP', "7046:2B39:E323:8B27:2FEF:726C:1197:9A7E" ]
    ],
    'SAN is as expected');
is($x509->notbefore, 1587130167, 'not before is as expected');
is($x509->notafter, 1589722167, 'not after is as expected');
is($x509->get_serial, '18276018821053647745944141854221156918868810574', 'serial is as expected');

1;

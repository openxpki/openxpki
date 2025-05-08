package OpenXPKI::Defaults;
use strict;
use warnings;

our $SERVER_SOCKET  = '/run/openxpkid/openxpkid.sock';
our $SERVER_PID     = '/run/openxpkid/openxpkid.pid';
our $CLIENT_SOCKET  = '/run/openxpki-clientd/openxpki-clientd.sock';
our $CLIENT_PID     = '/run/openxpki-clientd/openxpki-clientd.pid';

1;

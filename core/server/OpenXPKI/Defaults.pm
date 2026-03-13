package OpenXPKI::Defaults;
use strict;
use warnings;

# starting with v3.32 we enforce a schema version for the config to be set
# this holds a list of integer numbers which are accpted by this release
our $CONFIG_SCHEMA  = [1,2];

# same for the database
our $DATABASE_SCHEMA  = [1,2,3,4,5];

our $SERVER_SOCKET  = '/run/openxpkid/openxpkid.sock';
our $SERVER_LEGACY_SOCKET = '/var/openxpki/openxpki.socket';
our $SERVER_PID     = '/run/openxpkid/openxpkid.pid';
our $SERVER_CONFIG_DIR = '/etc/openxpki/config.d/';

our $CLIENT_SOCKET  = '/run/openxpki-clientd/openxpki-clientd.sock';
our $CLIENT_PID     = '/run/openxpki-clientd/openxpki-clientd.pid';
our $CLIENT_CONFIG_DIR = '/etc/openxpki/client.d/';

# interval in seconds after which in-memory secrets are checked against cache
our $CRYPTO_SECRET_CACHE_CHECK = 1;
our $CRYPTO_SECRET_CACHE_CHECK_IF_COMPLETE = 60;

1;

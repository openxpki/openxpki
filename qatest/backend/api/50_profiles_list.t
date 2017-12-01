
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
my $oxitest = OpenXPKI::Test->new(with => [ qw( SampleConfig Server ) ]);

# Init client
my $client = $oxitest->new_client_tester;
$client->connect;
$client->init_session;
$client->login("caop");

my $result = $client->send_command_ok('get_cert_subject_profiles' => { PROFILE => 'I18N_OPENXPKI_PROFILE_TLS_SERVER' });

cmp_deeply $result, superhashof({
    '00_basic_style' => ignore(),
    '05_advanced_style' => ignore(),
}), "list profile styles";

done_testing;

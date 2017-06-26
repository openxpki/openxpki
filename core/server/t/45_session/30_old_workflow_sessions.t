package main;
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw( tempdir );

# CPAN modules
use Test::More;
use Test::Exception;
use Test::Deep;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($OFF);

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Session.*'} = 100;

plan tests => 5;

#
# Setup test env
#
my $oxitest = OpenXPKI::Test->new;
$oxitest->setup_env;

#
# Tests
#
use_ok "OpenXPKI::Server::Session";

my $session;
lives_ok {
    $session = OpenXPKI::Server::Session->new(
        type => "Database",
        config => { dbi => $oxitest->dbi },
    )->create;
} "create session";

lives_ok {
    # extracted from MySQL database
    my $data = "HASH\n50\n4\nrole\nSCALAR\n11\nRA Operator\n4\nuser\nSCALAR\n4\nraop\n";

    $session->data->thaw($data);
} "deserialize old workflow session";

is $session->data->user, "raop", "session attribute 'user' correct";
is $session->data->role, "RA Operator", "session attribute 'role' correct";

1;

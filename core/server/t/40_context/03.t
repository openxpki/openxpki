use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );
use Data::Dumper;
use Scalar::Util qw( blessed );

# CPAN modules
use Test::More;
use Test::Exception;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;


my $oxitest = OpenXPKI::Test->new();

is ref CTX('config'), 'OpenXPKI::Config', "CTX('config')";
is ref CTX('log'), 'OpenXPKI::Server::Log', "CTX('log')";
is ref CTX('dbi'), 'OpenXPKI::Server::Database', "CTX('dbi')";
is ref CTX('api2'), 'OpenXPKI::Server::API2::Autoloader', "CTX('api2')";
is ref CTX('authentication'), 'OpenXPKI::Server::Authentication', "CTX('authentication')";

done_testing;

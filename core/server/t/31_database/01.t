use strict;
use warnings;
use English;
use Test::More;
use Test::Exception;
use File::Spec;

#plan tests => 9;

my $basedir = File::Spec->catdir((File::Spec->splitpath(File::Spec->rel2abs(__FILE__)))[0,1]);

## prepare log system
use OpenXPKI::Server::Log;
my $log = OpenXPKI::Server::Log->new (CONFIG => File::Spec->catfile($basedir, "log4perl.conf"));
ok($log, "Log object initialized");

my %params = (
    type =>       'MySQL',
    name =>       'oxi',
    namespace =>  '',
    host =>       'localhost',
    #port =>       '',
    user =>       'klothilde',
    passwd =>     'pass1234',
);

use_ok("OpenXPKI::Server::Database");

my $dbi;

# create faulty instance
lives_ok { $dbi = OpenXPKI::Server::Database->new(
    log => $log,
    dsn_params => {
        %params,
        type => undef,
    }
) };

throws_ok { $dbi->driver } qr/\btype\b.*missing/, 'Complain about missing "type" parameter';

# create correct instance
lives_ok { $dbi = OpenXPKI::Server::Database->new(
    log => $log,
    dsn_params => \%params,
) } "create instance";

my $query;
lives_ok { $query = $dbi->query } "fetch (create) query object instance";

done_testing;

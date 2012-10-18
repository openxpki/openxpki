use strict;
use warnings;
use English;
use Test::More;
plan tests => 6;

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}

our $dbi;
our $token;
require 't/30_dbi/common.pl';

use OpenXPKI::Server::Context;
use OpenXPKI::Server::Log;

OpenXPKI::Server::Context::setcontext({
    dbi_log => $dbi
});
my $log = OpenXPKI::Server::Log->new( CONFIG => 't/28_log/log4perl.conf' );

my $msg = sprintf "DBI Log Test %01d", rand(10000000);

# Workflow errors go to DBI
ok ($log->log (FACILITY => "audit",
               PRIORITY => "info",
               MESSAGE  => $msg), 'Test message');

 my $result = $dbi->select(
    TABLE => 'AUDITTRAIL',
    DYNAMIC => 
    {
        CATEGORY => {VALUE => 'openxpki.audit' },
        MESSAGE => {VALUE => "%$msg", OPERATOR => 'LIKE'},
    }
);
is(scalar @{$result}, 1, 'Log entry found');

1;

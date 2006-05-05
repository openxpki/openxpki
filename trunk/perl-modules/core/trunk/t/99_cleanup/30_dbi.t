use strict;
use warnings;
use Test;
BEGIN { plan tests => 6 };

print STDERR "OpenXPKI::Server::DBI Cleanup\n";

foreach my $db (qw( t/30_dbi/sqlite.db 
                    t/30_dbi/sqlite.db._workflow_
                    t/30_dbi/sqlite.db._backend_ )) {

    unlink $db;

    ok(1);

    if (-e $db)
    {
	ok(0);
    } else {
	ok(1);
    }
}

1;

use Test::More tests => 1;

use English;

BEGIN {

    require "t/common.pl";

    ## ask for the first page
    my $result = `perl bin/openxpki.cgi`;
    ok (! $EVAL_ERROR);

print STDERR $result;
}

diag( "Testing syntax of used classes" );

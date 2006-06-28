use Test::More tests => 2;

use English;

BEGIN {

    require "t/common.pl";
    our $OUTPUT;

    ## ask for the first page
    my $result = `perl bin/openxpki.cgi`;
    ok (! $EVAL_ERROR);
    if (open FD, ">$OUTPUT/auth_stack.html" and
        print FD $result and
        close FD)
    {
        ok(1);
    } else {
        ok(0);
        print STDERR "Cannot write returned HTML page to file $OUTPUT/auth_stack.html.\n";
    }
}

diag( "Testing authentication" );

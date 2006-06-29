use Test::More tests => 5;

use English;

BEGIN {

    require "t/common.pl";
    our $OUTPUT;
    our $XS;

    ## ask for the auth_stack page
    my $result = `perl bin/openxpki.cgi`;
    ok (! $EVAL_ERROR);
    ## strip off http header
    $result =~ s/^.*\n\n<\?xml/<?xml/s;
    if (open FD, ">$OUTPUT/auth_stack.html" and
        print FD $result and
        close FD)
    {
        ok(1);
    } else {
        ok(0);
        print STDERR "Cannot write returned HTML page to file $OUTPUT/auth_stack.html.\n";
    }

    ## parse the auth_stack page
    ## we use three tests here to verify check_html ... yes this is a kind of a hack
    my $xml = $XS->XMLin ("$OUTPUT/auth_stack.html");
    ok (0 < check_html ({PAGE => $xml, PATH => "html:0/body:0/div:0/div:1/form:0/select:0/none:0"}));
    ok (0 == check_html ({PAGE => $xml, PATH => "html:0/body:0/div:0/div:1/form:0/select:0/option:4"}));
    ok (0 > check_html ({PAGE => $xml, PATH => "html:0/body:0/div:0/div:1/form:0/select:0/option:5"}));
}

diag( "Testing authentication" );

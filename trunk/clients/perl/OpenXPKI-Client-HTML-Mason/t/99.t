use Test::More tests => 1;

use English;

BEGIN {
    ## configure test environment

    my $INSTANCE   = "t/tc1";
    $INSTANCE   = $ENV{INSTANCE}   if (exists $ENV{INSTANCE});    

    ## check for OpenXPKI::Server
    
    ## stop server
    `openxpkictl --config $INSTANCE/etc/openxpki/config.xml stop`;
    ok (! $EVAL_ERROR);
}

diag( "Stop OpenXPKI test server" );

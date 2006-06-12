use Test::More tests => 2;

use English;

BEGIN {
    ## configure test environment

    my $INSTANCE   = "/tmp/openxpki-client-html-mason-test";
    $INSTANCE   = $ENV{INSTANCE}   if (exists $ENV{INSTANCE});    

#    ## check for OpenXPKI::Server
#    
#    ## stop server
#    if (-e "$INSTANCE/config.xml")
#    {
#        `openxpkictl --config $INSTANCE/config.xml stop`;
#        ok (! $EVAL_ERROR);
#    } else {
        ok (1);
#    }

#    ## remove instance
#    if (length $INSTANCE > 10)
#    {
#        `rm -rf $INSTANCE`;
#    }
    ok (! -d $INSTANCE);
}

diag( "Deploy an OpenXPKI trustcenter installation" );

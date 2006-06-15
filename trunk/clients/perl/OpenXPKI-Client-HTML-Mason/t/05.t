
use strict;
use warnings;

use Test::More tests => 10;

use English;

BEGIN {
    ## configure test environment

    my $PWD      = `pwd`;
       $PWD      =~ s/\n//g;
    my $INSTANCE = "$PWD/t/tc1";
    my $CONFIG   = "openxpki.conf";

    $INSTANCE   = $ENV{INSTANCE}   if (exists $ENV{INSTANCE});    

    ## check for OpenXPKI::Server
    use_ok ("OpenXPKI::Server");

    ## check for deployment tools
    ok (`openxpkiadm --help`);
    ok (`openxpkictl --help`);

    ## create test directory
    mkdir $INSTANCE if (! -d $INSTANCE);
    ok (-d $INSTANCE);
    mkdir "$INSTANCE/etc" if (! -d "$INSTANCE/etc");
    ok (-d "$INSTANCE/etc");

    ## create openxpki.conf
    `openxpkiadm deploy $INSTANCE/etc`;
    ok (-e "$INSTANCE/etc/$CONFIG");

    ## set correct prefix
    `cd $INSTANCE/etc && openxpki-metaconf --setcfgvalue dir.prefix=$INSTANCE`;
    ok(! $EVAL_ERROR);

    ## configure new instance
    `cd $INSTANCE/etc && openxpki-configure --batch`;
    ok (! $EVAL_ERROR);

    ## start server
    `openxpkictl --config $INSTANCE/etc/config.xml start`;
    ok (! $EVAL_ERROR);
    print STDERR "Waiting 10 seconds for server startup ...";
    sleep 10;

    ## get socketfile
    my $socketfile = `openxpki-metaconf --config $INSTANCE/etc/$CONFIG --getcfgvalue server.socketfile`;
       $socketfile =~ s{ (.*) \n+ }{$1}xms;
    ok (-e $socketfile);
}

diag( "Deploy an OpenXPKI trustcenter installation" );

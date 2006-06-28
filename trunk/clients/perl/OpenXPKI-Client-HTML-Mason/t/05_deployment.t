
use strict;
use warnings;

use Test::More tests => 18;

use English;

BEGIN {

    our ($INSTANCE, $CONFIG);
    require "t/common.pl";

    ## remove instance; from old test
    if (length $INSTANCE > 10)
    {
        `rm -rf $INSTANCE`;
    }
    ok (! -d $INSTANCE);

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
    mkdir "$INSTANCE/etc/openxpki" if (! -d "$INSTANCE/etc/openxpki");
    ok (-d "$INSTANCE/etc/openxpki");

    ## create openxpki.conf
    `openxpkiadm deploy $INSTANCE/etc/openxpki`;
    ok (-e "$INSTANCE/etc/openxpki/$CONFIG");

    ## set correct prefix
    ## set correct user and group
    `cd $INSTANCE/etc/openxpki && openxpki-metaconf --config openxpki.conf --force --setcfgvalue dir.prefix=$INSTANCE --setcfgvalue server.runuser=$UID --setcfgvalue server.rungroup=$GID --setcfg dir.localstatedir=$INSTANCE/var --setcfg dir.sysconfdir=$INSTANCE/etc --setcfg dir.openxpkiconfdir=$INSTANCE/etc/openxpki --writecfg openxpki.conf`;
    ok(! $EVAL_ERROR);

    ## configure new instance
    `cd $INSTANCE/etc/openxpki && openxpki-configure --batch --force`;
    ok (! $EVAL_ERROR);

    # create some necessary directories
    foreach my $name (qw( dir.datarootdir dir.localedir dir.localstatedir dir.openxpkistatedir dir.openxpkisessiondir ))
    {
        my $dir = `openxpki-metaconf --config $INSTANCE/etc/openxpki/$CONFIG --getcfgvalue $name`;
           $dir =~ s{ (.*) \n+ }{$1}xms;
        ok (-d $dir or mkdir $dir);
    }

    ## start server
    `openxpkictl --config $INSTANCE/etc/openxpki/config.xml start`;
    ok (! $EVAL_ERROR);
    #unnecessary - openxpkictl performs waitpid
    #print STDERR "Waiting 10 seconds for server startup ...";
    #sleep 5;

    ## get socketfile
    my $socketfile = `openxpki-metaconf --config $INSTANCE/etc/openxpki/$CONFIG --getcfgvalue server.socketfile`;
       $socketfile =~ s{ (.*) \n+ }{$1}xms;
    #print STDERR "Verifying server via socketfile $socketfile ...\n";
    ok (-e $socketfile);

    ## create a directory for the generated HTML pages
    our $OUTPUT;
    if (not -d $OUTPUT)
    {
        ok(mkdir $OUTPUT);
    } else {
        ok(1);
    }
}

diag( "Deploy an OpenXPKI trustcenter installation" );

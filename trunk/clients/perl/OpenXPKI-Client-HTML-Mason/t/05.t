use Test::More tests => 12;

use English;

BEGIN {
    ## configure test environment

    my $DEPLOYMENT = "/tmp/openxpki-client-html-mason-test";
    my $CONFIG     = "openxpki.conf";
    my $INSTANCE   = "/tmp/openxpki-client-html-mason-test/tc1";
    my $TEMPLATES  = "/etc/openxpki/templates";

    $DEPLOYMENT = $ENV{DEPLOYMENT} if (exists $ENV{DEPLOYMENT});    
    $INSTANCE   = $ENV{INSTANCE}   if (exists $ENV{INSTANCE});    
    $TEMPLATES  = $ENV{TEMPLATES}  if (exists $ENV{TEMPLATES});    

    ## check for OpenXPKI::Server
    use_ok ("OpenXPKI::Server");

    ## check for deployment tools
    ok (`openxpki-metaconf --help`);
    ok (`openxpki-configure --help`);
    ok (`openxpkictl --help`);

    ## create test directory
    if (-d $DEPLOYMENT)
    {
        `mv $DEPLOYMENT $DEPLOYMENT.old`;
    }
    ok (mkdir $DEPLOYMENT);

    ## create openxpki.conf
    `cp $TEMPLATES/$CONFIG $DEPLOYMENT/$CONFIG`;
    ok (-e "$DEPLOYMENT/$CONFIG");

    ## create fresh metaconf
    `openxpki-metaconf --config $DEPLOYMENT/$CONFIG --includesection dir,file,deployment --force --writecfg $DEPLOYMENT/$CONFIG --destdir $DEPLOYMENT --setcfgvalue dir.prefix=$DEPLOYMENT --setcfgvalue dir.sysconfdir=$INSTANCE --setcfgvalue dir.openxpkistatedir=$DEPLOYMENT/var/tc1 --setcfgvalue file.openssl=/usr/local/ssl/bin/openssl --setcfgvalue dir.datarootdir=$DEPLOYMENT/data --setcfgvalue dir.templatedir=$TEMPLATES`;
    ok (! $EVAL_ERROR);

    ## create makefile
    `openxpki-metaconf --config $DEPLOYMENT/$CONFIG --file $TEMPLATES/default/Makefile >$DEPLOYMENT/Makefile`;
    ok (! $EVAL_ERROR);

    ## install new instance
    `cd $DEPLOYMENT && make package-install`;
    ok (! $EVAL_ERROR);

    ## configure new instance
    `cd $INSTANCE && OPENXPKI_SYSCONFDIR=$INSTANCE openxpki-configure --batch`;
    ok (! $EVAL_ERROR);

    ## start server
    `openxpkictl --config $INSTANCE/config.xml start`;
    ok (! $EVAL_ERROR);
    print STDERR "Waiting 10 seconds for server startup ...";
    sleep 10;

    ## get socketfile
    my $socketfile = `openxpki-metaconf --config $DEPLOYMENT/$CONFIG --getcfgvalue server.socketfile`;
       $socketfile =~ s{ (.*) \n+ }{$1}xms;
    ok (-e $socketfile);
my $dir = `dirname $socketfile`;
print STDERR "LS: ".`ls -lisa $dir`."\n";
}

diag( "Deploy an OpenXPKI trustcenter installation" );

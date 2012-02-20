#!/usr/bin/perl
##
## Written 2006 by Julia Dubenskaya
## for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;
use Cwd;

my $man1 = "MAN1=";
my $man3 = "MAN3=";
my $line = "";
my ${PORT_NAME}=$ARGV[0];
my ${PKGNAME_PREFIX}="p5-";
my ${PORT_PATH}=cwd;
my ${PERL_VERSION} = sprintf "%vd", $^V;
	# Above works only for perl 5.10 and above 

open(SOURCE_FILE,"<${PORT_PATH}/pkg-plist.0");
open(TARGET_FILE,">${PORT_PATH}/pkg-plist");
while ($line = <SOURCE_FILE>) {
    chomp($line);
    $line =~ s/\.gz$//;
    $line =~ s/lib\/perl5\/${PERL_VERSION}\/man\/man3\//\t/;
    $line =~ s/man\/man1\//\t/;
    $line =~ s/lib\/perl5\/site_perl\/${PERL_VERSION}/\%\%SITE_PERL\%\%/;
    $line =~ s/\/mach\//\/\%\%PERL_ARCH\%\%\//;
    $line =~ s/share\/${PORT_NAME}/\%\%DATADIR\%\%/;
    $line =~ s/(dirrm)([^t])/$1try$2/;
    $line =~ s/share\/examples\/${PORT_NAME}/\%\%EXAMPLESDIR\%\%/;
    $line =~ s/share\/doc\/${PORT_NAME}/\%\%DOCSDIR\%\%/;                                                            

    $line =~ s/\A(.*\%\%DOCSDIR\%\%)/\%\%PORTDOCS\%\%$1/;
    $line =~ s/\A(.*\%\%DATADIR\%\%)/\%\%PORTDATA\%\%$1/;
    $line =~ s/\A(.*\%\%EXAMPLESDIR\%\%)/\%\%PORTEXAMPLES\%\%$1/;

    if ($line =~ m/\.1$/) {
        $man1 .= $line." \\\n";
    }
    elsif ($line =~ m/\.3$/) {
        $man3 .= $line." \\\n" if ($line =~ m/\.3$/);
    }
    else {
       print TARGET_FILE "$line\n" if (($line !~ m/share\/nls/) and 
                                       (($line !~ m/dirrm/) or
                                        ($line =~ m/openxpki/i) or ($line =~ m/DATADIR/i) or
                                        ($line =~ m/DOCSDIR/i) or
                                        ($line =~ m/EXAMPLESDIR/) or ($line =~ m/share/)
                                       )
                                      );
    }
}
close(SOURCE_FILE);
close(TARGET_FILE);

$man1 =~ s/ \\$//;
$man3 =~ s/ \\$//;

open(SOURCE_MAKEFILE,"<${PORT_PATH}/Makefile.bak");
open(TARGET_MAKEFILE,">${PORT_PATH}/Makefile");

my $MAKEFILE_DATA = "";
while ($line = <SOURCE_MAKEFILE>) {
    chomp($line);
    $MAKEFILE_DATA .= $line."\n"; 
}

$MAKEFILE_DATA =~ s/MAN1=(.*\s*)*\.1\s/$man1/m;
$MAKEFILE_DATA =~ s/MAN3=(.*\s*)*\.3\s/$man3/m;

print TARGET_MAKEFILE $MAKEFILE_DATA;

close(SOURCE_MAKEFILE);
close(TARGET_MAKEFILE);


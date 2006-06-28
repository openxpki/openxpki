
use strict;
use warnings;

## configure test environment

our $PWD      = `pwd`;
    $PWD      =~ s/\n//g;
our $INSTANCE = "$PWD/t/tc1";
our $CONFIG   = "openxpki.conf";
our $OUTPUT   = "t/html_output";

$INSTANCE   = $ENV{INSTANCE}   if (exists $ENV{INSTANCE});    

$ENV{DOCUMENT_ROOT}        = "$PWD/htdocs"; ## comp_path
$ENV{OPENXPKI_SOCKET_FILE} = "$PWD/t/tc1/var/openxpki/openxpki.socket";

1;

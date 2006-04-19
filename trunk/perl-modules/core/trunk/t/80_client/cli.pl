#!/usr/bin/perl

use strict;
use warnings;
use English;
use OpenXPKI::Debug;
$OpenXPKI::Debug::LEVEL{'OpenXPKI::.*'} = 100;
eval
{
    require OpenXPKI::Client::CLI;
    my $cli = OpenXPKI::Client::CLI->new({CONFIG => "t/80_client/cli.conf"});
    $cli->init();
    $cli->run();
    undef $cli;
};
if ($EVAL_ERROR)
{
    print STDERR "Exception: ${EVAL_ERROR}\n";
}

1;

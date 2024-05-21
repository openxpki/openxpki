#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp;

# CPAN modules
use Test::More;
use Test::Deep ':v1';
use Test::Exception;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({
    level => $ENV{TEST_VERBOSE} ? $TRACE : $OFF,
    layout  => '# %-5p %m%n',
});

# Project modules
use lib "$Bin/lib";


use_ok "OpenXPKI::TestCommandsTypes";

my $content =
     "Es schlug mein Herz, geschwind zu Pferde!\n"
    ."Es war getan fast eh gedacht;\n"
    ."Der Abend wiegte schon die Erde,\n"
    ."Und an den Bergen hing die Nacht.";

my ($fh, $filename) = File::Temp::tempfile(UNLINK => 1);
print $fh $content;
close $fh;

my $api;
lives_ok {
    $api = OpenXPKI::TestCommandsTypes->new(
        log => Log::Log4perl->get_logger,
        enable_acls => 0,
    );
} "instantiate";

lives_and {
    my $result = $api->dispatch(command => "showfile", params => { file => $filename });
    is $result->$*, $content;
} "'FileContents' type fetches the file contents";

done_testing;

1;

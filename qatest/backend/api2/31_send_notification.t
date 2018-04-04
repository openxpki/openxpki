#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw( tempdir );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 1;


#
# Init helpers
#
my $message_id = "warning";
my $tempdir = tempdir(CLEANUP => 1);
open my $fh, ">", "$tempdir/$message_id"
    or die "Could not write notification template to temp file: $@";
print $fh q(
Hear [% data.target %]!
You shall not [% data.forbidden %]. See [% meta_baseurl %]. Proceed!
);
close $fh;

use TestNotificationDummyHandler;

my $oxitest = OpenXPKI::Test->new(
    add_config => {
        "realm.test.notification.dummy" => {
            backend => {
                class => "TestNotificationDummyHandler",
            },
            template => {
                dir => $tempdir,
            },
        },
    },
);

lives_and {
    my $result = $oxitest->api2_command("send_notification" => {
        message => $message_id,
        params => {
            target => "rock",
            forbidden => "move",
        },
    });
    my $url = $oxitest->get_config("system.realms.test.baseurl");
    like $TestNotificationDummyHandler::RESULT, qr{ rock .* move .* \Q$url\E }msxi;
} "Invoke notification handler";

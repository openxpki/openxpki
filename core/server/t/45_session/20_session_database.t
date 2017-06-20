package main;
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw( tempdir );

# CPAN modules
use Test::More;
use Test::Exception;
use Test::Deep;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($OFF);

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Session.*'} = 100;

plan tests => 4;

#
# Setup test env
#
my $oxitest = OpenXPKI::Test->new;
$oxitest->setup_env;

#
# Tests
#
sub driver_ok {
    my ($args) = @_;

    subtest lc($args->{type})." backed session" => sub {
        ## create new session
        my $session;
        lives_ok {
            $session = OpenXPKI::Server::SessionHandler->new(%{ $args })->create;
        } "create session";

        # set all attributes except "user" (and those not comparable as scalars):
        # "user" is left out to test persist/resume for uninitialized attributes
        for my $name (grep { $_ !~ /^(modified|_secrets|user)$/ } @{ $session->data->get_attribute_names }) {
            $session->data->$name(int(rand(2**32-1)));
        }
        $session->data->secret(group => "golf", secret => 333);
        $session->data->secret(group => "ballet", secret => 222);

        # persist
        lives_ok {
            $session->persist;
        } "persist session";

        my $session2;
        lives_and {
            $session2 = OpenXPKI::Server::SessionHandler->new(%{ $args });
            ok $session2->resume($session->id);
        } "resume session";

        # verify data is equal
        lives_and {
            my $d1 = $session->data_as_hashref;  delete $d1->{modified};
            my $d2 = $session2->data_as_hashref; delete $d2->{modified};
            cmp_deeply $d2, $d1;
        } "data is the same after freeze-thaw-cycle";

        # make sure session expires
        sleep 2;

        lives_and {
            my $temp = OpenXPKI::Server::SessionHandler->new(%{ $args }, lifetime => 1);
            ok not $temp->resume($session->id);
        } "fail resuming an expired session";

        lives_and {
            my $temp = OpenXPKI::Server::SessionHandler->new(%{ $args }, lifetime => 1)->create;
            $temp->purge_expired;
            ok not $temp->driver->load($session->id);
        } "purge expired sessions from backend";

        # delete a session
        my $session3;
        lives_and {
            $session3 = OpenXPKI::Server::SessionHandler->new(%{ $args })->create;
            $session3->data->user("test");
            $session3->persist;
            my $temp = OpenXPKI::Server::SessionHandler->new(%{ $args })->resume($session3->id);
            is $temp->data->user, $session3->data->user;
        } "delete test: create and persist session";

        lives_and {
            my $id = $session3->id;
            $session3->delete;
            ok not OpenXPKI::Server::SessionHandler->new(%{ $args })->resume($id);
        } "delete test: delete session";

    }
}

sub dir_empty {
    my $path = shift;
    opendir my $dir, $path or die $!;
    if (grep ! /^\.\.?\z/, readdir $dir ) {
        return 0;
    }
    return 1;
}

use_ok "OpenXPKI::Server::SessionHandler";

# FILE backed session
my $tempdir = tempdir( CLEANUP => 1 );
driver_ok {
    type => "File",
#    log  => Log::Log4perl->get_logger(),
    config => { directory => $tempdir },
};
ok dir_empty($tempdir), "Session storage directory is empty";

# DATABASE backed session
driver_ok {
    type => "Database",
#    log  => Log::Log4perl->get_logger(),
    config => { dbi => $oxitest->dbi },
};

1;

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

plan tests => 5;

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

    subtest $args->{descr} => sub {
        ## create new session
        my $session;
        my $factory = sub { OpenXPKI::Server::Session->new(%{ $args }, @_) };

        lives_ok {
            $session = $factory->()->create;
        } "create session";

        # set all attributes except "user" (and those not comparable as scalars):
        # "user" is left out to test persist/resume for uninitialized attributes
        for my $name (grep { $_ !~ /^(modified|_secrets|user|is_valid)$/ } @{ $session->data->get_attribute_names }) {
            $session->data->$name(int(rand(2**32-1)));
        }
        $session->is_valid(1);
        $session->data->secret(group => "golf", value => 333);
        $session->data->secret(group => "ballet", value => 222);

        # persist
        lives_ok {
            $session->persist;
        } "persist session";

        my $session2;
        lives_and {
            $session2 = $factory->();
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
            my $temp = $factory->(lifetime => 1);
            ok not $temp->resume($session->id);
        } "fail resuming an expired session";

        lives_and {
            my $temp = $factory->(lifetime => 1)->create;
            $temp->purge_expired;
            ok not $temp->driver->load($session->id);
        } "purge expired sessions from backend";

        # regenerate session ID
        my $session3;
        lives_and {
            $session3 = $factory->()->create;
            $session3->data->user("sally");
            $session3->persist;
            my $temp = $factory->()->resume($session3->id);
            is $temp->data->user, "sally";
        } "create, persist and resume new session";

        lives_and {
            my $oldid = $session3->id;
            $session3->new_id;
            isnt $session3->id, $oldid;
        } "create a new ID for existing session";

        lives_and {
            my $temp = $factory->()->resume($session3->id);
            is $temp->data->user, "sally";
        } "resume session using the new ID";

        # delete a session
        lives_and {
            my $id = $session3->id;
            $session3->delete;
            ok not $factory->()->resume($id);
        } "delete session";

        # SCEP data object
        use_ok "OpenXPKI::Server::Session::Data::SCEP";

        my $session4;
        lives_and {
            # persist
            $session4 = $factory->(data_class => "OpenXPKI::Server::Session::Data::SCEP")->create;
            $session4->data->profile("low");
            $session4->persist;
            # resume
            my $temp = $factory->(data_class => "OpenXPKI::Server::Session::Data::SCEP")->resume($session4->id);
            # check
            is $temp->data->profile, "low";
            $session4->delete;
        } "create, persist and resume session with SCEP data object";
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

use_ok "OpenXPKI::Server::Session";

my $tempdir = tempdir( CLEANUP => 1 );

# FILE backed session
driver_ok {
    type => "File",
    config => { directory => $tempdir },
    descr => "Session with file backend",
};
ok dir_empty($tempdir), "Session storage directory is empty";

# DATABASE backed session
driver_ok {
    type => "Database",
    config => { dbi => $oxitest->dbi },
    descr => "Session with database backend (existing DB handle)",
};


# CUSTOM DATABASE backed session
my $dbi = OpenXPKI::Server::Database->new(
    db_params => {
        type => "SQLite",
        name => "$tempdir/test.sqlite",
    },
    autocommit => 1,
    log => Log::Log4perl->get_logger,
);

#
# Uuuh oooh this is ugly copy-n-paste, I know.
# Currently there is no way to access the DB schema to rebuild it in tests
#
$dbi->run(qq(
CREATE TABLE mysess (
  session_id varchar(255) NOT NULL,
  data longtext,
  created decimal(49,0) NOT NULL,
  modified decimal(49,0) NOT NULL,
  ip_address varchar(45),
  PRIMARY KEY (session_id)
);
));

# DATABASE backed session with custom DB driver
driver_ok {
    type => "Database",
    config => {
        driver => "SQLite",
        name => "$tempdir/test.sqlite",
        table => "mysess",
    },
    descr => "Session with custom database backend",
};

1;

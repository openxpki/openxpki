#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use DateTime;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({
    level => $ENV{TEST_VERBOSE} ? $DEBUG : $OFF,
    layout  => '# %-5p %m%n',
});

# Project modules
use lib "$Bin/lib";


plan tests => 12;


use_ok "OpenXPKI::Server::API2";

my $api;

my $CURRENT_ROLE;

lives_ok {
    $api = OpenXPKI::Server::API2->new(
        namespace => "OpenXPKI::TestCommands",
        log => Log::Log4perl->get_logger(),
        acl_rule_accessor => sub {
            return {
                mean_child => {
                    commands => {
                        scream => {
                            how => {
                                default => "loud",
                                match => '\A (loud|louder) \z',
                            }
                        },
                    }
                },
                sweet_child => {
                    commands => {
                        scream => {
                            how => {
                                force => "never",
                            },
                        },
                    },
                },
                quick_child => {
                    commands => {
                        scream => 1,
                    },
                },
                regulated_child => {
                    commands => {
                        scream => {
                            whom => {
                                block => 1,
                            },
                        },
                    },
                },
            }->{$CURRENT_ROLE};
        },
    );
} "instantiate";


throws_ok {
    $CURRENT_ROLE = "unborn_child";
    my $result = $api->dispatch(command => "scream");
} qr/not permit/, "complain about unknown role" or die;

throws_ok {
    $CURRENT_ROLE = "mean_child";
    my $result = $api->dispatch(command => "givetheparams");
} qr/not permit/, "complain about forbidden command" or die;

#
# default parameters
#
$CURRENT_ROLE = "mean_child";
lives_and {
    my $result = $api->dispatch(command => "scream", params => { what => "boo" } );
    like $result, qr/:loud:.*boo/;
} "apply parameter defaults" or die;

lives_and {
    my $result = $api->dispatch(command => "scream", params => { how => "louder", what => "boo" } );
    like $result, qr/:louder:.*boo/;
} "overwrite parameter defaults and match regex" or die;

throws_ok {
    my $result = $api->dispatch(command => "scream", params => { how => "insanely", what => "boo" } );
} qr/does not match/, "complain about non-matching parameters" or die;

#
# forced parameters
#
$CURRENT_ROLE = "sweet_child";
lives_and {
    my $result = $api->dispatch(command => "scream", params => { what => "boo" } );
    like $result, qr/:never:.*boo/;
} "set parameter to forced value" or die;

lives_and {
    my $result = $api->dispatch(command => "scream", params => { how => "loud", what => "boo" } );
    like $result, qr/:never:.*boo/;
} "overwrite given parameter with forced value" or die;

#
# quick spec of allowed command
#
$CURRENT_ROLE = "quick_child";
lives_and {
    my $result = $api->dispatch(command => "scream", params => { how => "shortly", what => "boo" } );
    like $result, qr/:shortly:.*boo/;
} "accept quick command spec in ACL" or die;

#
# blocked parameters
#
$CURRENT_ROLE = "regulated_child";
lives_and {
    my $result = $api->dispatch(command => "scream", params => { how => "properly", what => "Hi" } );
    like $result, qr/:properly:.*Hi.*to Albert/;
} "ignored blocked parameters if not given" or die;

throws_ok {
    my $result = $api->dispatch(command => "scream", params => { how => "properly", what => "Hi", whom => "Mom" } );
} qr/blocked/, "complain about blocked parameters if given" or die;

1;

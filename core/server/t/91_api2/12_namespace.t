#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep ':v1';
use Test::Exception;
use DateTime;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({
    level => $ENV{TEST_VERBOSE} ? $TRACE : $OFF,
    layout  => '# %-5p %m%n',
});

# Project modules
use lib "$Bin/lib";


use_ok "OpenXPKI::TestCommandsNamespace";

my $api;
lives_ok {
    $api = OpenXPKI::TestCommandsNamespace->new(
        log => Log::Log4perl->get_logger,
        enable_acls => 0,
    );
} "instantiate";

lives_and {
    cmp_deeply [ keys $api->commands->%* ], ['info'];
} "query available commands in root namespace";

lives_and {
    is $api->has_non_root_namespaces, 1;
} "has_non_root_namespaces == TRUE";

lives_and {
    cmp_deeply [ keys $api->commands('config')->%* ], bag(qw( info show ));
} "query available commands in 'config' namespace";

lives_and {
    cmp_deeply [ keys $api->commands('user')->%* ], bag(qw( create delete ));
} "query available commands in 'user' namespace";

lives_and {
    cmp_deeply [ keys $api->commands('workflow')->%* ], bag(qw( create pickup ));
} "query available commands in 'workflow' namespace";

throws_ok {
    $api->dispatch(rel_namespace => 'TheUnknown', command => 'create');
} qr/unknown[\w\s]+namespace/i, "complain about unknown API namespace";

throws_ok {
    $api->dispatch(rel_namespace => 'config', command => 'create');
} qr/unknown[\w\s]+command/i, "complain about unknown API command (wrong namespace)";

lives_and {
    my $result = $api->dispatch(rel_namespace => 'config', command => 'info');
    is $result, 'CONFIG_INFO';
} "execute config.info";

lives_and {
    my $result = $api->dispatch(rel_namespace => 'config', command => 'show');
    cmp_deeply $result, { a => 1, b => 2 };
} "execute config.show";

lives_and {
    my $result = $api->dispatch(rel_namespace => 'user', command => 'create');
    is $result, 'USER_CREATED';
} "execute user.create";

lives_and {
    my $result = $api->dispatch(rel_namespace => 'workflow', command => 'create');
    is $result, 'WF_CREATED';
} "execute workflow.create";

#
# Conflicting namespace name / command name
#

use_ok "OpenXPKI::TestCommandsNamespaceConflict";

lives_ok {
    $api = OpenXPKI::TestCommandsNamespaceConflict->new(
        log => Log::Log4perl->get_logger,
        enable_acls => 0,
    );
} "instantiate";

throws_ok {
    $api->dispatch(rel_namespace => 'TheUnknown', command => 'create');
} qr/command.*info.*equals.*namespace/i, "complain about conflicting command name and namespace name";

done_testing;

1;

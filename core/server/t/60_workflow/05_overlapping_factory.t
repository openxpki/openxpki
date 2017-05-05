use strict;
use warnings;

#use Test::More tests => 27;
use Test::More skip_all => 'See Issue #188';

use OpenXPKI::XML::Cache;
use OpenXPKI::Workflow::Handler;
use OpenXPKI::Workflow::Factory qw( FACTORY );

use OpenXPKI::Debug;
use Data::Dumper;
use English;

if ($ENV{DEBUG}) {
    $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Init'} = 128;
}

note "Test overlapping use of two factories";

my $xml_config = OpenXPKI::XML::Cache->new(CONFIG => 't/60_workflow/05_workflow.xml');
my $ser = $xml_config->get_serialized();

my $xml_config_restored = OpenXPKI::XML::Cache->new(SERIALIZED_CACHE => $ser);

is_deeply($xml_config->{cache}, $xml_config_restored->{cache}, 'Deep compare');

# Init the database handler and api stuff
require 't/60_workflow/common.pl';

my $handler = OpenXPKI::Workflow::Handler->new();
my $factory = $handler->get_factory({ XML_CONFIG => $xml_config });
is(ref $factory, 'OpenXPKI::Workflow::Factory');

my $xml_config2 = OpenXPKI::XML::Cache->new(CONFIG => 't/60_workflow/05_workflow2.xml');
my $factory2 = $handler->get_factory({ XML_CONFIG => $xml_config2 });
is(ref $factory2, 'OpenXPKI::Workflow::Factory');

my $workflow = $factory->create_workflow('dummy workflow');
is(ref $workflow, 'OpenXPKI::Server::Workflow');

my @actions = $workflow->get_current_actions();
is_deeply(@actions, ('noop'));

my $workflow2 = $factory2->create_workflow('dummy workflow');
is(ref $workflow2, 'OpenXPKI::Server::Workflow');

@actions = $workflow2->get_current_actions();
is_deeply(@actions, ('nothing'));

do_step($workflow, 
    EXPECTED_STATE => 'INITIAL',
    EXPECTED_ACTIONS => [ 'noop' ],
    EXECUTE_ACTION => "noop",
);

do_step($workflow2, 
    EXPECTED_STATE => 'INITIAL',
    EXPECTED_ACTIONS => [ 'nothing' ],
    EXECUTE_ACTION => "nothing",
);

do_step($workflow2, 
    EXPECTED_STATE => 'step1',
    EXPECTED_ACTIONS => [ 'nothing' ],
);

do_step($workflow, 
    EXPECTED_STATE => 'state1',
    EXPECTED_ACTIONS => [ 'noop' ],
);

done_testing();

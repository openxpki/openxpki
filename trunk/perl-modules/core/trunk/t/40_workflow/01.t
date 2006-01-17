use strict;
use warnings;
use English;
use Data::Dumper;
use Test;

# use Smart::Comments;

use Workflow::Factory;

BEGIN { plan tests => 29; };

print STDERR "OpenXPKI::Server::Workflow - Persistence\n";

our $basedir;

require 't/40_workflow/common.pl';


my $debug = $ENV{DEBUG};
### Debug: $debug

my $factory = Workflow::Factory->instance();

### reading Workflow configuration...
$factory->add_config_from_file(
    workflow  => "$basedir/01_workflow.xml",
    action    => "$basedir/01_workflow_activity.xml",
    persister => "$basedir/01_workflow_persister.xml",
    );


### instantiate new basic request workflow instance...
my $workflow = $factory->create_workflow('dummy workflow');

# save workflow id for later reference (fetch operation)
my $workflow_id = $workflow->id();
### Workflow id: $workflow_id

    
# uncomment to show the workflow instance
# show_workflow_instance($workflow);

# save some dummy parameters in workflow context
$workflow->context()->param(foo  => 'barbaz');
$workflow->context()->param(pkirealm  => 'Test Root CA');

# create some bulk (Unicode) data
my $data = pack "U*", (1 .. 32768);
$workflow->context()->param(bulkdata  => $data);

# check if context entries are persistent
ok($workflow->context()->param('foo'), 'barbaz');
ok($workflow->context()->param('pkirealm'), 'Test Root CA');
ok($workflow->context()->param('bulkdata'), $data);

do_step($workflow, 
	EXPECTED_STATE => 'INITIAL',
	EXPECTED_ACTIONS => [ 'null' ],
	EXECUTE_ACTION => 'null',
    );

# delete context instance
$workflow = undef;
# and resurrect it
$workflow = $factory->fetch_workflow('dummy workflow', $workflow_id);

# check if we got the correct workflow back
ok($workflow->id(), $workflow_id);

# check if context entries are persistent
ok($workflow->context()->param('foo'), 'barbaz');
ok($workflow->context()->param('pkirealm'), 'Test Root CA');
ok($workflow->context()->param('bulkdata') eq $data);

### do_step
do_step($workflow, 
	EXPECTED_STATE => 'state1',
	EXPECTED_ACTIONS => [ 'null' ],
	EXECUTE_ACTION => 'null',
    );

# delete context instance
$workflow = undef;
# and resurrect it
$workflow = $factory->fetch_workflow('dummy workflow', $workflow_id);

# check if we got the correct workflow back
ok($workflow->id(), $workflow_id);

# check if context entries are persistent
ok($workflow->context()->param('foo'), 'barbaz');
ok($workflow->context()->param('pkirealm'), 'Test Root CA');
ok($workflow->context()->param('bulkdata') eq $data);

### do_step
do_step($workflow, 
	EXPECTED_STATE => 'FINISHED',
	EXPECTED_ACTIONS => [ ],
    );

# delete context instance
$workflow = undef;
# and resurrect it
$workflow = $factory->fetch_workflow('dummy workflow', $workflow_id);

# check if we got the correct workflow back
ok($workflow->id(), $workflow_id);

# check if context entries are persistent
ok($workflow->context()->param('foo'), 'barbaz');
ok($workflow->context()->param('pkirealm'), 'Test Root CA');
ok($workflow->context()->param('bulkdata') eq $data);


1;

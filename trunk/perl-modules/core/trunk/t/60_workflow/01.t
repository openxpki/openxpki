use strict;
use warnings;
use English;
use Data::Dumper;
use Test;

# use Smart::Comments;


BEGIN { plan tests => 38 };

print STDERR "OpenXPKI::Server::Workflow - Persistence\n";

our $basedir;

require 't/60_workflow/common.pl';

# workflow requires an initialized Log4perl system and tries to access it
# in its BEGIN block, hence require it here
require Workflow::Factory;

`cp t/30_dbi/sqlite.db t/30_dbi/sqlite.db._workflow_`;
ok(not $CHILD_ERROR);


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


# save some dummy parameters in workflow context
$workflow->context()->param(foo  => 'barbaz');
$workflow->context()->param(pkirealm  => 'Test Root CA');

# create some binary data (16 KB)
my $binary_data = pack "C*", (0 .. 255) x (4 * 16);
$workflow->context()->param(binarydata => $binary_data);

# create some bulk (Unicode) data
#my $data = pack "U*", (1 .. 32768);
my $data;
foreach my $unicode_index (1 .. 32768) {
    # chr returns the unicode character here
    my $char = chr($unicode_index);
    if (length($char) and $char =~ m{ \A \p{Assigned} \z }xms) {
	$data .= $char;
    }
}

$workflow->context()->param(bulkdata  => $data);


### check if context entries are available...
ok($workflow->context()->param('foo'), 'barbaz');
ok($workflow->context()->param('pkirealm'), 'Test Root CA');


### try to execute action (expect exception because of the binary data)
eval {
    do_step($workflow, 
	    EXPECTED_STATE => 'INITIAL',
	    EXPECTED_ACTIONS => [ 'null' ],
	    EXECUTE_ACTION => 'null',
	    PASS_EXCEPTION => 1,
	);
};
if (my $exc = OpenXPKI::Exception->caught()) {
    ### got expected exception
    ok($exc->message(), 
       "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_UPDATE_WORKFLOW_CONTEXT_VALUE_ILLEGAL_DATA"); # expected error
} else {
    ### no exception...
    ok(0);
}


### now delete the offending parameter...
# work around a bug in Workflow::Base::param() that does not allow to
# set reset a single parameter. It works when called with a hash ref, though.
$workflow->context()->param({ binarydata => undef });


### create a volatile data object
$workflow->context()->param(_binarydata => $binary_data);
ok($workflow->context()->param('_binarydata') eq $binary_data);

### execute null action
do_step($workflow, 
	EXPECTED_STATE => 'INITIAL',
	EXPECTED_ACTIONS => [ 'null' ],
	EXECUTE_ACTION => 'null',
    );

### expect that the volatile object is still around
ok($workflow->context()->param('_binarydata') eq $binary_data);

### delete context instance
$workflow = undef;
### and resurrect it
$workflow = $factory->fetch_workflow('dummy workflow', $workflow_id);

### check if we got the correct workflow back...
ok($workflow->id(), $workflow_id);

### expect that the volatile object is now gone
ok($workflow->context()->param('_binarydata'), undef);

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

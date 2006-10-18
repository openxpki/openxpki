use strict;
use warnings;
use Test;
use DateTime;

BEGIN { plan tests => 26 };

print STDERR "OpenXPKI::Server::DBI: Queries with constraints and joins\n";

use OpenXPKI::Server::DBI;
# use Smart::Comments;

ok (1);

our %config;
our $dbi;
require 't/30_dbi/common.pl';

ok (1);

# insert some sample data
my $history_id = 100000;
foreach my $ii (10001 .. 10005) {
    $dbi->insert(
	TABLE => 'WORKFLOW',
	HASH => 
	{
	    WORKFLOW_SERIAL         => $ii,
	    PKI_REALM               => 'Test Root CA',
	    WORKFLOW_TYPE           => 'Dummy Workflow',
	    WORKFLOW_VERSION_SERIAL => -1,
	    WORKFLOW_STATE          => 'INITIAL',
	    WORKFLOW_LAST_UPDATE    => DateTime->now->strftime( '%Y-%m-%d %H:%M' ),
	});

    $dbi->insert(
	TABLE => 'WORKFLOW_HISTORY',
	HASH => {
	    WORKFLOW_HISTORY_SERIAL => $history_id++,
	    WORKFLOW_SERIAL         => $ii,
	    WORKFLOW_ACTION         => 'create_workflow',
	    WORKFLOW_DESCRIPTION    => 'Created instance',
	    WORKFLOW_STATE          => 'INITIAL',
	    WORKFLOW_USER           => 'dummy',
	    WORKFLOW_HISTORY_DATE   => DateTime->now->strftime( '%Y-%m-%d %H:%M' ),
	});
    

    foreach my $jj (0 .. 9) {
	my $key = "somekey-" . $jj;
	my $value = "somevalue: " . ($jj + $ii * 10);

	$dbi->insert(
	    TABLE => 'WORKFLOW_CONTEXT',
	    HASH =>
	    {
		WORKFLOW_SERIAL => $ii,
		WORKFLOW_CONTEXT_KEY => $key,
		WORKFLOW_CONTEXT_VALUE => $value,
	    });

	$dbi->insert(
	    TABLE => 'WORKFLOW_HISTORY',
	    HASH => {
		WORKFLOW_HISTORY_SERIAL => $history_id++,
		WORKFLOW_SERIAL         => $ii,
		WORKFLOW_ACTION         => 'add_context',
		WORKFLOW_DESCRIPTION    => "Added context value $key->$value",
		WORKFLOW_STATE          => 'INITIAL',
		WORKFLOW_USER           => 'dummy',
		WORKFLOW_HISTORY_DATE   => DateTime->now->strftime( '%Y-%m-%d %H:%M' ),
	    });
	
    }
}

ok($dbi->commit());

# simple ranged queries
my $result;

$result = $dbi->select(
    TABLE => 'WORKFLOW_HISTORY',
    FROM => 100020,
    TO => 100039,
    );

ok(scalar @{$result}, 20);


# simple query for default index field
$result = $dbi->select(
    TABLE => 'WORKFLOW_HISTORY',
    SERIAL => 100020,
    );

ok(scalar @{$result}, 1);


# simple query for default index field
$result = $dbi->select(
    TABLE => 'WORKFLOW_HISTORY',
    DYNAMIC => {
	WORKFLOW_DESCRIPTION => 'Added context value somekey-3->somevalue: 100043',
    },
    );

ok(scalar @{$result}, 1);


# simple compound query for default index field
$result = $dbi->select(
    TABLE => 'WORKFLOW_HISTORY',
    DYNAMIC => {
	WORKFLOW_DESCRIPTION => [ 
	    'Added context value somekey-3->somevalue:%',
	    '%100043',
	    ],
    },
    );

ok(scalar @{$result}, 1);



# SELECT 
#    workflow.workflow_id, 
#    workflow_context.workflow_context_key, 
#    workflow_context.workflow_context_value 
# FROM workflow, workflow_context, workflow_history 
# WHERE workflow.workflow_id=workflow_context.workflow_id 
#   AND workflow_context.workflow_id=workflow_history.workflow_id 
#   AND workflow_history.workflow_description like ? 
# ORDER BY workflow.workflow_id, 
#   workflow_context.workflow_context_key, 
#   workflow_context.workflow_context_value
$result = $dbi->select(
    #          first table second table        third table
    TABLE => [ 'WORKFLOW', 'WORKFLOW_CONTEXT', 'WORKFLOW_HISTORY' ],

    # return these columns
    COLUMNS => [ 'WORKFLOW.WORKFLOW_SERIAL', 'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_KEY', 'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_VALUE' ],
    
    JOIN => [
	#  on first table     second table       third
	[ 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL' ],
    ],
    DYNAMIC => {
	'WORKFLOW_HISTORY.WORKFLOW_DESCRIPTION' => 'Added context value somekey-3->somevalue: 100043',
    },
    );

### $result

ok(scalar @{$result}, 10);
ok($result->[0]->{'WORKFLOW.WORKFLOW_SERIAL'}, 10004);
ok($result->[9]->{'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_VALUE'}, 'somevalue: 100049');


###########################################################################
# test aliases table names

# SELECT 
#    workflow.workflow_id, 
#    context1.workflow_context_value 
#    context2.workflow_context_value 
# FROM workflow, workflow_context as context1, workflow_context as context2
# WHERE workflow.workflow_id=context1.workflow_id 
#   AND context1.workflow_id=context2.workflow_id 
#   AND context1.workflow_context_key like ?
#   AND context1.workflow_context_value like ?
#   AND context2.workflow_context_key like ?
#   AND context2.workflow_context_value like ?
# ORDER BY workflow.workflow_id, 
#   context1.workflow_context_value, 
#   context2.workflow_context_value
$result = $dbi->select(
    #          first table second table                          third table
    TABLE => [ 'WORKFLOW', 
	       [ 'WORKFLOW_CONTEXT' => 'context1' ], 
	       [ 'WORKFLOW_CONTEXT' => 'context2' ] ],
    
    # return these columns
    COLUMNS => [ 'WORKFLOW.WORKFLOW_SERIAL', 'context1.WORKFLOW_CONTEXT_VALUE', 'context2.WORKFLOW_CONTEXT_VALUE' ],
    
    JOIN => [
	#  on first table     second table       third
	[ 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL' ],
    ],
    DYNAMIC => {
	'context1.WORKFLOW_CONTEXT_KEY' => 'somekey-5',
	'context1.WORKFLOW_CONTEXT_VALUE' => 'somevalue: 100045',
	'context2.WORKFLOW_CONTEXT_KEY' => 'somekey-7',
	'context2.WORKFLOW_CONTEXT_VALUE' => 'somevalue: 100047',
    },
    );

### $result

ok(scalar @{$result}, 1);
ok($result->[0]->{'WORKFLOW.WORKFLOW_SERIAL'}, 10004);
ok($result->[0]->{'context1.WORKFLOW_CONTEXT_VALUE'}, 'somevalue: 100045');
ok($result->[0]->{'context2.WORKFLOW_CONTEXT_VALUE'}, 'somevalue: 100047');



# get unique key values for workflow context
# 
# SELECT 
#    DISTINCT workflow_context.workflow_context_key
#    workflow.workflow_id
# FROM workflow, workflow_context
# WHERE workflow.workflow_id=workflow_context.workflow_id 
#   AND workflow_context.workflow_id=?
# ORDER BY workflow_context.workflow_context_key, 
#   workflow.workflow_id
$result = $dbi->select(
    #          first table second table
    TABLE => [ 'WORKFLOW', 'WORKFLOW_CONTEXT' ],

    # return these columns
    COLUMNS => [ 
	{ 
	    COLUMN   => 'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_KEY',
	    DISTINCT => 1,
	},
	'WORKFLOW.WORKFLOW_SERIAL', 
    ],
    JOIN => [
	#  on first table     second table   
	[ 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL' ],
    ],
    DYNAMIC => {
	'WORKFLOW.WORKFLOW_SERIAL' => '10004',
    },
    );

### $result

ok(scalar @{$result}, 10);
ok($result->[0]->{'WORKFLOW.WORKFLOW_SERIAL'}, 10004);
ok($result->[0]->{'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_KEY'}, 'somekey-0');
# ..
ok($result->[9]->{'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_KEY'}, 'somekey-9');



# SELECT 
#    MAX(workflow_context.workflow_context_key),
#    workflow.workflow_id
# FROM workflow, workflow_context
# WHERE workflow.workflow_id=workflow_context.workflow_id 
#   AND workflow_context.workflow_id=?
# ORDER BY workflow_context.workflow_context_key, 
#   workflow.workflow_id
$result = $dbi->select(
    #          first table second table
    TABLE => [ 'WORKFLOW', 'WORKFLOW_CONTEXT' ],

    # return these columns
    COLUMNS => [ 
	{ 
	    COLUMN   => 'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_KEY',
	    #DISTINCT => 1,
	    AGGREGATE => 'MAX',
	},
	'WORKFLOW.WORKFLOW_SERIAL', 
    ],
    JOIN => [
	#  on first table     second table   
	[ 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL' ],
    ],
    DYNAMIC => {
	'WORKFLOW.WORKFLOW_SERIAL' => '10004',
    },
    );

### $result

ok(scalar @{$result}, 1);
ok($result->[0]->{'WORKFLOW.WORKFLOW_SERIAL'}, 10004);
ok($result->[0]->{'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_KEY'}, 'somekey-9');

1;

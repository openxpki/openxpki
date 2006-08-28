use strict;
use warnings;
use Test;
use DateTime;

BEGIN { plan tests => 12 };

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

# simple queries
my $result;

$result = $dbi->select(
    TABLE => 'WORKFLOW_HISTORY',
    FROM => 100020,
    TO => 100039,
    );

ok(scalar @{$result}, 20);


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

1;

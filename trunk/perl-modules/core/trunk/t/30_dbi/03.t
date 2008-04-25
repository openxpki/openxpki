use strict;
use warnings;
use Test::More;
use DateTime;
use English;

plan tests => 50;

diag "OpenXPKI::Server::DBI: Queries with constraints and joins\n";

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


# insert dummy certificates
# please note that previous tests insert two additional certificates:
# valid -2 years to now and
# valid now to +2 years

my $cert_serial = 1;
my $attribute_serial = 1;
my $now = time;

# 1 expired
$dbi->insert(
    TABLE => 'CERTIFICATE_ATTRIBUTES',
    HASH => 
    {
	IDENTIFIER               => "dummy_identifier_$cert_serial",
	ATTRIBUTE_KEY            => 'dummy key',
	ATTRIBUTE_VALUE          => 'dummy value',
	ATTRIBUTE_SERIAL         => $attribute_serial++,
    });

$dbi->insert(
    TABLE => 'CERTIFICATE',
    HASH => 
    {
	IDENTIFIER               => "dummy_identifier_$cert_serial",
	PKI_REALM                => 'Test Root CA',
	ISSUER_IDENTIFIER        => 'issuer_dummy_identifier',
	ISSUER_DN                => 'n/a',
	DATA                     => 'n/a',
	SUBJECT                  => 'Dummy Certificate $cert_serial',
	EMAIL                    => 'n/a',
	STATUS                   => 'ISSUED',
	ROLE                     => 'n/a',
	PUBKEY                   => 'n/a',
	SUBJECT_KEY_IDENTIFIER   => 'n/a',
	AUTHORITY_KEY_IDENTIFIER => 'n/a',
	NOTBEFORE                => $now - 86400,
	NOTAFTER                 => $now - 1,
	LOA                      => 'n/a',
	CSR_SERIAL               => 'n/a',
	CERTIFICATE_SERIAL       => $cert_serial++,
    });

# 1 valid
$dbi->insert(
    TABLE => 'CERTIFICATE_ATTRIBUTES',
    HASH => 
    {
	IDENTIFIER               => "dummy_identifier_$cert_serial",
	ATTRIBUTE_KEY            => 'dummy key',
	ATTRIBUTE_VALUE          => 'dummy value',
	ATTRIBUTE_SERIAL         => $attribute_serial++,
    });

$dbi->insert(
    TABLE => 'CERTIFICATE',
    HASH => 
    {
	IDENTIFIER               => "dummy_identifier_$cert_serial",
	PKI_REALM                => 'Test Root CA',
	ISSUER_IDENTIFIER        => 'issuer_dummy_identifier',
	ISSUER_DN                => 'n/a',
	DATA                     => 'n/a',
	SUBJECT                  => 'Dummy Certificate $cert_serial',
	EMAIL                    => 'n/a',
	STATUS                   => 'ISSUED',
	ROLE                     => 'n/a',
	PUBKEY                   => 'n/a',
	SUBJECT_KEY_IDENTIFIER   => 'n/a',
	AUTHORITY_KEY_IDENTIFIER => 'n/a',
	NOTBEFORE                => $now - 86400,
	NOTAFTER                 => $now + 86400,
	LOA                      => 'n/a',
	CSR_SERIAL               => 'n/a',
	CERTIFICATE_SERIAL       => $cert_serial++,
    });




ok($dbi->commit());


###########################################################################

# simple ranged queries
my $result;

$result = $dbi->select(
    TABLE => 'WORKFLOW_HISTORY',
    FROM => 100020,
    TO => 100039,
    );

is(scalar @{$result}, 20);


# simple query for default index field
$result = $dbi->select(
    TABLE => 'WORKFLOW_HISTORY',
    SERIAL => 100020,
    );

is(scalar @{$result}, 1);


# simple query for default index field
$result = $dbi->select(
    TABLE => 'WORKFLOW_HISTORY',
    DYNAMIC => {
	WORKFLOW_DESCRIPTION => 'Added context value somekey-3->somevalue: 100043',
    },
    );

is(scalar @{$result}, 1);


# Try an 'OR' query
$result = $dbi->select(
    TABLE => 'WORKFLOW_HISTORY',
    DYNAMIC => {
	WORKFLOW_DESCRIPTION => [ 
	    'Added context value somekey-3->somevalue:%',
	    '%100043',
	    ],
    },
    );

is(scalar @{$result}, 5);



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

is(scalar @{$result}, 10);
is($result->[0]->{'WORKFLOW.WORKFLOW_SERIAL'}, 10004);
is($result->[9]->{'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_VALUE'}, 'somevalue: 100049');


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

is(scalar @{$result}, 1);
is($result->[0]->{'WORKFLOW.WORKFLOW_SERIAL'}, 10004);
is($result->[0]->{'context1.WORKFLOW_CONTEXT_VALUE'}, 'somevalue: 100045');
is($result->[0]->{'context2.WORKFLOW_CONTEXT_VALUE'}, 'somevalue: 100047');



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
	    'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_KEY',
	    'WORKFLOW.WORKFLOW_SERIAL', 
    ],
    JOIN => [
	#  on first table     second table   
	[ 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL' ],
    ],
    DYNAMIC => {
	'WORKFLOW.WORKFLOW_SERIAL' => '10004',
    },
    DISTINCT => 1,
    );

### $result

is(scalar @{$result}, 10);
is($result->[0]->{'WORKFLOW.WORKFLOW_SERIAL'}, 10004);
is($result->[0]->{'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_KEY'}, 'somekey-0');
# ..
is($result->[9]->{'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_KEY'}, 'somekey-9');



# SELECT 
#    MAX(workflow_context.workflow_context_key),
#    workflow.workflow_id
# FROM workflow, workflow_context
# WHERE workflow.workflow_id=workflow_context.workflow_id 
#   AND workflow_context.workflow_id=?
# ORDER BY workflow_context.workflow_context_key, 
#   workflow.workflow_id
$result = undef;
eval {
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
};
### $result

TODO: {
    local $TODO = 'Fails on MySQL, see bug #1951532';
    ok(! $EVAL_ERROR) or diag "ERROR: $EVAL_ERROR"; 
    is(ref $result eq 'ARRAY' && scalar @{$result}, 1);
    is(ref $result eq 'ARRAY' && $result->[0]->{'WORKFLOW.WORKFLOW_SERIAL'}, 10004);
    is(ref $result eq 'ARRAY' && $result->[0]->{'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_KEY'}, 'somekey-9');
}



###########################################################################
# validity tests (uses certificates and CRLs from 02.t)


my @validity_specs = (
    # spec                                           expected hits
    # single time                                    03.t + 02.t
    [ time - (7 * 24 * 3600),                        0 + 1 ],
    [ time - (     1 * 3600),                        2 + 1 ],
    [ time,                                          1 + 2 ],
    [ DateTime->now,                                 1 + 2 ],

    # multiple points in time
    # note that 02.t certs are not matched (because they have no 
    # certificate_attribute entry)
    [ [ DateTime->now, time - 3600 ],                1 + 1 ],
    [ [ time - 3600, time + 3600 ],                  1 + 1 ],
    [ [ time - 3600, time - 7200 ],                  2 + 1 ],
    [ [ time - 3600, time - 7200, time - 14400 ],    2 + 1 ],
    );

### simple validity...
foreach my $spec (@validity_specs) {
    ### $spec
    $result = $dbi->select(
	TABLE => 'CERTIFICATE',
	VALID_AT => $spec->[0],
	);

    is(scalar @{$result}, $spec->[1]);
}


###########################################################################
### validity in joins...
foreach my $spec (@validity_specs) {
    ### $spec
    $result = $dbi->select(
	#          first table second table
	TABLE => [ 'CERTIFICATE', 'CERTIFICATE_ATTRIBUTES' ],
	
	# return these columns
	COLUMNS => [ 
	    'CERTIFICATE.SUBJECT',
	],
	JOIN => [
	    #  on first table     second table   
	    [ 'IDENTIFIER', 'IDENTIFIER' ],
	],
	#             first table  second table (n/a)
	VALID_AT => [ $spec->[0],  undef ],
	);
    
    is(scalar @{$result}, $spec->[1]);
}


### validity in aliased joins...
foreach my $spec (@validity_specs) {
    ### $spec
    $result = $dbi->select(
	#          first table second table
	TABLE => [ [ 'CERTIFICATE' => 'cert' ], 'CERTIFICATE_ATTRIBUTES' ],
	
	# return these columns	COLUMNS => [ 
	COLUMNS => [ 
	    'cert.SUBJECT',
	],
	JOIN => [
	    #  on first table     second table   
	    [ 'IDENTIFIER', 'IDENTIFIER' ],
	],
	#             first table  second table (n/a)
	VALID_AT => [ $spec->[0],  undef ],
	);
    
    is(scalar @{$result}, $spec->[1]);
}


1;

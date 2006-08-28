## OpenXPKI::Server::DBI::SQL
##
## Written 2005 by Michael Bell for the OpenXPKI::Server project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$

package OpenXPKI::Server::DBI::SQL;

use strict;
use warnings;
use utf8;
use English;

use OpenXPKI::Debug 'OpenXPKI::Server::DBI::SQL';
use OpenXPKI::Server::DBI::Schema;
use OpenXPKI::Server::DBI::DBH;

# use Smart::Comments;

sub new
{
    shift;
    my $self = { @_ };
    bless $self, "OpenXPKI::Server::DBI::SQL";
    $self->{schema} = OpenXPKI::Server::DBI::Schema->new();
    return $self;
}

#######################################################################

sub get_new_serial
{
    my $self = shift;
    return $self->{DBH}->get_new_serial (@_);
}

#######################################################################

sub table_exists
{
    my $self = shift;
    my $keys = { @_ };
    my $name = $keys->{NAME};

    ##! 2: "name: $name"

    # get constant value from the table (avoid full table scan)
    my $command = "select 1 from ".$self->{schema}->get_table_name ($name);

    ##! 2: "command: $command"

    eval { $self->{DBH}->do_query ( QUERY => $command ); };
    if ($EVAL_ERROR) {
        ##! 4: "query failed return"
        return 0;
    } else {
        $self->{DBH}->finish_sth();
        return 1;
    }
}

sub create_table
{
    my $self = shift;
    my $keys = { @_ };
    my $table = $keys->{NAME};
    my $mode  = $keys->{MODE};
 
    ##! 2: "table: $table; mode: $mode"
 
    my $command = "";

    $command = "create table ".$self->{schema}->get_table_name($table)." (";
    foreach my $col (@{$self->{schema}->get_table_columns ($table)})
    {
        my $column = $self->{schema}->get_column ($col);
        my $type   = $self->{DBH}->get_column_type ($column);
        $command .= "$column $type";
        if ($self->{DBH}->get_abstract_column_type ($column) ne "SERIAL" and
            scalar grep /^${col}$/, @{$self->{schema}->get_table_index($table)})
        {
            ## we need this extra handling of SERIAL primary key columns
            ## because there is no standard related to such auto_increment
            ## columns. each vendor implement it different. Examples:
            ## PostgreSQL: SERIAL
            ## MySQL:      AUTO_INCREMENT
            ## SQLite:     PRIMARY KEY AUTOINCREMENT
            $command .= " NOT NULL";
        }
        $command .= ", ";
    }

    ## a SERIAL column can contain a primary key statement
    ## because some databases have really poor SQL capabilities
    ## an example of such a poor SQL dialect is SQLite
    if ($command !~ /primary\s+key/i)
    {
        $command .= "PRIMARY KEY (";
        foreach my $col (@{$self->{schema}->get_table_index($table)})
        {
            $command .= $self->{schema}->get_column ($col);
            $command .= ", ";
        }
        $command = substr ($command, 0, length($command)-2); ## erase the last ,
        $command .= ")";
    } else {
        $command = substr ($command, 0, length($command)-2); ## erase the last ,
    }

    $command .= ")";
    $command .= " ".$self->{DBH}->get_table_option();

    ##! 2: "command: $command"

    if ($mode eq "DRYRUN")
    {
        return $command.";";
    } else {
        $self->{DBH}->do_query ( QUERY => $command );
        $self->{DBH}->finish_sth();
        return 1;
    }
}

sub create_index
{
    my $self = shift;
    my $keys = { @_ };
    my $name = $keys->{NAME};
    my $mode = $keys->{MODE};

    ##! 2: "name: $name, mode: $mode"

    my $index = $self->{schema}->get_index_name ($name);
    my $table = $self->{schema}->get_index_table ($name);
       $table = $self->{schema}->get_table_name ($table);

    my $command = "create index $index on $table (";
    foreach my $col (@{$self->{schema}->get_index_columns($name)})
    {
        $command .= $self->{schema}->get_column ($col);
        $command .= ", ";
    }
    $command = substr ($command, 0, length($command)-2); ## erase the last ,
    $command .= ")";

    ##! 2: "command: $command"

    if ($mode eq "DRYRUN")
    {
        return $command.";";
    } else {
        $self->{DBH}->do_query ( QUERY => $command );
        $self->{DBH}->finish_sth();
        return 1;
    }
}


sub drop_table
{
    my $self = shift;
    my $keys = { @_ };
    my $table = $keys->{NAME};
    my $mode  = $keys->{MODE};
 
    ##! 2: "table: $table; mode: $mode"
 
    my $command = "";

    $command = "drop table " . $self->{schema}->get_table_name($table);

    if ($mode eq "DRYRUN")
    {
        return $command.";";
    } elsif ($mode eq 'FORCE') {
        $self->{DBH}->do_query ( QUERY => $command );
        $self->{DBH}->finish_sth();
        return 1;
    } else {
	## must be forced...
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_DBI_SQL_DROP_TABLE_NOT_FORCED",
	    params  => 
	    {
		"TABLE"  => $table,
	    });
    }
}

sub drop_index
{
    my $self = shift;
    my $keys = { @_ };
    my $name = $keys->{NAME};
    my $mode = $keys->{MODE};

    ##! 2: "name: $name, mode: $mode"

    my $index = $self->{schema}->get_index_name ($name);
    my $table = $self->{schema}->get_index_table ($name);
       $table = $self->{schema}->get_table_name ($table);

    my $command = "drop index $index on $table";

    if ($mode eq "DRYRUN")
    {
        return $command.";";
    } elsif ($mode eq 'FORCE') {
        $self->{DBH}->do_query ( QUERY => $command );
        $self->{DBH}->finish_sth();
        return 1;
    } else {
	## must be forced...
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_DBI_SQL_DROP_INDEX_NOT_FORCED",
	    params  => 
	    {
		"NAME"   => $name,
	    });
    }
}

#######################################################################

sub insert
{
    my $self  = shift;
    my $keys  = { @_ };
    my $table = $keys->{TABLE};
    my $hash  = $keys->{DATA};

    my $sql = "insert into ".$self->{schema}->get_table_name ($table);

    my $names  = "";
    my $values = "";
    my @list   = ();

    ## prepare query

    foreach my $col (@{$self->{schema}->get_table_columns($table)})
    {
        next if (not exists $hash->{$col});
        $names  .= ", " if (length($names));
        $values .= ", " if (length($values));
        $names  .= $self->{schema}->get_column ($col);
        $values .= "?";
        push @list, $hash->{$col};
    }
    $sql .= "($names) values ($values)";

    ## execute query

    my $h = $self->{DBH}->get_next_sth();
    $self->{DBH}->do_query (QUERY => $sql, BIND_VALUES => \@list);
    $self->{DBH}->finish_sth($h);

    return 1;
}

#######################################################################

sub update
{
    my $self  = shift;
    my $keys  = { @_ };
    my $table = $keys->{TABLE};
    my $hash  = $keys->{DATA};
    my $where = $keys->{WHERE};

    my $sql = "update ".$self->{schema}->get_table_name ($table);

    my @data  = ();
    my @where = ();
    my @list  = ();

    ## prepare data update

    foreach my $col (@{$self->{schema}->get_table_columns($table)})
    {
        next if (not exists $hash->{$col});
        push @data, $self->{schema}->get_column ($col)." = ?";
        push @list, $hash->{$col};
    }
    $sql .= " set ".join ", ", @data;

    ## prepare where clause

    foreach my $key (keys %{$where})
    {
        push @where, $self->{schema}->get_column ($key)." = ?";
        push @list, $where->{$key};
    }
    $sql .= " where ".join " and ", @where;

    ## execute query

    my $h = $self->{DBH}->get_next_sth();
    $self->{DBH}->do_query (QUERY => $sql, BIND_VALUES => \@list);
    $self->{DBH}->finish_sth($h);

    return 1;
}

#######################################################################

sub delete
{
    my $self  = shift;
    my $keys  = { @_ };
    my $table = $keys->{TABLE};
    my $hash  = $keys->{DATA};

    my $sql = "delete from ".$self->{schema}->get_table_name ($table)." where ";

    my @list   = ();

    ## prepare query

    my @cols = @{$self->{schema}->get_table_columns($table)};
    foreach my $col (keys %{$hash})
    {
        next if (not exists $hash->{$col}); ## empty hash?
        if (not grep /$col/, @cols)
        {
            ## illegal column
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_DBI_SQL_DELETE_WRONG_COLUMN",
                params  => {"TABLE"  => $table,
                            "COLUMN" => $col});
        }
        my ($val, $op) = (undef, "=");
        if (ref ($hash->{$col}))
        {
            ## value and operator
            $op  = $hash->{$col}->[0];
            $val = $hash->{$col}->[1];
            if ($op ne "="  and
                $op ne "<=" and $op ne ">=" and
                $op ne "<"  and $op ne ">")
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SERVER_DBI_SQL_DELETE_WRONG_OPERATOR",
                    params  => {"OPERATOR" => $op});
            }
        } else {
            ## value only
            $val = $hash->{$col};
        }
        $sql .= " and " if (scalar @list);
        $sql .= $self->{schema}->get_column ($col).$op."?";
        push @list, $val;
    }

    ## execute query

    my $h = $self->{DBH}->get_next_sth();
    $self->{DBH}->do_query (QUERY => $sql, BIND_VALUES => \@list);
    $self->{DBH}->finish_sth($h);

    return 1;
}

#######################################################################

# split 
sub __get_symbolic_column_and_table {
    my $self = shift;
    my $arg = shift;

    my ($symbolic_column, $symbolic_table) 
	= reverse split(m{\.}xms, $arg);

    return ($symbolic_column, $symbolic_table);
}

# split 
sub __get_schema_column_and_table {
    my $self = shift;
    my $arg = shift;

    my ($symbolic_column, $symbolic_table) 
	= $self->__get_symbolic_column_and_table($arg);
    
    my $tab;
    if (defined $symbolic_table) {
	$tab = $self->{schema}->get_table_name($symbolic_table);
    };
    
    my $col = $self->{schema}->get_column($symbolic_column);

    return ($col, $tab);
}

sub get_symbolic_query_columns {
    my $self = shift;
    my $keys = shift;

    my $table = $keys->{TABLE};
    
    my @select_list;
    
    if (ref $table eq '') {
	@select_list = @{$self->{schema}->get_table_columns($table)};

    } elsif (ref $table eq 'ARRAY') {
	## ensure a schema compatible result
	if (! exists $keys->{COLUMNS} ||
	    ref $keys->{COLUMNS} ne 'ARRAY') {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_DBI_SQL_GET_SYMBOLIC_QUERY_COLUMNS_MISSING_COLUMNS");
	}

	foreach my $column (@{$keys->{COLUMNS}}) {
	    my ($col, $tab) = $self->__get_symbolic_column_and_table($column);
	    
	    if (! defined $tab) {
		push @select_list, $col;
	    } else {
		push @select_list, $tab . '.' . $col;
	    }
	}
    }
    return @select_list;
}

sub get_schema_query_columns {
    my $self = shift;
    my $keys = shift;

    my $table = $keys->{TABLE};
    
    my @select_list;
    
    if (ref $table eq '') {
	@select_list = map {
	    $self->{schema}->get_column($_);
	} @{$self->{schema}->get_table_columns($table)};

    } elsif (ref $table eq 'ARRAY') {
	## ensure a schema compatible result
	if (! exists $keys->{COLUMNS} ||
	    ref $keys->{COLUMNS} ne 'ARRAY') {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_DBI_SQL_GET_SCHEMA_QUERY_COLUMNS_MISSING_COLUMNS");
	}

	foreach my $column (@{$keys->{COLUMNS}}) {
	    my ($col, $tab) = $self->__get_schema_column_and_table($column);
	    
	    if (! defined $tab) {
		push @select_list, $col;
	    } else {
		push @select_list, $tab . '.' . $col;
	    }
	}
    }
    return @select_list;
}



sub select
{
    my $self  = shift;
    my $keys  = { @_ };

    ## check arguments
    my $table = $keys->{TABLE};
    if (! defined $table)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_MISSING_TABLE");
    }

    my %compare = ("FROM"    => ">=",
                   "TO"      => "<=",
                   "GREATER" => ">",
                   "LOWER"   => "<");
    

    ## extract columns from query
    my @select_list = $self->get_schema_query_columns($keys);

    my @select_tables;
    my @condition;
    my @bind_values;
    my $pivot_column;


    if (ref $table eq '') {
	### single table queries...

	# use table index serial column as default selector
	$pivot_column = $table . '_SERIAL';
	
	push(@select_tables, $self->{schema}->get_table_name($table));
    } elsif (ref $table eq 'ARRAY') {
	### natural join...
	@select_tables = map {
	    $self->{schema}->get_table_name($_);
	} @{$table};

	# use the first column
	$pivot_column = $select_tables[0];
	### $pivot_column

	if (! exists $keys->{JOIN} ||
	    ref $keys->{JOIN} ne 'ARRAY') {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_MISSING_JOIN");
	}
	
	foreach my $join (@{$keys->{JOIN}}) {
	    ### $join
	    if (ref $join ne 'ARRAY' ||
		scalar(@{$join}) != scalar(@select_tables)) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_JOIN_SPECIFICATION_MISMATCH",
		    params => {
			TABLES => [ @select_tables ],
			JOIN => [ @{$join} ],
		    });
	    }

	    ### add join condition...
	    my $join_index;
	  JOIN_COLUMN:
	    for (my $ii = 0; $ii < scalar(@select_tables); $ii++) {
		next JOIN_COLUMN if (! defined $join->[$ii]);
		### $ii

		# skip column if undef'd
		if (defined $join_index) {
		    # combine the current join column with the previous one
		    my $left = $select_tables[$join_index] . '.' . $self->{schema}->get_column($join->[$join_index]);
		    my $right = $select_tables[$ii] . '.' . $self->{schema}->get_column($join->[$ii]);
		    ### $left
		    ### $right
		    push @condition, $left . '=' . $right;
		}
		$join_index = $ii;
	    }
	}
    }

    if (exists $keys->{PIVOT_COLUMN}) {
	$pivot_column = $keys->{PIVOT_COLUMN};
    }

    foreach my $key (keys %compare)
    {
	next if (not exists $keys->{$key});
	push @condition, $self->{schema}->get_column ($pivot_column) . " " . $compare{$key}." ?";
	push @bind_values, $keys->{$key};
    }
    
    foreach my $key ("KEY", "SERIAL")
    {
	next if (not exists $keys->{$key});
	push @condition, $self->{schema}->get_column ($pivot_column) . " = ?";
	push @bind_values, $keys->{$key};
    }


    ## check dynamic parameters
    
    if ($keys->{DYNAMIC})
    {
	foreach my $key (keys %{$keys->{DYNAMIC}})
	{
	    # for joins the key may be TABLE.COLUMN, otherwise we only
	    # only get COLUMN
	    # $dynamic_column always is set to COLUMN, $dynamic_table is
	    # TABLE if available, otherwise undef
	    my ($col, $tab) = $self->__get_schema_column_and_table($key);

	    if (not $col)
	    {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_WRONG_COLUMN",
		    params  => {
			COLUMN => $key,
		    });
	    }
	    
	    my $expr;
	    if (defined $tab) {
		$expr = $tab . '.';
	    }
	    $expr .= $col;

	    if ($self->{DBH}->column_is_numeric ($col))
	    {
		$expr .= ' = ?';
	    } else {
		$expr .= ' like ?';
	    }
	    push @condition, $expr;
	    push @bind_values, $keys->{DYNAMIC}->{$key};
	} 
    }
    

    # sanity check: there must be a where clause
    if (scalar(@select_list) == 0) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_NO_COLUMNS_SELECTED",
	    params  => {
		TABLE  => $table,
	    });
    }
    
    # sanity check: there must be a condition
    if (scalar(@condition) == 0) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_NO_WHERE_CLAUSE",
	    params  => {
		TABLE  => $table,
	    });
    }

    ## execute query
    
    my $query .= 'SELECT ' . join(', ', @select_list)
	. ' FROM ' . join(', ', @select_tables)
	. ' WHERE '
	. join(' AND ', @condition);

    if ($keys->{REVERSE})
    {
        $query .= ' ORDER BY ' . join(' DESC, ', @select_list) . ' DESC';
    } else {
        $query .= ' ORDER BY ' . join(', ', @select_list);
    }

    $self->{DBH}->do_query (QUERY       => $query,
                            BIND_VALUES => \@bind_values,
                            LIMIT       => $keys->{LIMIT});

    ## build an array to return it

    my @array = ();
    my $sth = $self->{DBH}->get_sth();
    while ( (my $item =  $sth->fetchrow_arrayref) ) {
        my @tab = ();
        for (my $i = 0; $i < scalar @{$item}; $i++)
        {
            if (not defined $item->[$i])
            {
                push @tab, undef;
            } else {
                ## this is only a method to make a normale string a utf8 string
                ## decoding is necessary because at minimum SQLite returns no utf8
                push @tab, pack ("U0C*", unpack "C*", $item->[$i]);
            }
        }
        push @array, [ @tab ];
    }
    $self->{DBH}->finish_sth();

    return [ @array ];
}
1;
__END__

=head1 Name

OpenXPKI::Server::DBI::SQL

=head1 Description

This module implements the SQL interface of the database interface.
It implements basic functions which accept hashes with parameters
for the SQL operations.

=head1 Functions

=head2 General Functions

=head3 new

this is the constructor. Only an instance of OpenXPKI::Server::DBI::DBH
is expected in the parameter DBH.

=head2 Directly Mapped Functions

=head3 get_new_serial

is directly mapped to OpenXPKI::Server::DBI::DBH->get_new_serial

=head2 Functions which implement database initialization

=head3 table_exists

checks if the specified table exists. The parameter for the table name
is NAME.

=head3 create_table

creates a table which was specified with the parameter NAME.
If DRYRUN is the value of MODE then the function returns the SQL commands.

=head3 drop_table

drops the table which was specified with the parameter NAME.
If DRYRUN is the value of MODE then the function returns the SQL commands.
MODE must be FORCE, otherwise this method will throw an exception.

=head3 create_index

creates an index which was specified with the parameter NAME.
If DRYRUN is the value of MODE then the function returns the SQL commands.

=head3 drop_index

drops the index which was specified with the parameter NAME.
If DRYRUN is the value of MODE then the function returns the SQL commands.
MODE must be FORCE, otherwise this method will throw an exception.

=head2 Functions which implement SQL commands

=head3 insert

expects TABLE and DATA. DATA is a hash reference which includes the
names and values of the used columns of the table. A column is 
NULL if the column is not present in the hash.

=head3 update

expects TABLE, WHERE and DATA. DATA is a hash reference which includes the
names and values of the used columns of the table. A column is 
NULL if the column is not present in the hash. WHERE is a hash reference
which includes the parameters for the where clause. All parameters
are required. General updates are not allowed.

=head3 delete

expects TABLE and DATA. DATA is a hash refrence which includes the
names and values of the used columns of the table. These columns will
be specified in the where clause of the SQL delete command.

There must be at minimum one column with a value in the hash reference.
We do not support complete table erasements for security reasons via this
interface.

If you need other operators for the columns in the data hash than C<=>
then you can specify an array reference where the first element is
the operator and the second element is the value. Please note that only
simple operators are allowed (<, >, <=, >= and =).

Examples:

=over 4

=item * erases CRR 3

$self-<gt>{db}-<gt>delete (TABLE =<gt> "CRR",
                           DATA  =<gt> {CRR_SERIAL => 3});

=item * erases all CRRs lower than 3

$self-<gt>{db}-<gt>delete (TABLE =<gt> "CRR",
                           DATA  =<gt> {CRR_SERIAL => ["<", 3]});

=back

BTW CRRs should never be erased!

=head3 update

not implemented

=head3 __get_symbolic_column_and_table

Expects a string argument (arg). 
Returns a two element array containing (arg, undef) if no '.' is 
contained in the string.
Returns a two element array containing (first, second) if the string
looks like 'first.second'.

=head3 __get_schema_column_and_table

Works similar to __get_symbolic_column_and_table but returns the
schema column (and table if appropriate) for the specified argument.

=head3 get_symbolic_query_columns

Returns a list of symbolic column names for the specified query.
If a single table is queried the method returns all table columns.
If a join query is specified the method returns symbolic TABLE.COLUMN
specifications for this particular query.

=head3 get_schema_query_columns

Works like get_symbolic_query_columns but returns the schema mapping
for the specified query.


=head3 select

Select is the most versatile function and has two invocation modes:
single table query and natural join.

The method supports the following named static parameters:

=over 4

=item * TABLE

Is the table which will be searched. If this is a scalar value a single
table is queried. If an array reference is passed, the method tries
to construct a join. See below for a discussion on joins.

=item * KEY

is the serial of the table. See SERIAL for more informations.

=item * SERIAL

will be mapped to ${TABLE}_SERIAL. Please note that a SERIAL is perhaps
not a unique index in a table. Certificates with identical serials
can be present in a table if they were issued by different CAs.

=item * FROM

creates the SQL filter C<${FROM} <lt>= ${TABLE}_SERIAL>.

=item * TO

creates the SQL filter C<${TABLE}_SERIAL <lt> ${FROM}>.

=item * GREATER

creates the SQL filter C<${GREATER} <lt> ${TABLE}_SERIAL>.

=item * LOWER

creates the SQL filter C<${TABLE}_SERIAL <lt> ${FROM}>.

=item * LIMIT

is the number of returned items.

=item * REVERSE

reverse the ordering of the results.

=item * PIVOT_COLUMN

optional, specifies the key column to apply above filters on. Defaults
to table_SERIAL.

=back

In addition the function supports all table columns except of the
data columns because they are perhaps too large. Many database do not
support searching on high volume columns or columns with a flexible
length. Dynamic parameters may be specified via a hash reference passed
in as the named parameter DYNAMIC.

You can use wildcards inside of text fields like subjects or emailaddresses.
You have to ensure that C<%> is used as wildcard. This module expects SQL
ready wildcards. It always binds parameters to queries so that SQL
injection is impossible.

=head4 Joins

In order to issue compound queries across multiple tables it is possible
to call select with an array reference contained in the named parameter
TABLE. If this is the case the following named parameters are also required:

=over 4

=item * COLUMNS

Array reference containing the exact specification of the columns to return.
The scalars contained in the array ref should have the form TABLE.COLUMN,
with table being one of the tables specified in the TABLES argument.

=item * JOIN

Array reference containing array references specifying the join condition.
The length of the inner arrayref (join condition) must be identical 
to the number of the TABLEs to join. 
Each scalar element in the join condition may be either undef (which means
that the corresponding table will not be part of the join condition) or 
a column name in the corresponding table. If the element
is defined, an SQL AND statement will be formed between the previous
defined element and the current one in order to form the join.
It is possible to specify multiple join conditions.

See the example below to get an idea how this is meant to work.

=back

=head4 Join example 1

 $result = $dbi->select(
    #          first table second table        third table
    TABLE => [ 'WORKFLOW', 'WORKFLOW_CONTEXT', 'WORKFLOW_HISTORY' ],

    # return these columns
    COLUMNS => [ 'WORKFLOW.WORKFLOW_SERIAL', 'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_KEY', 'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_VALUE' ],
    
    JOIN => [
	#  on first table     second table       third
	[ 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL' ],
        # a hypothetical additional join condition only using the columns
        # WORKFLOW_CONTEXT.FOO and WORKFLOW_HISTORY.BAR
        # (just for illustration purposes):
	# [ undef, 'FOO', 'BAR' ],
    ],
    DYNAMIC => {
	'WORKFLOW_HISTORY.WORKFLOW_DESCRIPTION' => 'Added context value somekey-3->somevalue: 100043',
    },
    );

This results in the following query:

 SELECT 
    workflow.workflow_id, 
    workflow_context.workflow_context_key, 
    workflow_context.workflow_context_value 
 FROM workflow, workflow_context, workflow_history 
 WHERE workflow.workflow_id=workflow_context.workflow_id 
   AND workflow_context.workflow_id=workflow_history.workflow_id 
   AND workflow_history.workflow_description like ? 
 ORDER BY workflow.workflow_id, 
   workflow_context.workflow_context_key, 
   workflow_context.workflow_context_value


=head1 See also

OpenXPKI::Server::DBI::DBH and OpenXPKI::Server::DBI::Schema


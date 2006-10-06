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



sub select
{
    my $self  = shift;
    my $args  = { @_ };

    my %operator_of = (
	'FROM'          => '>=',
	'TO'            => '<=',

	'LESS_THAN'     => '<',
	'GREATER_THAN'  => '>',
	);

    my $pivot_column;

    # we have three levels of table specification:
    # alias => openxpki symbolic table name => sql table name

    # this maps an alias to a symbolic table name and to a sql table name
    my %alias_map_of;

    my @symbolic_select_tables;
    my @select_list;
    my @conditions;
    my @bind_values;

    my $table_args = $args->{TABLE};

    if (! defined $table_args)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_MISSING_TABLE");
    } elsif (ref $table_args eq '') {
	### single table queries...

	# use table index serial column as default selector
	$pivot_column = $table_args . '_SERIAL';
	
	@select_list = map {
	    $self->{schema}->get_column($_);
	} @{$self->{schema}->get_table_columns($table_args)};

	push @symbolic_select_tables,
	{
	    SYMBOLIC_NAME => $table_args,
	    SQL_NAME => $self->{schema}->get_table_name($table_args),
	};
    } elsif (ref $table_args eq 'ARRAY') {
	### natural join...

	if (! exists $args->{COLUMNS} ||
	    ref $args->{COLUMNS} ne 'ARRAY') {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_MISSING_COLUMNS");
	}
	
	# collect tables to join
	# - scalar value: join on this symbolic table name
	# - arrayref: expect exactly two values (fat comma syntax suggested),
	#     first is the symbolic table name, the second the alias name
	#     to use in the query. you must use the second, alias name
	#     to reference the table in the conditions if this syntax is used.
	my $ii = -1;
      TABLE:
	foreach my $entry (@{$table_args}) {
	    $ii++;
	    if (ref $entry eq '') {
		### literal table name...
		# the argument is the symbolic table name
		push @symbolic_select_tables, 
		{
		    SYMBOLIC_NAME => $entry,
		    SQL_NAME => $self->{schema}->get_table_name($entry),
		};
		next TABLE;
	    }
	    if (ref $entry eq 'ARRAY') {
		### aliased table name...
		### $entry
		# [ 'symbolic_table_name', 'alias_name' ] or
		# [ 'symbolic_table_name' => 'alias_name' ]
		if (scalar @{$entry} != 2) {
		    OpenXPKI::Exception->throw (
			message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_INCORRECT_NUMBER_OF_SYMBOLIC_TABLE_ENTRIES",
			params => {
			    TABLE_REF => ref $entry,
			    TABLE_INDEX => $ii,
			});
		}
		my ($symbolic_table_name, $alias) = @{$entry};
		### $symbolic_table_name
		### $alias
		# select on the alias name

		# make sure the alias is unique
		if (exists $alias_map_of{$alias}) {
		    OpenXPKI::Exception->throw (
			message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_ALIAS_NOT_UNIQUE",
			params => {
			    SYMBOLIC_NAME => $symbolic_table_name,
			    ALIAS => $alias,
			});
		}

		# remember the mapping
		$alias_map_of{$alias} = {
		    SYMBOLIC_NAME => $symbolic_table_name,
		    SQL_NAME => $self->{schema}->get_table_name($symbolic_table_name),
		};

		push @symbolic_select_tables, 
		{
		    ALIAS => $alias,
		    %{$alias_map_of{$alias}},
		};
		next TABLE;
	    }

	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_INCORRECT_TABLE_SPECIFICATION",
		params => {
		    TABLE_REF => ref $entry,
		    TABLE_INDEX => $ii,
		});
	}

	# build column specification
	### $keys->{COLUMNS}
	foreach my $column (@{$args->{COLUMNS}}) {
	    my ($col, $tab) = $self->__get_symbolic_column_and_table($column);

	    # convert this into schema compatible column
	    $col = $self->{schema}->get_column($col);

	    if (defined $tab) {
		# if this is an alias leave it this way
		if (! exists $alias_map_of{$tab}) {
		    $tab = $self->{schema}->get_table_name($tab);
		}
		push @select_list, $tab . '.' . $col;

	    } else {
		push @select_list, $col;
	    }

	}


	# use first column as pivot column
	if (! defined $pivot_column) {
	    $pivot_column = $symbolic_select_tables[0]->{SYMBOLIC_NAME} . '_SERIAL';
	}


	######################################################################
	# handle joins
	if (! exists $args->{JOIN} ||
	    ref $args->{JOIN} ne 'ARRAY') {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_MISSING_JOIN");
	}
	
	foreach my $join (@{$args->{JOIN}}) {
	    ### $join
	    if (ref $join ne 'ARRAY' ||
		scalar(@{$join}) != scalar(@symbolic_select_tables)) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_JOIN_SPECIFICATION_MISMATCH",
		    params => {
			TABLES => [ @symbolic_select_tables ],
			JOIN => [ @{$join} ],
		    });
	    }

	    ### add join condition...

	    my $join_index;
	  JOIN_COLUMN:
	    for (my $ii = 0; $ii < scalar(@symbolic_select_tables); $ii++) {
		next JOIN_COLUMN if (! defined $join->[$ii]);
		### $ii

		# skip column if undef'd
		if (defined $join_index) {
		    # combine the current join column with the previous one
		    
		    # use alias if available, otherwise symbolic name
		    my $left_table;
		    if (exists $symbolic_select_tables[$join_index]->{ALIAS}) {
			# use alias literally
			$left_table = $symbolic_select_tables[$join_index]->{ALIAS};
		    } else {
			# map symbolic name to real table name
			$left_table = $self->{schema}->get_table_name(
			    $symbolic_select_tables[$join_index]->{SYMBOLIC_NAME}
			    );
		    }

		    my $right_table;
		    if (exists $symbolic_select_tables[$ii]->{ALIAS}) {
			# use alias literally
			$right_table = $symbolic_select_tables[$ii]->{ALIAS};
		    } else {
			# map symbolic name to real table name
			$right_table = $self->{schema}->get_table_name(
			    $symbolic_select_tables[$ii]->{SYMBOLIC_NAME}
			    );
		    }
		    
		    my $left = 
			$left_table 
			. '.' 
			. $self->{schema}->get_column($join->[$join_index]);

		    my $right = 
			$right_table 
			. '.' 
			. $self->{schema}->get_column($join->[$ii]);

		    ### $left
		    ### $right
		    push @conditions, $left . '=' . $right;
		}
		$join_index = $ii;
	    }
	}
    }


    # sanity check: there must be a where clause
    if (scalar(@select_list) == 0) {
 	OpenXPKI::Exception->throw (
 	    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_NO_COLUMNS_SELECTED",
 	    params  => {
 		TABLE  => $table_args,
 	    });
    }
    

    # allow to override pivot columnn
    if (exists $args->{PIVOT_COLUMN}) {
	$pivot_column = $args->{PIVOT_COLUMN};
    }

    ###########################################################################
    # build condition

  OPERATOR:
    foreach my $keyword (keys %operator_of)
    {
	next OPERATOR if (! exists $args->{$keyword});
	push @conditions, $self->{schema}->get_column ($pivot_column) . " " . $operator_of{$keyword} . " ?";
	push @bind_values, $args->{$keyword};
    }


  INDEX_MATCH:
    foreach my $key (qw( KEY SERIAL ))
    {
	next INDEX_MATCH if (! exists $args->{$key});
	push @conditions, $self->{schema}->get_column($pivot_column) . " = ?";
	push @bind_values, $args->{$key};
    }


    ###########################################################################
    ## check dynamic conditions
    if (exists $args->{DYNAMIC} && ref $args->{DYNAMIC} eq 'HASH')
    {
	foreach my $condition (keys %{$args->{DYNAMIC}})
	{
	    # for joins the key may be SYMBOLIC_NAME.COLUMN or ALIAS.COLUMN, 
	    # otherwise we only only get COLUMN
	    # $dynamic_column always is set to COLUMN, $dynamic_table is
	    # TABLE if available, otherwise undef
	    my ($col, $tab) = 
		$self->__get_symbolic_column_and_table($condition);

	    # leave alias as is, but map symbolic table name to real table name
	    if (! exists $alias_map_of{$tab}) {
		$tab = $self->{schema}->get_table_name($tab);
	    }

	    if (! $col)
	    {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_WRONG_COLUMN",
		    params  => {
			COLUMN => $condition,
		    });
	    }
	    
	    $col = $self->{schema}->get_column($col);

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
	    push @conditions, $expr;
	    push @bind_values, $args->{DYNAMIC}->{$condition};
	} 
    }
    
    # sanity check: there must be a condition
    if (scalar(@conditions) == 0) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_NO_WHERE_CLAUSE",
	    params  => {
		TABLE  => $table_args,
	    });
    }



    ###########################################################################
    # compose table specifications
    my @table_specs;
    foreach my $entry (@symbolic_select_tables) {
	# real table name
	my $table = $entry->{SQL_NAME};

	if (exists $entry->{ALIAS}) {
	    # aliased table
	    $table = $entry->{SQL_NAME} . ' AS ' . $entry->{ALIAS};
	}

	push @table_specs, $table;
    }

    
    ###########################################################################
    ## execute query
    my $query .= 'SELECT ' . join(', ', @select_list)
	. ' FROM ' . join(', ', @table_specs)
	. ' WHERE '
	. join(' AND ', @conditions);

    if ($args->{REVERSE})
    {
        $query .= ' ORDER BY ' . join(' DESC, ', @select_list) . ' DESC';
    } else {
        $query .= ' ORDER BY ' . join(', ', @select_list);
    }

    ### $query
    $self->{DBH}->do_query (QUERY       => $query,
                            BIND_VALUES => \@bind_values,
                            LIMIT       => $args->{LIMIT});

    ## build an array to return it

    my @result;
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
        push @result, [ @tab ];
    }
    $self->{DBH}->finish_sth();

    return [ @result ];
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

=head3 get_symbolic_query_columns

Returns a list of symbolic column names for the specified query.
If a single table is queried the method returns all table columns.
If a join query is specified the method returns symbolic TABLE.COLUMN
specifications for this particular query.


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

=item * PIVOT_COLUMN

optional, specifies the key column to apply the following filters on. Defaults
to ${TABLE}_SERIAL.

=item * FROM

creates the SQL filter C<${FROM} <lt>= PIVOT_COLUMN>.

=item * TO

creates the SQL filter C<PIVOT_COLUMN <lt>= ${FROM}>.

=item * GREATER_THAN

creates the SQL filter C<${GREATER} <lt> PIVOT_COLUMN>.

=item * LESS_THAN

creates the SQL filter C<PIVOT_COLUMN <lt> ${FROM}>.

=item * LIMIT

is the number of returned items.

=item * REVERSE

reverse the ordering of the results.

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

In the common invocation mode, TABLE is an arrayref containing scalar
table names. In this case the join uses these as table names. 

Example:

  TABLE => [ 'foo', 'bar' ]

If you wish to reference one table more than once (e. g. for matching
multiple tuples from one single table) you can assign a symbolic name
to the table. In this case the TABLE arrayref should contain another 
arrayref containing two entries, such as follows for the table 'bar'.

Example:

  TABLE => [ 'foo', [ bar => symbolic ] ]


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

=head4 Join example 2

  $result = $dbi->select(
    #          first table second table                          third table
    TABLE => [ 'WORKFLOW', [ 'WORKFLOW_CONTEXT' => 'context1' ], [ 'WORKFLOW_CONTEXT' => 'context2' ] ],

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

This results in the following query:

 SELECT 
    workflow.workflow_id, 
    context1.workflow_context_value 
    context2.workflow_context_value 
 FROM workflow, workflow_context as context1, workflow_context as context2
 WHERE workflow.workflow_id=context1.workflow_id 
   AND context1.workflow_id=context2.workflow_id 
   AND context1.workflow_context_key like ?
   AND context1.workflow_context_value like ?
   AND context2.workflow_context_key like ?
   AND context2.workflow_context_value like ?
 ORDER BY workflow.workflow_id, 
   context1.workflow_context_value, 
   context2.workflow_context_value


=head1 See also

OpenXPKI::Server::DBI::DBH and OpenXPKI::Server::DBI::Schema


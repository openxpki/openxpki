# OpenXPKI::Server::DBI::SQL
##
## Written 2005 by Michael Bell for the OpenXPKI::Server project
## (C) Copyright 2005-2006 by The OpenXPKI Project

package OpenXPKI::Server::DBI::SQL;

use strict;
use warnings;
use utf8;
use English;

use Regexp::Common;

use OpenXPKI::Debug;
use OpenXPKI::Server::DBI::Schema;
use OpenXPKI::Server::DBI::DBH;

# use Smart::Comments;

use Data::Dumper;

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
    if (! scalar @data) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_DBI_SQL_UPDATE_NO_DATA_PRESENT',
        );
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
    my $result = $self->{DBH}->do_query(
        QUERY       => $sql,
        BIND_VALUES => \@list
    );
    $self->{DBH}->finish_sth($h);

    return $result;
}

#######################################################################

sub delete
{
    my $self  = shift;
    my $keys  = { @_ };
    my $table = $keys->{TABLE};
    my $hash  = $keys->{DATA};
    my $all   = $keys->{ALL};

    my $sql = "delete from " . $self->{schema}->get_table_name($table);

    if (!defined $hash && $all) {
        # delete everything
        $hash = {};  # so that foreach below works 
    }
    else {
        $sql .= ' where ';
    }

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
	    if (ref $column eq 'HASH') {
		$column = $column->{COLUMN};
	    }

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


# if a non-arrayref is passed, returns an arrayref containing the argument
# if an arrayref is passed, returns the same arrayref
sub __normalize_scalar_or_arrayref {
    my $self = shift;
    my $args = shift;

    if (ref $args eq 'ARRAY') {
	return $args;
    } else {
	return [ $args ];
    }
}

# returns an arrayref containing epoch integers
sub __normalize_validity {
    my $self = shift;
    my $args = shift;

    $args = $self->__normalize_scalar_or_arrayref($args);

    if (! defined $args) {
	return;
    }
    
    foreach my $element (@{$args}) {
	if (ref $element eq 'DateTime') {
	    $element = $element->epoch;
	}

	if ($element !~ m{ \A \d+ \z }xms) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_DBI_SQL_NORMALIZE_VALIDITY_INVALID_ARGUMENT",
		params => {
		    VALIDITY_SPEC => @{$args},
		}) ;
	}
    }

    return $args;
}



sub __get_validity_conditions {
    my $self = shift;
    my $args = shift;

    my $table         = $args->{TABLE};
    my $validity_args = $self->__normalize_validity($args->{VALID_AT});
    
    my @conditions;

    if (! defined $validity_args) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_DBI_SQL_GET_VALIDITY_CONDITION_INCORRECT_VALIDITY_ARGUMENTS",
	    params => {
		VALID_AT => $args->{VALID_AT},
	    }) ;
    }
	    
    my $notbefore = $self->{schema}->get_column('NOTBEFORE');
    my $notafter  = $self->{schema}->get_column('NOTAFTER');

    if (defined $table) {
	$notbefore = $table . '.' . $notbefore;
	$notafter  = $table . '.' . $notafter;
    }
    
    foreach my $validity (@{$validity_args}) {
	push @conditions, 
	$validity
	    . '>=' 
	    . $notbefore;
	
	push @conditions, 
	$validity
	    . '<=' 
	    . $notafter;
    }
    
    return \@conditions;
}


sub select
{
    ##! 1: "start"
    my $self  = shift;
    my $args  = { @_ };

    ##! 128: 'args: ' . Dumper $args
    
    ##! 2: "initialize variables"
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
    # select_list semantics:
    # [
    #    {
    #      COLUMN => '...',
    #      DISTINCT => 0,   # or 1
    #      AGGREGATE => 'MAX',  # alternative aggregates possible (or undef'd)
    #    }, ...
    # ]

    my @conditions;
    my @bind_values;

    my $table_args = $args->{TABLE};

    ##! 2: "setup table joins"

    if (! defined $table_args)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_MISSING_TABLE");
    } elsif (ref $table_args eq '') {
	### single table queries...

	# use table index serial column as default selector
	$pivot_column = $table_args . '_SERIAL';
	
	@select_list = map {
	    {
		COLUMN => $self->{schema}->get_column($_),
	    }
	} @{$self->{schema}->get_table_columns($table_args)};

	push @symbolic_select_tables,
	{
	    SYMBOLIC_NAME => $table_args,
	    SQL_NAME => $self->{schema}->get_table_name($table_args),
	};



	# handle validity specification for single tables
	if (exists $args->{VALID_AT}) {

	    # check if table contains NOTBEFORE/NOTAFTER
	    my $columns = $self->{schema}->get_table_columns($table_args);
	    ### $columns
	    if (! (grep(m{ \A NOTBEFORE \z }xms, @{$columns}) 
		   && grep(m{ \A NOTAFTER \z }xms, @{$columns}))) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_INVALID_TABLE_FOR_VALIDITY_CONSTRAINT",
		    params => {
			TABLE => $table_args,
		    });
	    }

	    push @conditions,
	    @{$self->__get_validity_conditions(
		{
		    VALID_AT => $args->{VALID_AT},
		})};
	    
 	}

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
	$ii = -1;
	foreach my $entry (@{$args->{COLUMNS}}) {
	    $ii++;

	    my $column;
	    my %column_specification;

	    if (ref $entry eq 'HASH') {
		$column = $entry->{COLUMN};

		if (defined $entry->{AGGREGATE}) {
		    $column_specification{AGGREGATE} = $entry->{AGGREGATE};

		    if ($column_specification{AGGREGATE} !~ 
			m{ \A (?: MIN | MAX | AVG | COUNT ) \z }xms) {
			
			OpenXPKI::Exception->throw (
			    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_INVALID_AGGREGATE_SPECIFICATION",
			    params => {
				COLUMN_REF => ref $entry,
				COLUMN_INDEX => $ii,
				COLUMN => $column,
				AGGREGATE => $column_specification{AGGREGATE},
			    });
		    }
		}
	    } elsif (ref $entry eq '') {
		# scalar value
		$column = $entry;

	    } else {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_INCORRECT_COLUMN_DATA_TYPE",
		    params => {
			COLUMN_REF => ref $entry,
			COLUMN_INDEX => $ii,
		    });
	    }
	    
	    if (! defined $column) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_COLUMN_NOT_SPECIFIED",
		    params => {
			COLUMN_REF => ref $column,
			COLUMN_INDEX => $ii,
		    });
	    }
	    

	    my ($col, $tab) = $self->__get_symbolic_column_and_table($column);

	    # convert this into schema compatible column
	    $col = $self->{schema}->get_column($col);

	    if (defined $tab) {
		# if this is an alias leave it this way
		if (! exists $alias_map_of{$tab}) {
		    $tab = $self->{schema}->get_table_name($tab);
		}
		$column_specification{COLUMN} = $tab . '.' . $col;

	    } else {
		$column_specification{COLUMN} = $col;
	    }
	    
	    push @select_list, \%column_specification;
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
                    JOIN => Dumper $join,
                },
            );
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
	
	##
	# handle validity for joins
	if (defined $args->{VALID_AT}) {
	    # according to the documentation for this constraint it may be
	    # one of the following
	    # 1. single table query:
	    #    - SCALAR (single point in time)
	    #    - ARRAYREF (multiple points in time)
	    # 2. join query across multiple tables
	    #    - ARRAYREF containing entries for each single joined table
	    #      - each containing SCALAR or ARRAYREF, see 1.
	    # hence for single table queries we need to wrap the argument
	    # in an arrayref to prepare the input for generalized processing
	    # below
	    if (scalar(@symbolic_select_tables) == 1) {
		$args->{VALID_AT} = [ $args->{VALID_AT} ];
	    }

	    # sanity checks
	    if (ref $args->{VALID_AT} ne 'ARRAY') {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_INCORRECT_VALIDITY_SPECIFICATION_TYPE_FOR_JOIN");
	    }
	    
	    if (scalar(@{$args->{VALID_AT}}) != scalar(@symbolic_select_tables)) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_VALIDITY_SPECIFICATION_MISMATCH_FOR_JOIN",
		    params => {
			TABLES   => [ @symbolic_select_tables ],
			VALID_AT => $args->{VALID_AT},
		    });
	    }

	    ### add validity conditions...
	    
	    my $validity_index;
	  VALIDITY:
	    for (my $ii = 0; $ii < scalar(@symbolic_select_tables); $ii++) {
		next VALIDITY if (! defined $args->{VALID_AT}->[$ii]);
		
		# use alias if available, otherwise symbolic name
		my $table;
		if (exists $symbolic_select_tables[$ii]->{ALIAS}) {
		    ### use alias literally...
		    $table = $symbolic_select_tables[$ii]->{ALIAS};
		} else {
		    ### map symbolic name to real table name...
		    $table = $self->{schema}->get_table_name(
			$symbolic_select_tables[$ii]->{SYMBOLIC_NAME}
			);
		}
		
		# check if table contains NOTBEFORE/NOTAFTER
		my $columns = 
		    $self->{schema}->get_table_columns($symbolic_select_tables[$ii]->{SYMBOLIC_NAME});

		if (! (grep(m{ \A NOTBEFORE \z }xms, @{$columns}) 
		       && grep(m{ \A NOTAFTER \z }xms, @{$columns}))) {
		    OpenXPKI::Exception->throw (
			message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_INVALID_TABLE_FOR_VALIDITY_CONSTRAINT",
			params => {
			    TABLE => $symbolic_select_tables[$ii]->{SYMBOLIC_NAME},
			});
		}

		### table: $table
		push @conditions,
		@{$self->__get_validity_conditions(
		      {
			  VALID_AT => $args->{VALID_AT}->[$ii],
			  TABLE    => $table,
		      })};
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

    ##! 128: '@conditions: ' . Dumper \@conditions
  OPERATOR:
    foreach my $keyword (keys %operator_of)
    {
	next OPERATOR if (! exists $args->{$keyword});
	push @conditions, $self->{schema}->get_column ($pivot_column) . " " . $operator_of{$keyword} . " ?";
	push @bind_values, $args->{$keyword};
    }
    ##! 128: '@conditions: ' . Dumper \@conditions


  INDEX_MATCH:
    foreach my $key (qw( KEY SERIAL ))
    {
	next INDEX_MATCH if (! exists $args->{$key});
	push @conditions, $self->{schema}->get_column($pivot_column) . " = ?";
	push @bind_values, $args->{$key};
    }
    ##! 128: '@conditions: ' . Dumper \@conditions


    ###########################################################################
    ## check dynamic conditions
    if (exists $args->{DYNAMIC} && ref $args->{DYNAMIC} eq 'HASH')
    {
	foreach my $dynamic_key (keys %{$args->{DYNAMIC}})
	{
	    # for joins the key may be SYMBOLIC_NAME.COLUMN or ALIAS.COLUMN, 
	    # otherwise we only only get COLUMN
	    # $dynamic_column always is set to COLUMN, $dynamic_table is
	    # TABLE if available, otherwise undef
	    my ($col, $tab) = 
		$self->__get_symbolic_column_and_table($dynamic_key);
	    
	    # leave alias as is, but map symbolic table name to real table name
	    if (defined $tab && ! exists $alias_map_of{$tab}) {
		$tab = $self->{schema}->get_table_name($tab);
	    }
	    
	    if (! $col)
	    {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_WRONG_COLUMN",
		    params  => {
			COLUMN => $dynamic_key,
		    });
	    }
	    
	    $col = $self->{schema}->get_column($col);

	    # left-hand side
	    my $lhs = '';
	    if (defined $tab) {
		$lhs = $tab . '.';
	    }
	    $lhs .= $col;

	    my $comparison_operator;
	    if ($self->{DBH}->column_is_numeric ($col))
	    {
		$comparison_operator = ' = ?';
	    } else {
		$comparison_operator = ' like ?';
	    }
	    
	    my @dynamic_values;

	    if (ref $args->{DYNAMIC}->{$dynamic_key} eq '') {
                ##! 64: 'pushing scalar dynamic value for ' . $dynamic_key
		push @dynamic_values, $args->{DYNAMIC}->{$dynamic_key};
	    } elsif (ref $args->{DYNAMIC}->{$dynamic_key} eq 'ARRAY') {
                ##! 64: 'pushing arrayref dynamic value for ' . $dynamic_key
		push @dynamic_values, $args->{DYNAMIC}->{$dynamic_key};
	    } else {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_INVALID_DYNAMIC_QUERY",
		    params  => {
			CONDITION => $dynamic_key,
		    });
	    }
	    
	    foreach my $value (@dynamic_values) {
                ##! 64: 'dynamic value: ' . Dumper $value
		if (defined $value && ! ref $value) {
                    # scalar case
		    push @conditions, $lhs . $comparison_operator;
		    push @bind_values, $value;
		}
                elsif (defined $value && ref $value eq 'ARRAY') {
                    # the value is an array reference, combine with OR
                    my @tmp = ();
                    foreach my $subvalue (@{$value}) {
                        push @tmp, $lhs . $comparison_operator;
                        push @bind_values, $subvalue; 
                    }
                    push @conditions, \@tmp;
                }
                else {
		    # handle queries for NULL
		    push @conditions, $lhs . ' IS NULL';
		}
	    }
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
    # compose column specifications
    my @select_column_specs;
    my @order_specs;
    foreach my $entry (@select_list) {
	my $select_column = $entry->{COLUMN};

	if (defined $entry->{AGGREGATE}) {
	    $select_column = $entry->{AGGREGATE} . '(' . $select_column . ')';
	}

	push @select_column_specs, $select_column;

	# only order by column if no aggregate or distinct is applied to it
	if ($select_column eq $entry->{COLUMN}) {
	    # don't order by TEXT and LONGTEXT columns
	    my ($col, $tab) = 
		$self->__get_symbolic_column_and_table($select_column);

	    my $type = $self->{DBH}->get_abstract_column_type($col);
	    if (($type ne 'TEXT') && ($type ne 'LONGTEXT')) {
		push @order_specs, $select_column;
	    }
	}
    }

    ###########################################################################
    # compose table specifications
    my @table_specs;
    foreach my $entry (@symbolic_select_tables) {
	# real table name
	my $table = $entry->{SQL_NAME};

	if (exists $entry->{ALIAS}) {
	    # aliased table
	    $table = $entry->{SQL_NAME} . ' ' . $entry->{ALIAS};
	}

	push @table_specs, $table;
    }

    ###########################################################################
    ## execute query
    foreach my $condition (@conditions) {
        if (ref $condition eq 'ARRAY') {
            $condition = '(' . join(' OR ', @{$condition}) . ')';
        }
    }
    my $distinct = '';
    if ($args->{DISTINCT}) {
        $distinct = 'DISTINCT';
    }
    my $query = 'SELECT ' . $distinct . ' '
      . join(', ', @select_column_specs)
	  . ' FROM ' . join(', ', @table_specs)
	  . ' WHERE '
	  . join(' AND ', @conditions);

    if (@order_specs) { # only order if we actually have columns by which
                        # we can order
        if (exists $args->{ORDER}) {
            ##! 16: 'order argument exists ...'
            ##! 64: 'order specs: ' . Dumper \@order_specs
            if (ref $args->{ORDER} ne 'ARRAY') {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_DBI_SQL_ORDER_IS_NOT_ARRAYREF',
                );
            }
            my @order = @{ $args->{ORDER} };
            ##! 16: 'order: ' . Dumper \@order
            my @real_order;
            foreach my $order_arg (@order) {
	            my ($col, $tab) = 
		            $self->__get_symbolic_column_and_table($order_arg);
                $col = $self->{schema}->get_column($col);
                if ($tab) {
                    $tab = $self->{schema}->get_table_name($tab);
                    push @real_order, $tab . '.' . $col;
                }
                else {
                    push @real_order, $col;
                }
            }
            ##! 16: 'order: ' . Dumper \@real_order
            foreach my $entry (@real_order) {
                if (! grep { $entry eq $_ } @order_specs) {
                    # argument entries need to be part of the order_specs
                    OpenXPKI::Exception->throw(
                        message => 'I18N_OPENXPKI_SERVER_DBI_SQL_ORDER_INVALID_ENTRY',
                        params  => {
                            ENTRY => $entry,
                        },
                    );
                }
                push @order_specs, $entry;
            }
        }

        if ($args->{REVERSE})
        {
            $query .= ' ORDER BY ' . join(' DESC, ', reverse @order_specs) . ' DESC';
        } else {
            $query .= ' ORDER BY ' . join(', ', reverse @order_specs);
        }
    }
    
    ### $query
    ##! 2: "execute do_query: $query"
    $self->{DBH}->do_query (QUERY       => $query,
                            BIND_VALUES => \@bind_values,
                            LIMIT       => $args->{LIMIT});

    ##! 2: "build an array to return it"

    my @result = ();
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

    ##! 1: "return ".scalar (@result)." results"
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

Can either be a number n, which means that only the first n rows are returned,
or a hash reference with the keys AMOUNT and START, in which case AMOUNT
rows are returned starting at START.

=item * REVERSE

reverse the ordering of the results.

=item * VALID_AT

limit search to specified validity (see below).

=back

In addition the function supports all table columns except of the
data columns because they are perhaps too large. Many database do not
support searching on high volume columns or columns with a flexible
length. Dynamic parameters may be specified via a hash reference passed
in as the named parameter DYNAMIC. The argument to DYNAMIC may be a scalar
or an hash reference. In the latter case multiple conditions are
created that are logically ANDed. The hash value for each key can
either be a scalar or an array reference. In the latter case, they
are combined by a logical OR.

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


=head4 Validity specification for single table queries

Adding the named parameter VALID_AT limits the returned results to entries 
with a NOTBEFORE and a NOTAFTER date. Depending on if the query is
a single-table query or a join, the argument of VALID_AT is interpreted
differently.

For single-table queries the argument may either be a single scalar value
or a arrayref. Each individual value of these may be either an
integer number or a DateTime object.

If an integer value is passed, the value is interpreted as seconds 
since epoch. As an alternative, it is also possible to pass a 
DateTime object instead of an epoch value.

Only those entries are returned which match the validity specification.

Examples:

  VALID_AT => time
or
  VALID_AT => DateTime->now

selects entries that are valid now


  VALID_AT => time + 3600

selects entries that will be valid in one hour

  VALID_AT => [ time, time + 3600 ]

selects entries that are valid now and also one hour from now.


=head4 Validity specification for joined tables

If multiple queries are linked using the join syntax, the VALID_AT
named parameter must be an array reference very similar to the JOIN
specification. The number of array elements must match the number of
joined tables. Each individual entry of the arrayref specifies the
validity for the corresponding table, just as in JOIN. For tables that
do not have a NOTBEFORE/NOTAFTER date, the array element must be undef.
Tables that have a validity may have a validity specification just as
explained in the previous section for single table queries.

Example:

  $result = $dbi->select(
    #          first table    second table
    TABLE => [ 'CERTIFICATE', 'CERTIFICATE_ATTRIBUTES' ],

    # return these columns
    COLUMNS => [ 'CERTIFICATE.SUBJECT' ],
    
    JOIN => [
	#  on first table second table
	[ 'IDENTIFIER', 'IDENTIFIER' ],
    ],
    #             first table            second table (no notbefore -> undef)
    VALID_AT => [ [ time, time + 3600 ], undef ],
    DYNAMIC => {
	'CERTIFICATE_ATTRIBUTES.ATTRIBUTE_KEY' => 'somekey-5',
    },
    );


=head4 Aggregate statements

It is possible to include aggregate statements in the query
by using a hash reference for the column specification instead of a scalar.
In this case the hash key 'COLUMN' must be set to the desired column name.

The key 'AGGREGATE' indicates that an aggregate function should be used on
the column. In this case the value must be one of 'MIN', 'MAX', 'COUNT' or
'AVG'.

=head4 Aggregate example 1

  $result = $dbi->select(
    #          first table second table
    TABLE => [ 'WORKFLOW', 'WORKFLOW_CONTEXT' ],

    # return these columns
    COLUMNS => [ 
	{ 
	    COLUMN   => 'WORKFLOW_CONTEXT.WORKFLOW_CONTEXT_KEY',
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

results in the following query:

 SELECT 
    MAX(workflow_context.workflow_context_key),
    workflow.workflow_id
 FROM workflow, workflow_context
 WHERE workflow.workflow_id=workflow_context.workflow_id 
   AND workflow_context.workflow_id=?
 ORDER BY workflow_context.workflow_context_key, 
   workflow.workflow_id


=head4 Aggregate example 2

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

results in the query

 SELECT 
    DISTINCT workflow_context.workflow_context_key
    workflow.workflow_id
 FROM workflow, workflow_context
 WHERE workflow.workflow_id=workflow_context.workflow_id 
   AND workflow_context.workflow_id=?
 ORDER BY workflow_context.workflow_context_key, 
   workflow.workflow_id

=head4 Distinct results

If you want the results to be distinct, you can specify a
global DISTINCT key with a true value. This is particularly
interesting when used with joins.

=head1 See also

OpenXPKI::Server::DBI::DBH and OpenXPKI::Server::DBI::Schema


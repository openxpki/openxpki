## OpenXPKI::Server::DBI::DBH
##
## Written 2005 by Michael Bell for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project

package OpenXPKI::Server::DBI::DBH;

use strict;
use warnings;
use utf8;
use English;
use Math::BigInt;

use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use DBI;
use OpenXPKI::Server::DBI::Schema;
use OpenXPKI::Server::DBI::Driver;

use Data::Dumper;

our ($errno, $errval);

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = bless {}, $class;

    $self->{params} = { @_ };

    ##! 1: "start"
    $self->{log} = $self->{params}->{LOG};

    ##! 64: 'log: ' . ref $self->{log}
    ## init driver
    if (not $self->{params}->{TYPE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_MISSING_DATABASE_TYPE");
    }
    $self->{driver} = OpenXPKI::Server::DBI::Driver->new (%{$self->{params}});
    ##! 2: "driver: ".$self->{driver}

    ## get schema instance
    $self->{schema} = OpenXPKI::Server::DBI::Schema->new ();

    ## init namespace
    if (exists $self->{params}->{NAMESPACE} and
        defined $self->{params}->{NAMESPACE} and
        length ($self->{params}->{NAMESPACE}))
    {
        $self->{schema}->set_namespace ($self->{params}->{NAMESPACE});
    }

    ## add server configuration
    $self->{server_id}    = $self->{params}->{SERVER_ID};
    $self->{server_shift} = $self->{params}->{SERVER_SHIFT};

    return $self;
}

#######################################################################

sub is_connected {
    # TODO -- check if this works for all our database drivers
    my $self = shift;
    ##! 1: 'start'

    return 0 if (! defined $self->{DBH});
    return $self->{DBH}->ping();
}

sub connect
{
    my $self = shift;
    ##! 1: "start"

    $self->{STH} = [];

    ##! 2: "try to connect"
    my $dsn = $self->{driver}->get_dsn ();

    # default options for all connection, can be overridden by the drivers
    my %dbi_options = (
	PrintError => 0,
	%{$self->{driver}->{dbi_option}},
	);

    ##! 2: "dsn: $dsn"
    ##! 2: "USER: ".($self->{params}->{USER} or "")
    ##! 2: "PASSWD: ".($self->{params}->{PASSWD} or "")
    ##! 2: "DBI_OPTION: " . Dumper $self->{driver}->{dbi_option}

    # FIXME: we should really use RaiseError => 1, because Oracle
    # silently raises an error if authentication was not successful
    eval {
	$self->{DBH} = DBI->connect ($dsn,
				     ($self->{params}->{USER}   or ""),
				     ($self->{params}->{PASSWD} or ""),
				     \%dbi_options);
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_CONNECT_EXCEPTION",
            params  => {
		ERRNO  => $DBI::err,
		ERRVAL => $DBI::errstr,
		EXCEPTION => $EVAL_ERROR,
	    });
    }

    if (! defined $self->{DBH}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_CONNECT_FAILED",
            params  => {"ERRNO"  => $DBI::err,
                        "ERRVAL" => $DBI::errstr});
    }

    ##! 2: "Checking AutoCommit to be off ..."
    if ($self->{DBH}->{AutoCommit} == 1) {
        ##! 4: "AutoCommit is on so I'm aborting ..."
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_AUTOCOMMIT");
    }
    ##! 2: "AutoCommit is off"

    return 1;
}

sub disconnect
{
    my $self = shift;

    if (not $self->{DBH} or $self->{DBH}->disconnect() ) {
        delete $self->{DBH} if (exists $self->{DBH});
        return 1;
    } else {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_DISCONNECT_FAILED");
    }
}

#######################################################################

sub do_query
{
    my $self = shift;
    my $keys = { @_ };

    if (! defined $self->{DBH}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_DO_QUERY_NOT_CONNECTED",
	    );
    }

    ##! 1: "start"

    # these variables are in-vars
    my $query     = $keys->{QUERY};
    if ($keys->{LIMIT} && (! ref $keys->{LIMIT})) # 'old' style, limit is just a number
    {
        if (! $keys->{LIMIT} =~ m{ \A \d+ \z }xms) {
            # LIMIT is not a number!
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_DBI_DBH_DO_QUERY_LIMIT_IS_NOT_A_NUMBER',
            );
        }
        my $tmp = $self->{driver}->{limit};
        $tmp =~ s/__QUERY__/$query/;
        $tmp =~ s/__MAXITEMS__/$keys->{LIMIT}/;
        $query = $tmp;
    }
    elsif ($keys->{LIMIT} && (ref $keys->{LIMIT} eq 'HASH')) {
        # LIMIT is a hash reference consiting of AMOUNT and START
        ##! 16: 'amount: ' . $keys->{LIMIT}->{AMOUNT}
        ##! 16: 'start:  ' . $keys->{LIMIT}->{START}
        if (! ($keys->{LIMIT}->{AMOUNT} =~ m{ \A \d+ \z }xms)) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_DBI_DBH_DO_QUERY_LIMIT_AMOUNT_IS_NOT_A_NUMBER',
            );
        }
        if (! ($keys->{LIMIT}->{START} =~ m{ \A \d+ \z }xms)) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_DBI_DBH_DO_QUERY_LIMIT_START_IS_NOT_A_NUMBER',
            );
        }
        my $tmp = $self->{driver}->{limitstart};
        $tmp =~ s/__QUERY__/$query/g;
        $tmp =~ s/__MAXITEMS__/$keys->{LIMIT}->{AMOUNT}/g;
        $tmp =~ s/__START__/$keys->{LIMIT}->{START}/g;
        $query = $tmp;
    }
    my @bind_values = ();
       @bind_values = @{$keys->{BIND_VALUES}} if ($keys->{BIND_VALUES});
    undef $keys;

    ##! 2: "query: $query"
    if (@bind_values)
    {
	### bind values: @bind_values
        ##! 4: "bind_values: " .join ("\n", map { defined $_ ? $_ : 'NULL' } @bind_values)
    } else {
        ##! 4: "no elements in bind_values present"
    }
    #foreach my $help (@bind_values) {
    #  ##! 4: "doQuery: bind_values: $help"
    #}

    ## query empty so not a DB-failure
    return undef if ($query eq "");

    ## prepare
    ##
    ## it is dangerous if we use nested loops with the same query
    ## but I do not know when this should happen
    ##
    ## queries which contain dynamic data should not be cached or we
    ## have memory leaks otherwise
    ## notafter scans for expired or valid certs are a typical problem
    ##! 2: "prepare statement"
    my $sth_nr = 0;
       $sth_nr = scalar (@{$self->{STH}}) if (exists $self->{STH} and $self->{STH});
    ##! 2: "statement nr.: ${sth_nr}"
    #FIXME: we expect clean database queries
    #if ($query =~ /[0-9]+/)
    #{
    #    ##! 4: "do not cache query"
    #    $self->{STH}[$sth_nr] = $self->{DBH}->prepare ($query);
    #} else {
    ##! 2: "caching query"
    $self->{STH}[$sth_nr] = $self->{DBH}->prepare_cached ($query);
    #}
    if (not exists $self->{STH}[$sth_nr] or
        not defined $self->{STH}[$sth_nr] or
        not ref $self->{STH}[$sth_nr])
    {
        ## necessary for Oracle
        ##! 4: "prepare failed"
        ##! 4: "query: $query"
        ##! 4: "prepare returned undef"
        delete $self->{STH}[$sth_nr];
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_PREPARE_FAILED",
            params  => {"ERRNO"  => $self->{DBH}->err,
                        "ERRVAL" => $self->{DBH}->errstr,
                        "QUERY"  => $query});
    }

    ##! 2: "execute statement"
    my $result = $self->{STH}[$sth_nr]->execute(@bind_values);

    # FIXME: we have to perform error checking here; if the DBD driver
    # experiences an error, the code below sometimes does not catch it
    # properly.
    # remedy: either have the DBD throw an exception on error
    # or use $sth->err

    if ($result && ! $self->{STH}[$sth_nr]->err)
    {
        ##! 4: "execute succeeded (leaving function - $result)"
        ##! 4: "result count: ".$self->{STH}[$sth_nr]->rows()
        return $self->{STH}[$sth_nr]->rows();
    } else {
        ##! 4: "execute failed (leaving function)"
        my $err    = $self->{STH}[$sth_nr]->err;
        my $errstr = $self->{STH}[$sth_nr]->errstr;

        if ($err == 5 && $errstr =~ m{\A database\ is\ locked }xms) {
            # this is the typical SQLite concurrency problem,
            # we try to reconnect and do the query again 10 times
            # Note that this still might not help in which case it
            # will fail - a good reason to use SQLite for testing only ...
            ##! 16: 'database is locked ... SQLite concurrency problem?'
            ##! 16: 'trying again'
            foreach my $i (1..10) {
                ##! 16: 'try #' . $i
                $self->disconnect();
                $self->connect();
                ##! 16: 'reconnected ...'
                my $sth = $self->{DBH}->prepare($query);
                ##! 16: 'statement handle created successfully'
                $result = $sth->execute(@bind_values);
                ##! 16: 'executed'
                if ($result) {
                    ##! 16: 'failover worked'
                    return $result;
                }
                ##! 16: 'failover try failed'
            }
            ##! 16: 'failover failed completely'
        }
        $self->finish_sth();
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_EXECUTE_FAILED", 
            params  => {"QUERY"  => $query,
                        "ERRNO"  => $err,
                        "ERRVAL" => $errstr});
    }
}

#######################################################################

sub get_next_sth
{
    my $self = shift;
    return 0 if (not $self->{STH});
    return scalar @{$self->{STH}};
}

sub get_sth
{
    my $self  = shift;
    my $count = scalar @{$self->{STH}} -1;
    $count = shift if (defined $_[0]);

    return undef if (not exists $self->{STH}[$count]);
    return $self->{STH}[$count];
}

sub finish_sth
{
    my $self  = shift;
    my $count = scalar @{$self->{STH}} -1;
    $count = shift if (defined $_[0]);

    return 1 if (not exists $self->{STH}[$count]);
    $self->{STH}[$count]->finish();
    $self->{STH}[$count] = undef;
    while (scalar @{$self->{STH}} and not defined $self->{STH}[scalar @{$self->{STH}} -1])
    {
        pop @{$self->{STH}};
    }

    return 1;
}

#######################################################################

sub rollback
{
    my $self = shift;
    my ($package, $filename, $line, $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(0);

    ##! 1: "start"
    return 1 if (not $self->{DBH});
 
    if ($self->{DBH}->rollback()) {
        ## if it is not used with the server (e.g. on database init)
        ## then there is no log object
        $self->{log}->log (FACILITY => "audit",
                           PRIORITY => "warn",
                           MESSAGE  => "Rollback performed.".
                                       "\nsession=".CTX('session')->get_id(),
                           MODULE   => $package,
                           FILENAME => $filename,
                           LINE     => $line)
            if ($self->{log});
        return 1;
    } else {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_ROLLBACK_FAILED");
    }
}

sub commit
{
    my $self = shift;
    my ($package, $filename, $line, $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(0);

    ##! 1: "start"
    return 1 if (not $self->{DBH});

    if ($self->{DBH}->commit()) {
        return 1;
    } else {
        if (defined $self->{log}) {
            $self->{log}->log (FACILITY => "warn",
                               PRIORITY => "error",
                               MESSAGE  => "Commit failed.".
                                          "\nsession=".CTX('session')->get_id(),
                               MODULE   => $package,
                               FILENAME => $filename,
                               LINE     => $line);
        }
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_COMMIT_FAILED",
            params  => {"ERRNO"  => $self->{DBH}->err(),
                        "ERRVAL" => $self->{DBH}->errstr()});
    }
}

#######################################################################

sub get_new_serial
{
    my $self = shift;
    my %args = @_;
    ##! 16: 'args: ' . Dumper \%args
    my $inc  = $args{'INCREASING'};
    if (! defined $inc) {
        # backward compatibility ...
        $inc = 1;
    }
    my $rand        = $args{'RANDOM_PART'};
    # the length of the random part is passed as an extra argument
    # so that the leftmost bits do not need to be 0.
    # this will be used as the width for the random part, so that serial
    # numbers always have the same length (useful if increasing serial
    # numbers are used)
    my $rand_length = $args{'RANDOM_LENGTH'};

    my $serial = Math::BigInt->new('0');
    if ($inc) {
        # if incremental serials are requested, get a new one from the
        # DB layer
        my $serial_int = $self->{driver}->get_new_serial(
            DBH   => $self,
            TABLE => $args{'TABLE'},
        );
        $serial = Math::BigInt->new("$serial_int");
        ##! 16: 'incremental serial: ' . $serial->bstr()
    }
    if (defined $rand && (length($rand) > 0)) {
        # if a random part is present, left shift the existing serial
        # (either 0 or the incremental serial from above) by the size of
        # the random part and add it to the right
        my $shift_length = $rand_length * 8;
        my $rand_hex = '0x' . unpack 'H*', $rand;
        ##! 16: 'random part in hex: ' . $rand_hex
        $serial->blsft($shift_length);
        ##! 16: 'bit shifted serial: ' . $serial->bstr()
        $serial->bior(Math::BigInt->new($rand_hex));
        ##! 16: 'combined with random part: ' . $serial->bstr()
    }

    my $server_id    = $self->{server_id};
    my $server_shift = $self->{server_shift};

    ## fix missing module spec

    $server_shift = 8 if (not exists $self->{SERVER_SHIFT});
    $server_id = 2 ** $server_shift - 1 if (not exists $self->{SERVER_ID});

    ## shift serial and add server id
    $serial->blsft($server_shift);
    ##! 16: 'bit shifted for server id: ' . $serial->bstr()
    $serial->bior(Math::BigInt->new($server_id));
    ##! 16: 'combined with server id: ' . $serial->bstr()

    return $serial->bstr();
}

sub sequence_exists
{
    my $self = shift;
    return $self->{driver}->sequence_exists(DBH => $self, @_);
}

sub create_sequence
{
    my $self = shift;
    return $self->{driver}->create_sequence(DBH => $self, @_);
}

sub drop_sequence
{
    my $self = shift;
    return $self->{driver}->drop_sequence(DBH => $self, @_);
}

#######################################################################

sub get_column_type
{
    my $self = shift;
    return $self->{driver}->get_column_type(@_);
}

sub get_abstract_column_type
{
    my $self = shift;
    return $self->{driver}->get_abstract_column_type(@_);
}

sub column_is_numeric
{
    my $self = shift;
    return $self->{driver}->column_is_numeric(@_);
}

sub column_is_string
{
    my $self = shift;
    return $self->{driver}->column_is_string(@_);
}

sub get_table_option
{
    my $self = shift;
    return $self->{driver}->get_table_option(@_);
}

#######################################################################

sub DESTROY {
    my $self = shift;

    ##! 1: "start"
    ## do not rollback or commit with a destructor
    ## if the code is unclean then it is a bug
    ## if the code is clean then rollback/commit is unnecessary

    ## finish the statement handles to reduce warnings by DBI
    ##! 2: "call finish on all statement handles to avoid warnings by DBI"
    for my $h (@{$self->{STH}}) {
        next if (not $h); ## can happen if []
        $h->finish ();
    }

    if (exists $self->{DBH} and $self->{DBH})
    {
        ## IF THERE IS A DATABASE HANDLE THEN THERE WAS CRASH
        ## IF THERE WAS A CRASH THEN WE MUST ROLLBACK
        ##! 4: "found open database handle, so enforcing rollback"
        $self->{DBH}->rollback();
        $self->{DBH}->disconnect();
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::DBI::DBH

=head1 Description

This module is the only module which uses Perl's DBI.
It manages all database interaction.

=head1 General Functions

=head2 new

is the constructor. All parameters are identical
with the ones of OpenXPKI::Server::DBI::Driver because OpenXPKI::Server::DBI::DBH
instanciates the driver for the specific database. Please
check the driver documentation (OpenXPKI::Server::DBI::Driver)
for more informations.

You should add SERVER_ID and SERVER_SHIFT to the configuration.

=head1 DBI related Functions

=head2 connect

has no parameters and starts a new database connection.

=head2 disconnect

has no parameters and disconnects from the database.

=head2 do_query

executes a query with the specified parameters. The query is defined
in QUERY and the parameters must be as an array reference in the
parameter BIND_VALUES. Please note that the value of QUERY is
cached by the relating DBD driver. So please never put any
dynamical parameters into the query.

=head2 get_next_sth

returns the ID of the next statement handle. This cam be used to
finish a statement handle explicitly via finish_sth.

=head2 get_sth

get the last statement handle or the specified statement handle.

=head2 finish_sth

finish the last statement or the specified statement. This is
majorly a memory cleanup.

=head2 rollback

rollbacks an open transaction. No parameters.

=head2 commit

commits an open transaction. No parameters.

=head2 get_new_serial

is directly mapped to OpenXPKI::Server::DBI::Driver->get_new_serial
The serial is processed after it is returned from the driver
via the configuration parameters SERVER_ID and SERVER_SHIFT.

=head2 sequence_exists

is directly mapped to OpenXPKI::Server::DBI::Driver->sequence_exists

=head2 create_sequence

is directly mapped to OpenXPKI::Server::DBI::Driver->create_sequence

=head2 drop_sequence

is directly mapped to OpenXPKI::Server::DBI::Driver->drop_sequence

=head2 Driver dependend schema infos

=head3 get_column_type

is directly mapped to OpenXPKI::Server::DBI::Driver->get_column_type

=head3 get_abstract_column_type

is directly mapped to OpenXPKI::Server::DBI::Driver->get_abstract_column_type

=head3 column_is_numeric

is directly mapped to OpenXPKI::Server::DBI::Driver->column_is_numeric

=head3 column_is_string

is directly mapped to OpenXPKI::Server::DBI::Driver->column_is_string

=head3 get_table_option

is directly mapped to OpenXPKI::Server::DBI::Driver->get_table_option

=head1 Desctructor DESTROY

rollbacks and finishs all open statement handles. Finally it disconnects
from the database if a connection is still open.

=head1 See also

DBI, OpenXPKI::Server::DBI::Driver and OpenXPKI::Server::DBI::Schema


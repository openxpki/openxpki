## OpenXPKI::Server::DBI::DBH
##
## Written by Michael Bell for the OpenXPKI project
## Copyright (C) 2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::Server::DBI::DBH;

use OpenXPKI qw(debug);
use DBI;
use OpenXPKI::Server::DBI::Schema;
use OpenXPKI::Server::DBI::Driver;

our ($errno, $errval);

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = bless {DEBUG => 0}, $class;

    $self->{params} = { @_ };

    $self->{DEBUG}  = 1 if ($self->{params}->{DEBUG});
    $self->debug ("start");
    $self->{log} = $self->{params}->{LOG};

    ## init driver
    if (not $self->{params}->{TYPE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_MISSING_DATABASE_TYPE");
    }
    $self->{driver} = OpenXPKI::Server::DBI::Driver->new (%{$self->{params}});
    $self->debug ("driver: ".$self->{driver});

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

sub set_session_id
{
    my $self = shift;
    $self->{SESSION_ID} = shift;
    return $self->{SESSION_ID};
}

#sub set_log_ref
#{
#    my $self = shift;
#    $self->{log} = shift;
#    return $self->{log};
#}

#######################################################################

sub connect
{
    my $self = shift;
    $self->debug ("start");

    $self->{STH} = [];

    $self->debug ("try to connect");
    my $dsn = $self->{driver}->get_dsn ();
    $self->debug ("dsn: $dsn");
    $self->debug ("USER: ".  ($self->{params}->{USER}   or ""));
    $self->debug ("PASSWD: ".($self->{params}->{PASSWD} or ""));
    $self->debug ("DBI_OPTION: ".$self->{driver}->{dbi_option});
    $self->{DBH} = DBI->connect ($dsn,
                                 ($self->{params}->{USER}   or ""),
                                 ($self->{params}->{PASSWD} or ""),
                                 $self->{driver}->{dbi_option});
    if (not $self->{DBH}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_CONNECT_FAILED",
            params  => {"ERRNO"  => $DBI::err,
                        "ERRVAL" => $DBI::errstr});
    }

    $self->debug ("Checking AutoCommit to be off ...");
    if ($self->{DBH}->{AutoCommit} == 1) {
        $self->debug ("AutoCommit is on so I'm aborting ...");
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_AUTOCOMMIT");
    }
    $self->debug ("AutoCommit is off");

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

    $self->debug ("entering function");

    # these variables are in-vars
    my $query     = $keys->{QUERY};
    if ($keys->{LIMIT})
    {
        my $tmp = $self->{driver}->{limit};
        $tmp =~ s/__QUERY__/$query/;
        $tmp =~ s/__MAXITEMS__/$keys->{LIMIT}/;
        $query = $tmp;
    }
    my @bind_values = ();
       @bind_values = @{$keys->{BIND_VALUES}} if ($keys->{BIND_VALUES});
    undef $keys;

    $self->debug ("query: $query");
    if (@bind_values)
    {
        $self->debug ("bind_values: ".join ("\n", @bind_values));
    } else {
        $self->debug ("no elements in bind_values present");
    }
    #foreach my $help (@bind_values) {
    #  $self->debug ("doQuery: bind_values: $help");
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
    $self->debug ("prepare statement");
    my $sth_nr = 0;
       $sth_nr = scalar (@{$self->{STH}}) if (exists $self->{STH} and $self->{STH});
    $self->debug ("statement nr.: ${sth_nr}");
    #FIXME: we expect clean database queries
    #if ($query =~ /[0-9]+/)
    #{
    #    $self->debug ("do not cache query");
    #    $self->{STH}[$sth_nr] = $self->{DBH}->prepare ($query);
    #} else {
    $self->debug ("caching query");
    $self->{STH}[$sth_nr] = $self->{DBH}->prepare_cached ($query);
    #}
    if (not exists $self->{STH}[$sth_nr] or
        not defined $self->{STH}[$sth_nr] or
        not ref $self->{STH}[$sth_nr])
    {
        ## necessary for Oracle
        $self->debug ("prepare failed");
        $self->debug ("query: $query");
        $self->debug ("prepare returned undef");
        delete $self->{STH}[$sth_nr];
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_DBH_PREPARE_FAILED",
            params  => {"ERRNO"  => $self->{DBH}->err,
                        "ERRVAL" => $self->{DBH}->errstr,
                        "QUERY"  => $query});
    }

    ## execute
    $self->debug ("execute statement");
    my $result;
    if (@bind_values)
    {
        $result = $self->{STH}[$sth_nr]->execute (@bind_values);
    } else {
        $result = $self->{STH}[$sth_nr]->execute ();
    }
    if ($result)
    {
        $self->debug ("execute succeeded (leaving function - $result)");
        return $result;
    } else {
        $self->debug ("execute failed (leaving function)");
        my $err    = $self->{STH}[$sth_nr]->err;
        my $errstr = $self->{STH}[$sth_nr]->errstr;
        $self->finish_sth();
        OpenXPKI::EXception->throw (
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

    $self->debug ("entering function");
    return 1 if (not $self->{DBH});
 
    if ($self->{DBH}->rollback()) {
        ## if it is not used with the server (e.g. on database init)
        ## then there is no log object
        $self->{log}->log (FACILITY => "audit",
                           PRIORITY => "warn",
                           MESSAGE  => "Rollback performed.".
                                       "\nsession=".$self->{SESSION_ID},
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

    $self->debug ("entering function");
    return 1 if (not $self->{DBH});

    if ($self->{DBH}->commit()) {
        return 1;
    } else {
        $self->{log}->log (FACILITY => "warn",
                           PRIORITY => "error",
                           MESSAGE  => "Commit failed.".
                                       "\nsession=".$self->{SESSION_ID},
                           MODULE   => $package,
                           FILENAME => $filename,
                           LINE     => $line);
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

    my $serial = $self->{driver}->get_new_serial (DBH => $self, @_);

    my $server_id    = $self->{server_id};
    my $server_shift = $self->{server_shift};

    ## fix missing module spec

    $server_shift = 8 if (not exists $self->{SERVER_SHIFT});
    $server_id = exp($server_shift * log(2)) -1 if (not exists $self->{SERVER_ID});

    ## shift serial and add server id
    $serial = ($serial << $server_shift) | $server_id;

    return $serial;
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

    $self->debug ("start");
    ## do not rollback or commit with a destructor
    ## if the code is unclean then it is a bug
    ## if the code is clean then rollback/commit is unnecessary

    ## finish the statement handles to reduce warnings by DBI
    $self->debug ("call finish on all statement handles to avoid warnings by DBI");
    for my $h (@{$self->{STH}}) {
        next if (not $h); ## can happen if []
        $h->finish ();
    }

    if (exists $self->{DBH} and $self->{DBH})
    {
        ## IF THERE IS A DATABASE HANDLE THEN THERE WAS CRASH
        ## IF THERE WAS A CRASH THEN WE MUST ROLLBACK
        $self->debug ("found open database handle, so enforcing rollback");
        $self->{DBH}->rollback();
        $self->{DBH}->disconnect();
    }
}

1;
__END__

=head1 Description

This module is the only module which uses Perl's DBI.
It manages all database interaction.

=head1 General Functions

=head2 new

is the constructor.
The DEBUG flag is optional. All other parameters identical
with the ones of OpenXPKI::Server::DBI::Driver because OpenXPKI::Server::DBI::DBH
instanciates the driver for the specific database. Please
check the driver documentation (OpenXPKI::Server::DBI::Driver)
for more informations.

You should add SERVER_ID and SERVER_SHIFT to the configuration.

=head2 set_session_id

configure the session ID which is used for logging.

=head2 set_log_ref

configure the instance of a logging class to support logging.
This is necessary because the database module is one of the core
modules which will be initialized first.

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


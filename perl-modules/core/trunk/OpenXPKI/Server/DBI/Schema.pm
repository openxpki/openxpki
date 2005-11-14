## OpenXPKI::Server::DBI::Schema
##
## Written by Michael Bell for the OpenXPKI project 2005
## Copyright (C) 2005 The OpenXPKI Project
## $Revision: 1.6 $

use strict;
use warnings;
use utf8;

package OpenXPKI::Server::DBI::Schema;

use OpenXPKI::Exception;

our %SEQUENCE = (
                 CRL            => "sequence_crl",
                 CSR            => "sequence_csr",
                 CERTIFICATE    => "sequence_certificate",
                 CRR            => "sequence_crr",
                 AUDITTRAIL     => "sequence_audittrail",
                 DATA           => "sequence_data",
                 GLOBAL_KEY_ID  => "sequence_global_id",
                 PRIVATE        => "sequence_private",
                 SIGNATURE      => "sequence_signature",
                 VOTING         => "sequence_voting",
                 DATAEXCHANGE   => "sequence_dataexchange",
                );
our %COLUMN = (
               PKI_REALM             => "pki_realm",
               CA                    => "ca_name",
               ISSUING_CA            => "issuing_ca",
               ISSUING_PKI_REALM     => "issuing_pki_realm",

               SUBMIT_DATE           => "submit_date",
               TYPE                  => "format",
               DATA                  => "data",

               GLOBAL_KEY_ID         => "global_id",
               CERTIFICATE_SERIAL    => "cert_key",
               REVOKE_CERTIFICATE_SERIAL => "cert_key",
               CSR_SERIAL            => "req_key",
               CRR_SERIAL            => "crr_key",
               CRL_SERIAL            => "crl_key",
               AUDITTRAIL_SERIAL     => "audittrail_key",
               DATA_SERIAL           => "data_key",
               PRIVATE_SERIAL        => "private_key",
               STATEMACHINE_SERIAL   => "statemachine_key",
               SIGNATURE_SERIAL      => "signature_key",
               VOTING_SERIAL         => "voting_key",
               LOCK_SERIAL           => "global_id",
               DATAEXCHANGE_SERIAL   => "dataexchange_key",

               SUBJECT               => "subject",
               EMAIL                 => "email",
               RA                    => "ra",
               LAST_UPDATE           => "last_update",
               NEXT_UPDATE           => "next_update",
               ROLE                  => "role",
               PUBKEY                => "public_key",
               NOTAFTER              => "notafter",
               NOTBEFORE             => "notbefore",
               SCEP_TID              => "scep_tid",
               LOA                   => "loa",
               PUBLIC                => "public_cert",
                                  
               STATUS                => "status",
               REASON                => "reason",
               SERIAL                => "object_serial",
               TABLE                 => "object_type",
               UNTIL                 => "valid_until",
               SERVERID              => "server_id",
               EXPORTID              => "export_id",

               COLUMN_NAME           => "column_name",
               ARRAY_COUNTER         => "array_counter",
               CONTENT_TYPE          => "content_type",
               NUMBER                => "int_content",
               STRING                => "char_content",

               TIMESTAMP             => "logtimestamp",
               MESSAGE               => "message",
               CATEGORY              => "category",
               LEVEL                 => "level",

               "KEYID"               => "keyid",
               "CA_KEYID"            => "ca_keyid",
               "CA_ISSUER_NAME"      => "ca_issuer_name",
               "CA_ISSUER_SERIAL"    => "ca_issuer_serial",
              );

our %TABLE = (
    CA => {
        NAME    => "ca",
        INDEX   => [ "PKI_REALM", "CA" ],
        COLUMNS => [ "PKI_REALM", "CA",
                     "CERTIFICATE_SERIAL", "ISSUING_CA", "ISSUING_PKI_REALM"
                   ]},
    CSR => {
        NAME    => "request",
        INDEX   => [ "PKI_REALM", "CSR_SERIAL" ],
        COLUMNS => [ "PKI_REALM", "CSR_SERIAL",
                     "TYPE", "DATA", "GLOBAL_KEY_ID",
                     "SUBJECT", "EMAIL", "RA",
                     "STATUS", "ROLE", "PUBKEY",
                     "SCEP_TID", "LOA"]},
    CERTIFICATE => {
        NAME    => "certificate",
        INDEX   => [ "PKI_REALM", "CA", "CERTIFICATE_SERIAL" ],
        COLUMNS => [ "PKI_REALM", "CA", "CERTIFICATE_SERIAL",
                     "TYPE", "DATA", "GLOBAL_KEY_ID",
                     "SUBJECT", "EMAIL",
                     "STATUS", "ROLE", "PUBKEY", "KEYID",
                     "NOTAFTER", "LOA", "NOTBEFORE", "CSR_SERIAL"
                   ]},
    CRR => {
        NAME    => "crr",
        INDEX   => [ "PKI_REALM", "CA", "CRR_SERIAL" ],
        COLUMNS => [ "PKI_REALM", "CA", "CRR_SERIAL",
                     "REVOKE_CERTIFICATE_SERIAL", "SUBMIT_DATE",
                     "TYPE", "DATA", "GLOBAL_KEY_ID",
                     "RA", "STATUS", "REASON" ]},
    CRL => {
        NAME    => "crl",
        INDEX   => [ "PKI_REALM", "CA", "CRL_SERIAL" ],
        COLUMNS => [ "PKI_REALM", "CA", "CRL_SERIAL",
                     "TYPE", "DATA",
                     "LAST_UPDATE", "NEXT_UPDATE"]},
    AUDITTRAIL => {
        NAME    => "audittrail",
        INDEX   => [ "AUDITTRAIL_SERIAL" ],
        COLUMNS => [ "AUDITTRAIL_SERIAL",
                     "TIMESTAMP",
                     "CATEGORY", "LEVEL", "MESSAGE" ]},
    DATA => {
        NAME    => "data",
        INDEX   => [ "DATA_SERIAL" ],
        COLUMNS => [ "DATA_SERIAL",
                     "GLOBAL_KEY_ID",
                     "COLUMN_NAME", "ARRAY_COUNTER", "CONTENT_TYPE",
                     "NUMBER", "STRING" ]},
    PRIVATE => {
        NAME    => "private",
        INDEX   => [ "PRIVATE_SERIAL" ],
        COLUMNS => [ "PRIVATE_SERIAL",
                     "DATA", "TYPE", "GLOBAL_KEY_ID"]},
    STATEMACHINE => {
        NAME    => "statemachine",
        INDEX   => [ "STATEMACHINE_SERIAL" ],
        COLUMNS => [ "STATEMACHINE_SERIAL", "STATUS" ]},
    SIGNATURE => {
        NAME    => "signature",
        INDEX   => [ "SIGNATURE_SERIAL" ],
        COLUMNS => [ "SIGNATURE_SERIAL",
                     "TABLE", "SERIAL",
                     "DATA", "TYPE" ]},
    LOCK => {
        NAME    => "lock_table",  ## because of a mysql bug we cannot create a table lock
        INDEX   => [ "LOCK_SERIAL" ],
        COLUMNS => [ "LOCK_SERIAL",
                     "TABLE", "SERIAL",
                     "UNTIL" ]},
    DATAEXCHANGE => {
        NAME    => "dataexchange",
        INDEX   => [ "DATAEXCHANGE_SERIAL" ],
        COLUMNS => [ "DATAEXCHANGE_SERIAL",
                     "TABLE", "PKI_REALM", "CA", "SERIAL",
                     "SERVERID", "EXPORTID" ]});

our %INDEX = (
   DATA_COLUMN_NAME => {
       NAME    => "data_column_name_index",
       TABLE   => "DATA",
       COLUMNS => [ "COLUMN_NAME" ]},
   DATA_GLOBAL_KEY_ID   => {
       NAME    => "data_global_id_index",
       TABLE   => "DATA",
       COLUMNS => [ "GLOBAL_KEY_ID" ]},
   DATA_GLOBAL_COLUMN => {
       NAME    => "data_global_column_index",
       TABLE   => "DATA",
       COLUMNS => [ "GLOBAL_KEY_ID", "COLUMN_NAME" ]},
   DATA_COLUMN_STRING => {
       NAME    => "data_column_string_index",
       TABLE   => "DATA",
       COLUMNS => [ "COLUMN_NAME", "STRING" ]});

sub new
{
    my $self = {};
    bless $self, "OpenXPKI::Server::DBI::Schema";
    return $self;
}

########################################################################

sub get_column
{
    my $self = shift;

    if (not exists $_[0] or
        not defined $_[0] or
        not length $_[0])
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_SCHEMA_GET_COLUMN_MISSING_COLUMN_NAME");
    }

    if (not exists $COLUMN{$_[0]})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_DBI_SCHEMA_GET_COLUMN_UNKNOWN_COLUMN",
            params  => {"COLUMN" => $_[0]});
    }

    return $COLUMN{$_[0]};
}

########################################################################

sub get_tables
{
    return [ keys %TABLE ];
}

sub get_table_name
{
    my $self = shift;
    return $TABLE{$_[0]}->{NAME};
}

sub get_table_index
{
    my $self = shift;
    return $TABLE{$_[0]}->{INDEX};
}

sub get_table_columns
{
    my $self = shift;
    return $TABLE{$_[0]}->{COLUMNS};
}

########################################################################

sub get_sequences
{
    return [ keys %SEQUENCE ];
}

sub get_sequence_name
{
    my $self = shift;
    return $SEQUENCE{$_[0]};
}

########################################################################

sub get_indexes
{
    return [ keys %INDEX ];
}

sub get_index_name
{
    my $self = shift;
    return $INDEX{$_[0]}->{NAME};
}

sub get_index_table
{
    my $self = shift;
    return $INDEX{$_[0]}->{TABLE};
}

sub get_index_columns
{
    my $self = shift;
    return $INDEX{$_[0]}->{COLUMNS};
}

########################################################################

sub set_namespace
{
    my $self = shift;

    foreach my $table (keys %TABLE)
    {
        $TABLE{$table}->{NAME} = $_[0].".".$TABLE{$table}->{NAME};
    }
    return 1;
}

1;
__END__

=head1 Description

The major job of this class is to define and manage the schema
of the OpenXPKI database backend. This means that this class
has no real internal logic. It only implements several functions
to provide the other database classes with informations about
the database schema.

=head1 Database Schema

=head2 The CA table

The CA table is used to define a CA. Sounds simple? Yes, but it is a little
bit tricky. A certificate is identified via the primary key of the
certificate table. This primary key consists of the PKI realm, the name of
the issuing CA and the serial of the certificate. If such a certificate is
used as a CA certificate then we must associated this CA with a PKI realm
and we must give the CA a symbolic name.

If you want to interpret the table in a semantical manner then the table is
a connector which defines CAs inside of a PKI realm and connects certificates
with this CA. The same CA name is used by the token configuration.

=head2 GLOBAL_KEY_ID

The GLOBAL_KEY_ID is more or less a KEY_ID. It is used to identify all objects
which are related to one key. This is for example necessary to identify all
related objects if a revocation starts because of a key compromise. GLOBAL is
used to signal everybody that this ID is a GLOBAL unique ID.

=head1 Functions

=head2 Constructor

=head3 new

The constructor does not support any parameters. Even DEBUG is
not supported.

=head2 Column informations

=head3 get_column

returns the native SQL column name for a given column name.

Example:  $schema->get_column ("CERTIFICATE_SERIAL");

=head2 Table informations

=head3 get_tables

returns all available table names (these are not the native SQL
table names).

=head3 get_table_name

returns the native SQL table name for a given table name.

=head3 get_table_index

returns an ARRAY reference to the columns which build the index of
the specified table.

=head3 get_table_columns

returns an ARRAY reference to the columns which are in
the specified table.

=head2 Sequence informations

=head3 get_sequences

returns all available sequence names (these are not the native SQL
sequence names).

=head3  get_sequence_name

returns the native SQL sequence name for a given sequence name.

=head2 Index informations

=head3 get_indexes

returns all available index names (these are not the native SQL
index names).

=head3  get_index_name

returns the native SQL index name for a given index name.

=head3 get_index_table

returns the table where an index is placed on.

=head3 get_index_columns

returns the columns which are used for an index.

=head2 Namespace handling

=head3 set_namespace

This is the only function where something is manipulated in the schema
during runtime. The namespace can be configured to seperate some users
inside the same database management system. The result is that all tables
are prefixed by the namespace.

## OpenXPKI::Server::DBI::Schema
##
## Written by Michael Bell for the OpenXPKI project 2005
## Copyright (C) 2005 The OpenXPKI Project
##

use strict;

package OpenXPKI::Server::DBI::Schema;

our %SEQUENCE = (
                 CRL            => "sequence_crl",
                 CSR            => "sequence_csr",
                 CERTIFICATE    => "sequence_certificate",
                 CRR            => "sequence_crr",
                 AUDITTRAIL     => "sequence_audittrail",
                 DATA           => "sequence_data",
                 GLOBAL_ID      => "sequence_global_id",
                 PRIVATE        => "sequence_private",
                 SIGNATURE      => "sequence_signature",
                 VOTING         => "sequence_voting",
                 DATAEXCHANGE   => "sequence_dataexchange",
                );
our %COLUMN = (
               PKI_REALM             => "pki_realm",
               CA                    => "ca_name",

               SUBMIT_DATE           => "submit_date",
               TYPE                  => "format",
               DATA                  => "data",

               GLOBAL_ID             => "global_id",
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
    CSR => {
        NAME    => "request",
        INDEX   => [ "PKI_REALM", "CSR_SERIAL" ],
        COLUMNS => [ "PKI_REALM", "CSR_SERIAL",
                     "TYPE", "DATA",
                     "SUBJECT", "EMAIL", "RA",
                     "STATUS", "ROLE", "PUBKEY",
                     "SCEP_TID", "LOA"]},
    CERTIFICATE => {
        NAME    => "certificate",
        INDEX   => [ "PKI_REALM", "CA", "CERTIFICATE_SERIAL" ],
        COLUMNS => [ "PKI_REALM", "CA", "CERTIFICATE_SERIAL",
                     "TYPE", "DATA",
                     "SUBJECT", "EMAIL",
                     "STATUS", "ROLE", "PUBKEY", "KEYID",
                     "NOTAFTER", "LOA", "NOTBEFORE", "CSR_SERIAL"
                   ]},
    CRR => {
        NAME    => "crr",
        INDEX   => [ "PKI_REALM", "CA", "CRR_SERIAL" ],
        COLUMNS => [ "PKI_REALM", "CA", "CRR_SERIAL",
                     "REVOKE_CERTIFICATE_SERIAL", "SUBMIT_DATE",
                     "TYPE", "DATA",
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
                     "GLOBAL_ID",
                     "COLUMN_NAME", "ARRAY_COUNTER", "CONTENT_TYPE",
                     "NUMBER", "STRING" ]},
    PRIVATE => {
        NAME    => "private",
        INDEX   => [ "PRIVATE_SERIAL" ],
        COLUMNS => [ "PRIVATE_SERIAL",
                     "DATA", "TYPE"]},
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
   DATA_GLOBAL_ID   => {
       NAME    => "data_global_id_index",
       TABLE   => "DATA",
       COLUMNS => [ "GLOBAL_ID" ]},
   DATA_GLOBAL_COLUMN => {
       NAME    => "data_global_column_index",
       TABLE   => "DATA",
       COLUMNS => [ "GLOBAL_ID", "COLUMN_NAME" ]},
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

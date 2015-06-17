package OpenXPKI::Server::Workflow::Activity::Reports::Summary;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::DateTime;
use DateTime;

sub execute {
    
    my $self = shift;
    my $workflow = shift;
    
    my $context = $workflow->context();
    my $pki_realm = CTX('session')->get_pki_realm(); 
    
    my $valid_at;
    if ($self->param('valid_at')) {
       $valid_at = OpenXPKI::DateTime::get_validity({        
            VALIDITY =>  $self->param('valid_at'),
            VALIDITYFORMAT => 'detect',
        });
    } else {
       $valid_at = DateTime->now();
    }
    
    my $epoch = $valid_at->epoch();
            
    my $query = {
        TABLE => [ 'CERTIFICATE' ],
        JOIN => [ ['IDENTIFIER'] ],
        DYNAMIC => { 
            'CERTIFICATE.CSR_SERIAL' => { VALUE => undef, OPERATOR => 'NOT_EQUAL' },
            'CERTIFICATE.PKI_REALM' => { VALUE => $pki_realm }
        }        
    };
    
    # as this brain dead SQL layer mangles the query hash in place when executed
    # we need to set columns key each time 
    
    # total count
    $query->{COLUMNS} = [{ COLUMN  => 'CERTIFICATE.IDENTIFIER', AGGREGATE => 'COUNT' }];
    $context->param( 'total_count', $self->_query( $query ) + 0 );
    
    # total_revoked
    $query->{COLUMNS} = [{ COLUMN  => 'CERTIFICATE.IDENTIFIER', AGGREGATE => 'COUNT' }];    
    $query->{DYNAMIC}->{'CERTIFICATE.STATUS'} = [ 'REVOKED', 'CRL_ISSUANCE_PENDING' ];
    $context->param( 'total_revoked', $self->_query( $query ) + 0 );
    
    # total_distinct
    $query->{COLUMNS} = [{ COLUMN  => 'CERTIFICATE.SUBJECT', AGGREGATE => 'UNIQUE' }];
    $query->{DYNAMIC}->{'CERTIFICATE.STATUS'} = 'ISSUED';
    $context->param( 'total_distinct', $self->_query( $query ) + 0 );

    # total_expired
    $query->{COLUMNS} = [{ COLUMN  => 'CERTIFICATE.IDENTIFIER', AGGREGATE => 'COUNT' }];
    $query->{DYNAMIC}->{'CERTIFICATE.NOTAFTER'} = { VALUE => $epoch, OPERATOR => 'LESS_THAN' };
    $context->param( 'total_expired', $self->_query( $query ) + 0 );
    
    # valid_count
    $query->{COLUMNS} = [{ COLUMN  => 'CERTIFICATE.IDENTIFIER', AGGREGATE => 'COUNT' }];
    $query->{DYNAMIC}->{'CERTIFICATE.NOTBEFORE'} = { VALUE => $epoch, OPERATOR => 'LESS_THAN' };
    $query->{DYNAMIC}->{'CERTIFICATE.NOTAFTER'} = { VALUE => $epoch, OPERATOR => 'GREATER_THAN' };
    $context->param( 'valid_count', $self->_query( $query ) + 0 );

    # valid_distinct
    $query->{COLUMNS} = [{ COLUMN  => 'CERTIFICATE.SUBJECT', AGGREGATE => 'UNIQUE' }];
    $query->{DYNAMIC}->{'CERTIFICATE.NOTBEFORE'} = { VALUE => $epoch, OPERATOR => 'LESS_THAN' };
    $query->{DYNAMIC}->{'CERTIFICATE.NOTAFTER'} = { VALUE => $epoch, OPERATOR => 'GREATER_THAN' };
    $context->param( 'valid_distinct', $self->_query( $query ) + 0 );
      
    # Expiry cutoff date
    
    my $near_expiry_validity = $self->param('near_expiry') || '+000030';    
    my $expiry_cutoff = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE => $valid_at,
        VALIDITY => $near_expiry_validity,
        VALIDITYFORMAT => 'detect',
    })->epoch();
    
    # near_expiry
    $query->{COLUMNS} = [{ COLUMN  => 'CERTIFICATE.IDENTIFIER', AGGREGATE => 'COUNT' }];   
    $query->{DYNAMIC}->{'CERTIFICATE.NOTAFTER'} = { OPERATOR => 'BETWEEN', VALUE => [ $epoch, $expiry_cutoff ] };
    $context->param( 'near_expiry', $self->_query( $query ) + 0 );


    my $recent_expiry_validity = $self->param('recent_expiry') || '-000030';
    $expiry_cutoff = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE => $valid_at,
        VALIDITY => $recent_expiry_validity,
        VALIDITYFORMAT => 'detect',
    })->epoch();    

    $query->{COLUMNS} = [{ COLUMN  => 'CERTIFICATE.IDENTIFIER', AGGREGATE => 'COUNT' }];    
    $query->{DYNAMIC}->{'CERTIFICATE.NOTAFTER'} = { OPERATOR => 'BETWEEN', VALUE => [ $expiry_cutoff, $epoch ] };    
    $context->param( 'recent_expiry', $self->_query( $query ) + 0 );
    
    
      
} 

sub _query {
    
    my $self = shift;
    my $query = shift;

    ##! 32: 'Query ' . Dumper $query
    my $col = $query->{COLUMNS}->[0]->{COLUMN};
    
    my $result = CTX('dbi_backend')->select(%{$query});
    
    ##! 32: 'Result ' . Dumper $result
    
    if (!(defined $result && ref $result eq 'ARRAY' && scalar @{$result} == 1)) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SEARCH_CERT_COUNT_SELECT_RESULT_NOT_ARRAY',
            params => { 'TYPE' => ref $result, },
        );
    }
        
    return $result->[0]->{ $col };
    
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Reports::Summary

=head1 Description

Collect statistics about certificate counts, the resulting numbers are 
written into the context, see below. 

=head1 Configuration

=head2 Activity parameters

=over 

=item near_expiry

Parseable OpenXPKI::Datetime value (autodetected), certificates expiring
before the given date are shown as "near_expiry".
Default is +000030 (30 days).

=item recent_expiry

Parseable OpenXPKI::Datetime value (autodetected), certificates which are
expired after the given date are shown as "recent_expiry".
Default is -000030 (30 days in the past).

=item valid_at

Parseable OpenXPKI::Datetime value (autodetected) used as based for all
date related calculations. Default is now.

=item cutoff_notbefore (not implemented yet)

Parseable OpenXPKI::Datetime value (autodetected), hide certificates where
notbefore is below given date.

=item cutoff_notafter (not implemented yet)

Parseable OpenXPKI::Datetime value (autodetected), hide certificates where
notafter is above given date.

=back 

=head2 Context parameters

After completion the following context parameters will be set:

=over 12

=item total_count

Total number of certificates.

=item total_revoked

Number of certificates in revoked status (includes CRL pending).

=item total_expired

Number of expired certificates

=item total_distinct

Number of distinct subjects

=item valid_count

Number of valid certificates

=item valid_distinct

Number of distinct subjects within valid certificates

=item near_expiry, recent_expiry

Number of valid (not revoked) certificates within expiry window.

=back
 



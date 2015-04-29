
package OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicySubjectDuplicate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::DN;
use OpenXPKI::DateTime;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    
    my $cert_subject = $context->param('cert_subject');


    my $query = {
        STATUS => 'ISSUED',
        ENTITY_ONLY => 1,
    };
    
    if ($self->param('any_realm')) {
        ##! 32: 'Any realm requested'
        $query->{PKI_REALM} = '_ANY';
    }
    
    if ($self->param('cn_only')) {
        ##! 32: 'match cn only'        
        my $dn = new OpenXPKI::DN( $cert_subject );
        my %hash = $dn->get_hashed_content();
        $query->{SUBJECT} = 'CN='.$hash{CN}[0].',%';            
    } else {
        $query->{SUBJECT} = $cert_subject.'%';        
    }
    
    if (my $renewal = $self->param('allow_renewal_period')) {
        ##! 16: 'Renewal allowed in period ' . $renewal        
        my $notafter = OpenXPKI::DateTime::get_validity({        
            VALIDITY => $renewal,
            VALIDITYFORMAT => 'detect',
        });        
   
        $query->{NOTAFTER} = $notafter->epoch();
    } else {      
        $query->{NOTAFTER} = time();        
    }
    
    ##! 32: 'Search duplicate with query ' . Dumper $query
    
    my $result = CTX('api')->search_cert($query);
    
    ##! 16: 'Search returned ' . Dumper $result
    my @identifier = map {  $_->{IDENTIFIER} } @{$result};
    
    if (@identifier) {

        my $ser = OpenXPKI::Serialization::Simple->new();
        $context->param('check_policy_subject_duplicate', $ser->serialize(\@identifier) );
                
        CTX('log')->log(
            MESSAGE => "Policy subject duplicate check failed, found certs " . Dumper \@identifier,
            PRIORITY => 'info',
            FACILITY => [ 'application', ],
        );
                  
    } else {
        
        $context->param( { 'check_policy_subject_duplicate' => undef } );
        
    }
    
    return 1;
}

1;

=head1 NAME

OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicySubjectDuplicate

=head1 DESCRIPTION

Check if another certificate with the same subject already exists. The 
default is to check against entity certificates in the same realm which
are not expired and not revoked. Tthis includes certificates with a 
notbefore date in the future! 
See the parameters section for other search options.

=head2 Configuration parameters

=item any_realm

Boolean, search certificates globally.

=item match_profile (NOT IMPLEMENTED YET)

Boolean, duplicate only if profile is the same (profile must be given in
action parameter cert_profile). Hint: Use the _map_syntax to grab the 
profile from the workflow.

=item cn_only

Check only on the common name of the certificate.

=item allow_renewal_period

Set to a OpenXPKI::DateTime validity specification (eg. +0003 for three
month) to allow renewals within a defined period. Certificates which expire
within the given period are not considered to trigger a duplicate error.


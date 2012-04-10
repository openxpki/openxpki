 
package OpenXPKI::Server::Workflow::Activity::SmartCard::ApplyCSRPolicy;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;
use Template;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $config = CTX('config');
    
    # The certifiacte type of the current loop is in csr_cert_type
    my $cert_type = $context->param('csr_cert_type');
    ##! 8: ' Prepare CSR for cert type ' . $cert_type 
        
    # Get profile from certificate type
    my $cert_profile = $config->get( [ 'smartcard.policy.certs.type', $cert_type, 'allowed_profiles.0' ] );
    my $cert_role = $config->get( [ 'smartcard.policy.certs.type', $cert_type, 'role' ] ) || 'User';
    ##! 8: ' Prepare CSR for profile '. $cert_profile .' with role '. $cert_role 

    # cert_issuance_data is an array of hashes, one entry per certificate
    
    my $cert_issuance_data_context = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        { workflow => $workflow , context_key => 'cert_issuance_data' } );
    
       
    # prepare LDAP variable hashref for Template Toolkit
    # TODO should be renamed with other prefix (see CheckPrereqs)
    my $ldap_vars;
    foreach my $param (keys %{ $context->param() }) {
        if ($param =~ s{ \A ldap_ }{}xms) {
            ##! 64: 'adding param ' . $param . ' to ldap_vars, value: ' . $context->param('ldap_' . $param)
            $ldap_vars->{$param} = $context->param('ldap_' . $param);
        }
    }
    
    my $cert_subject_template = $config->get( [ 'profile', $cert_profile, 'subject' ] );
    my $sans_template = $config->get( [ 'profile', $cert_profile, 'subject_alternative_names' ] ) || '';
                          
    # Todo - fetch the necessary params from connector                          
                          
    # process subject using TT
    
    my $tt = Template->new();
    my $cert_subject = '';
    $tt->process(\$cert_subject_template, $ldap_vars, \$cert_subject);
    ##! 16: 'cert_subject: ' . $cert_subject

    # process subject alternative names using TT    
    my $cert_subj_alt_names = '';
    $tt->process(\$sans_template, $ldap_vars, \$cert_subj_alt_names);
    ##! 16: 'cert_subj_alt_names: ' . $cert_subj_alt_names

    my @sans = split(/,/, $cert_subj_alt_names);
    foreach my $entry (@sans) {
        my @tmp_array = split(/=/, $entry);
        $entry = \@tmp_array;
    }
    ##! 16: '@sans: ' . Dumper(\@sans)
 
 
    # Mark escrow certificates
    my $escrow_key_handle = ''; 
    if ($config->get( [ 'smartcard.policy.certs.type', $cert_type, 'escrow_key' ] ) && 
        $context->param('temp_key_handle')) {
        $escrow_key_handle =  $context->param('temp_key_handle');
    }
    # Unset 
    $context->param({ temp_key_handle => undef });
        
    my $cert_issuance_hash_ref = {
        'escrow_key_handle'     => $escrow_key_handle,
        'pkcs10'                => $context->param('pkcs10'),
        'csr_type'              => 'pkcs10',
        'cert_profile'          => $cert_profile,
        'cert_role'             => $cert_role,
        'cert_subject'          => $cert_subject,
        'cert_subject_alt_name' => \@sans,
    };
    ##! 16: 'cert_iss_hash_ref: ' . Dumper($cert_issuance_hash_ref)
    $cert_issuance_data_context->push( $cert_issuance_hash_ref );
    
    ##! 4: 'end'
    ##! 16: 'chosen_loginid: ' . $context->param('chosen_loginid')
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::ApplyCSRPolicy

=head1 Description

This class takes the CSR from the client and sets up an array of
hashrefs in the context (cert_issuance_data) which contains all
information needed to persist them in the database and then fork
certificate issuance workflows.


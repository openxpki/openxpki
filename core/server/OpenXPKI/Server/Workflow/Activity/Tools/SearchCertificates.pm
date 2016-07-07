
package OpenXPKI::Server::Workflow::Activity::Tools::SearchCertificates;

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
    
    my $cert_subject = $self->param('cert_subject');
    my $realm = $self->param('realm');
    my $profile = $self->param('profile');
    my $issuer = $self->param('issuer');

    my @param = $self->param();

    my $query = {
        STATUS => 'ISSUED',
        ENTITY_ONLY => 1,
        CERT_ATTRIBUTES => [] 
    };
    
    if ($cert_subject) {
        ##! 16: 'Adding subject ' . $cert_subject
        $query->{SUBJECT} = $cert_subject;
    }
    
    if ($realm) {
        ##! 16: 'Adding realm ' . $realm
        $query->{PKI_REALM} = $realm;
    }
    
    if ($profile) {
        ##! 16: 'Adding profile ' . $profile
        $query->{PROFILE} = $profile;
    }
   
    if ($issuer) {
        ##! 16: 'Adding issuer ' . $issuer
        $query->{ISSUER_IDENTIFIER} = $issuer;
    }
   
    
    foreach my $key (@param) {
        ##! 16: 'Checking key ' . $key
        if ($key =~ /^(meta_|system_|subject_alt_name)/) {
            my $value = $self->param($key);
            ##! 16: 'Add key with value ' . $value 
            push @{$query->{CERT_ATTRIBUTES}},  { KEY => $key, VALUE => $value };
        }   
    }

    ##! 32: 'Full query ' . Dumper $query;
    my $result = CTX('api')->search_cert($query);
    
    ##! 64: 'Search returned ' . Dumper $result
    my @identifier = map {  $_->{IDENTIFIER} } @{$result};

    my $target_key = $self->param('target_key') || 'cert_identifier_list';
    
    if (@identifier) {
        
        my $ser = OpenXPKI::Serialization::Simple->new();
        $context->param( $target_key , $ser->serialize(\@identifier) );
                
        CTX('log')->log(
            MESSAGE => "SearchCertificates result " . Dumper \@identifier,
            PRIORITY => 'debug',
            FACILITY => [ 'application', ],
        );
                  
    } else {
        
        $context->param( { $target_key => undef } );
        
    }
    
    return 1;
}

1;

=head1 NAME

OpenXPKI::Server::Workflow::Activity::Tools::SearchCertificates

=head1 DESCRIPTION

Search for certificates based on several criteria, useful as prestage for
duplicate/renewal check or for bulk actions. The result is a list of 
identifiers written to context defined by target_key.

See the parameter section for available filters.

=head1 Configuration

=head2 Example

 class: OpenXPKI::Server::Workflow::Activity::Tools::SearchCertificates
    param:
        profile: I18N_OPENXPKI_PROFILE_TLS_SERVER
        realm: ca-one
        issuer: YHkkLxEKtqbopNbcFwdBcHqKWPE
        target_key: other_key
        
=head2 Configuration parameters

=over 

=item realm

The realm to search in, default is the current realm, I<_any> searches globally

=item profile 

The profile of the certificate, default is all profiles.

=item cert_subject

Searches the full DN for an exact match! The '*' as wildcard is supported.

=item subject_alt_name

Searches in the SAN section, you must prefix the value with the SAN type, 
e.g. DNS:www.openxpki.org or IP:1.2.3.4. There might be some difficulties 
with non-ascii strings/encodings.

=item issuer

The certificate identifier of the issuer

=item meta_*, system_*

Lets you search for any certificate attribute having a listed prefix.

=item target_key

Name of the context value to write the result to, the default is 
I<cert_identifier_list>.

=back
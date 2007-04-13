# OpenXPKI::Server::Workflow::Activity::CertLdapPublish::ImportPublicData
# Written by Petr Grigoriev for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project
# $Revision$


package OpenXPKI::Server::Workflow::Activity::CertLdapPublish::ImportPublicData;

use strict;

use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::X509;
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::CertLdapPublish::ImportPublicData';
use Data::Dumper;
use utf8;

sub execute {
    my $self     = shift;
    my $workflow = shift;

    my $context    = $workflow->context();
    my $cert_data = $context->param('certificate');
    my $cert_role = $context->param('cert_role');


    ##! 129: 'LDAP IMPORT checking role'
    my $pki_realm = CTX('api')->get_pki_realm();
    my $realm_config = CTX('pki_realm')->{$pki_realm};
    my $ldap_excluded_roles = $realm_config->{ldap_excluded_roles};

    if ( $ldap_excluded_roles =~  /^\s*${cert_role}\s*\,/m  |
         $ldap_excluded_roles =~ /\,\s*${cert_role}\s*\,/m  |
         $ldap_excluded_roles =~ /\,\s*${cert_role}\s*$/m   |
         $ldap_excluded_roles =~  /^\s*${cert_role}\s*$/m  
        ){
              ##! 129: 'LDAP IMPORT - excluded due to role'
              $context->param('cert_permission' => 'no' );
              
    }
    else {
              ##! 129: 'LDAP IMPORT - the role accepted'
              $context->param('cert_permission' => 'yes' );
    };
    
    ##! 129: 'LDAP IMPORT getting a certificate from the context'    
    my $tm = CTX('crypto_layer');

    my $default_token = $tm->get_token(
			        TYPE      => 'DEFAULT',
			        PKI_REALM => $pki_realm,
			     );

    if (! defined $default_token) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_IMPORT_CERTIFICATE_TOKEN_UNAVAILABLE",
        );
    };
    
    my $x509 = OpenXPKI::Crypto::X509->new(
        TOKEN => $default_token,
        DATA  => $cert_data,
    );

    my %cert_hash = $x509->to_db_hash();

    ##! 129: 'LDAP IMPORT extracting e-mail info from db-hash'    
    my $cert_mail="";
    if (exists $cert_hash{'EMAIL'}){
         $cert_mail = $cert_hash{'EMAIL'};
    }; 

    ##! 129: 'LDAP IMPORT setting mail attribute'    
    $context->param('cert_mail' => $cert_mail);

    ##! 129: 'LDAP IMPORT setting LDAP node dn'    
    $context->param('cert_subject' => $cert_hash{'SUBJECT'});
    return;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Certificate::ImportPublicData

=head1 Description

Imports the certificate data  into the context.

=head2 Context parameters

Expects the following context parameter:

=over 12

=item certificate

The certificate is a PEM-coded certificate from CertificateIssue Workflow

=item cert_role

The certificate role as set in CertificateIssue Workflow

=back

Writes the following context parameters:

=over 12

=item cert_mail

E-mail addresses extracted from the PEM-coded certificate using
X509->to_db_hash()

=item cert_permission

Just 'yes' if the certificate role is not present in the
list of ldap-publishing exceptions and 'no' otherwise

=item cert_subject

Certificate subject extracted from the PEM-coded certificate using
X509->to_db_hash() and prepaired to be used as a dn of the LDAP node  to
which the certificate will be added

=back

=head1 Functions

=head2 execute

Executes the action.

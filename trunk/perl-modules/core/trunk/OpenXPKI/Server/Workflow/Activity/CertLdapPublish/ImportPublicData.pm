# OpenXPKI::Server::Workflow::Activity::CertLdapPublish::ImportPublicData
# Written by Petr Grigoriev for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project


package OpenXPKI::Server::Workflow::Activity::CertLdapPublish::ImportPublicData;

use strict;

use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::X509;
use OpenXPKI::Exception;
use OpenXPKI::Debug;
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
    my $cfg_id = $self->config_id();
    ##! 128: 'config_id: ' . $cfg_id
    my $realm_config = CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm};
    ##! 128: 'realm_config: ' . Dumper $realm_config
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
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_IMPORT_CERTIFICATE_TOKEN_UNAVAILABLE",
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

    ##! 129: 'LDAP IMPORT setting serialNumber attribute'    
    $context->param('cert_serial' => $cert_hash{'CERTIFICATE_SERIAL'});

    ##! 129: 'LDAP IMPORT check DirName for LDAP node DN'
    my $cert_dn = $cert_hash{'SUBJECT'} ;

#    FIXME
#
#    OpenXPKI fails to accept DirName SAN at the moment 
# 
#    my @subject_alt_names = $x509->get_subject_alt_names();
#    foreach my $san (@subject_alt_names) {
#       next if ($san->[0] ne "DirName");
#       $cert_dn = $san->[1];
       ##! 129: 'LDAP IMPORT DirName detected '.$cert_dn
#       last;
#    };

    ##! 129: 'LDAP IMPORT setting LDAP node DN '.$cert_dn    
    $context->param('cert_subject' => $cert_dn);
 
#   FIXME 
#
#   Using Workflow condition causes OpenXPKI server to connect 3 times to ldap-server
#   while checking two opposite conditions
#   So checking node is placed here for the time being
#   Condition just uses the preset flag to make a decision
#
    ##! 129: 'LDAP IMPORT setting LDAP node exist FLAG '

    my $dn_filter  = $cert_dn;
    $dn_filter =~ s/=.*$//;   
    $dn_filter = $dn_filter."=*";
    ##! 129: 'LDAP PUBLIC CONDITION prepairing search filter: '.$dn_filter

    ##! 129: 'LDAP PUBLIC CONDITION connecting to LDAP server'
    my $ldap_passwd  = $realm_config->{ldap_password};
    my $ldap_user    = $realm_config->{ldap_login};
    my $ldap_server  = $realm_config->{ldap_server};
    my $ldap_port    = $realm_config->{ldap_port};
#
#   FIXME 
#   we do not need suffix at the moment, and later the realm 
#   configuration will be changed to multi-suffix version
#   my $ldap_suffix  = $realm_config->{ldap_suffix};
    my $ldap_version = $realm_config->{ldap_version};

    my $ldap = Net::LDAP->new(
                              "$ldap_server",
            		      port => $ldap_port,
                          );
    if (! defined $ldap) {
       OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_IMPORT_LDAP_CONNECTION_FAILED",
            params  => {
                        'LDAP_SERVER'  => $ldap_server,
      		     'LDAP_PORT'  => $ldap_port,
   	            },
                log => {
                        logger => CTX('log'),
       	              priority => 'error',
       		      facility => 'monitor',
   		       },
       );
    };																    
    ##! 129: 'LDAP PUBLIC CONDITION connected to LDAP server OK'

    ##! 129: 'LDAP PUBLIC CONDITION binding to LDAP root node'
    my $mesg = $ldap->bind (
                            "$ldap_user",
                             password =>  "$ldap_passwd",
                              version =>  "$ldap_version",
         	           );
    if ($mesg->is_error()) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_IMPORT_LDAP_BIND_FAILED",
            params  => {
                        ERROR      => $mesg->error(),
                        ERROR_DESC => $mesg->error_desc(),
   	               },
                log => {
   	                 logger => CTX('log'),
         	       priority => 'error',
	               facility => 'monitor',
      		       },
        );
    };																    
    ##! 129: 'LDAP PUBLIC CONDITION bind OK'


    ##! 129: 'LDAP PUBLIC CONDITION starting search node'
    my  $search = $ldap->search (
                                 base    => $cert_dn,
                                 scope   => 'base',
                   	          filter => $dn_filter,	
			           attrs => ['1.1']
                               );
    if ( $search->is_error()){
       ##! 129: 'LDAP PUBLIC CONDITION node NOT FOUND'
       $context->param('node_exist' => 'no');

    }
    else { 
       ##! 129: 'LDAP PUBLIC CONDITION check node FOUND'
       $context->param('node_exist' => 'yes');
    }; 
    $ldap->unbind;
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


=item cert_serial

Serial number of the certificate extracted from the PEM-coded certificate using
X509->to_db_hash()

=item cert_permission

Just 'yes' if the certificate role is not present in the
list of ldap-publishing exceptions and 'no' otherwise

=item node_exist

Just 'yes' if the LDAP node already exists and 'no' otherwise
This parameter is used temporarily to avoid multiple LDAP connections
while checking the condition via workflow

=item cert_subject

Certificate subject extracted from the PEM-coded certificate using
X509->to_db_hash() and prepaired to be used as a DN of the LDAP node  to
which the certificate will be added. If the subject alternative name
attribute DirName found it is used as LDAP node DN instead of the
certificate subject.

=back

=head1 Functions

=head2 execute

Executes the action.

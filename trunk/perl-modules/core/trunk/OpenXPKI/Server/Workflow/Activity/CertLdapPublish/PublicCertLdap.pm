# OpenXPKI::Server::Workflow::Activity::CertLdapPublish::PublicCertLdap
# Written by Petr Grigoriev for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project


package OpenXPKI::Server::Workflow::Activity::CertLdapPublish::PublicCertLdap;

use strict;


use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::DN;
use utf8;
use Net::LDAP;

sub execute {
 my $self = shift;
 my $workflow = shift;
 
    my $context  = $workflow->context();
    my $cert_role = $context->param('cert_role');
    my $cert_permission = $context->param('cert_permission');
    
    if ( $cert_permission eq 'no' ){
        ##! 129: 'LDAP ACTION PUBLIC  excluded due to role '.$cert_role
        return 1;    
    };

    ##! 129: 'LDAP ACTION PUBLIC  converting the certificate'
    my $cert_dn  = $context->param('cert_subject');
    my $cert_data = $context->param('certificate');

    my $pki_realm = CTX('api')->get_pki_realm();
    my $realm_config = CTX('pki_realm_by_cfg')->{$self->config_id()}->{$pki_realm};

    my $tm = CTX('crypto_layer');
    my $default_token = $tm->get_token(
				        TYPE      => 'DEFAULT',
				        PKI_REALM => $pki_realm,
				      );
    if (! defined $default_token) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_PUBLISH_CERTIFICATE_TOKEN_UNAVAILABLE",
            );
    };
    my $cert_der = $default_token->command({
                    			    COMMAND => "convert_cert",
		                    	    DATA    => $cert_data,
					    OUT     => "DER",
			                    IN      => "PEM",
					    }
				   );
    if (! defined $cert_der) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_PUBLISH_CERTIFICATE_CONVERSION_FAILED",
        );
    };

    ##! 129: 'LDAP ACTION PUBLIC connecting to LDAP server'
    my $ldap_passwd  = $realm_config->{ldap_password};
    my $ldap_user    = $realm_config->{ldap_login};
    my $ldap_server  = $realm_config->{ldap_server};
    my $ldap_port    = $realm_config->{ldap_port};
#
#   FIXME
#   At the moment we are using only the first suffix of multi-suffix 
#   configuration.  Suffix selection will be added later.
#
    my $ldap_suffix  = $realm_config->{ldap_suffix}->[0];
    my $ldap_version = $realm_config->{ldap_version};


    my $ldap = Net::LDAP->new(
                              "$ldap_server",
 			      port => $ldap_port,
                             );
    if (! defined $ldap) {
       OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_PUBLISH_CERTIFICATE_LDAP_CONNECTION_FAILED",
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

    my $mesg = $ldap->bind (
                             "$ldap_user",
                             password => "$ldap_passwd",
                             version =>  "$ldap_version",
	       );
    if ($mesg->is_error()) {
       OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_PUBLISH_CERTIFICATE_LDAP_BIND_FAILED",
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
   ##! 129: 'LDAP ACTION PUBLIC connected to LDAP server OK'

   ##! 129: 'LDAP ACTION PUBLIC check certs'
   my $attr='userCertificate;binary';
   my $search = $ldap->search ( base    => $cert_dn,
                             scope   => 'base',
			     filter => 'objectClass=*',	
			     attrs => $attr,
                            );
   if ( $search->is_error()){
      ##! 129: 'LDAP ACTION PUBLIC certificates SEARCH FAILED'
       OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_PUBLISH_CERTIFICATE_LDAP_SEARCH_FAILED",
            params  => {
                        ERROR      => $search->error(),
			ERROR_DESC => $search->error_desc(),
	         	},
                log => {
	                  logger => CTX('log'),
		        priority => 'error',
			facility => 'monitor',
		        },
      );
   };
   
   # check how many certificates there is in the node
   my @cert_values = ($search->entries)[0]->get_value ($attr);
   my $number = scalar @cert_values;

   ##! 129: 'LDAP ACTION PUBLIC certificates found '.$number

   # now we add our new certificate to the stack and check for duplication
   push @cert_values, $cert_der;
   @cert_values = sort @cert_values;
   for (my $i=1; $i < scalar @cert_values; $i++) {
      if ($cert_values[$i] eq $cert_values[$i-1]) {
         splice @cert_values, $i, 1;
         $i--;
      };
   }; 
   
   $number = scalar @cert_values;
   ##! 129: 'LDAP ACTION PUBLIC certificates prepaired '.$number
   
   # no we add all prepaired certificates to the node
   $mesg = $ldap->modify (
                              $cert_dn, 
                              changes => [
                                 replace => [
				    $attr => [ 
				       @cert_values 
				    ],
				 ],
                              ],
		);
  if ($mesg->is_error()){
      ##! 129: 'LDAP ACTION PUBLIC add certificates FAILED'
      OpenXPKI::Exception->throw(
          message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_PUBLISH_CERTIFICATE_LDAP_MODIFY_FAILED",
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
  } else { 
     ##! 129: 'LDAP ACTION PUBLIC add certificates SUCCESS'
  };

$ldap->unbind;
return 1;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CertLdapPublish::PublicCertLdap

=head1 Description

This activity adds issued certificate to the existing LDAP node.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item certificate

PEM-coded certificate to be published

=item cert_subject

The certificate subject which will be used as LDAP node DN 

=item cert_permission

Parameter set to 'yes' permits to publish the certificate.
If set to 'no' shows that the certificate role is marked 
in ldappublic.xml as excluded from publishing list. 

=back

Does not create or change context parameters

=head1 Functions

=head2 execute

Executes the action.

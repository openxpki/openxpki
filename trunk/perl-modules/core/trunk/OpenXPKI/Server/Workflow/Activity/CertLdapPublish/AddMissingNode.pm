# OpenXPKI::Server::Workflow::Activity::CertLdapPublish::AddMissingNode
# Written by Petr Grigoriev for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project


package OpenXPKI::Server::Workflow::Activity::CertLdapPublish::AddMissingNode;
use base qw( OpenXPKI::Server::Workflow::Activity );

use strict;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::DN;

use Net::LDAP;
use Data::Dumper;


sub execute {
    my $self = shift;
    my $workflow = shift;
 
    my $pki_realm = CTX('api')->get_pki_realm();
    my $realm_config = CTX('pki_realm_by_cfg')->{$self->config_id()}->{$pki_realm};

    ##! 129: 'LDAP PUBLIC ADD NODE connecting to LDAP server'
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
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_ADD_DN_LDAP_CONNECTION_FAILED",
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
    ##! 129: 'LDAP PUBLIC ADD NODE connected to LDAP server OK'

    ##! 129: 'LDAP PUBLIC ADD NODE binding to LDAP root node'
    my $mesg = $ldap->bind (
                            "$ldap_user",
                             password =>  "$ldap_passwd",
                              version =>  "$ldap_version",
         	           );
    if ($mesg->is_error()) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_ADD_DN_LDAP_BIND_FAILED",
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
    ##! 129: 'LDAP PUBLIC ADD NODE bind OK'

    my $context  = $workflow->context();
    my $cert_serial = $context->param('cert_serial');
    my $cert_mail = $context->param('cert_mail');
    my $cert_dn  = $context->param('cert_subject');
    
    
    ##! 129: 'LDAP PUBLIC ADD NODE prepaire extra attributes hash'
    #
    # FIXME    SN added artificially 
    #
    my $cert_extra_attrs = {
       'serialnumber' => $cert_serial,
                 'sn' => 'NOT SUBSTITUTED YET',
    };
        
    ##! 129: 'LDAP PUBLIC ADD NODE check mail'
    if ( $cert_mail ne '' ){
       my @cert_mails = split /,/,$cert_mail;
       $cert_extra_attrs->{'mail'}=\@cert_mails;
    };

 ##! 129: 'LDAP PUBLIC ADD NODE parsing suffix '.$ldap_suffix
 my $suffix_parser = OpenXPKI::DN->new($ldap_suffix);
 my $suffix_parsed = scalar $suffix_parser->get_parsed();
 my $suffix_length = scalar $suffix_parsed;

  
 ##! 129: 'LDAP PUBLIC ADD NODE parsing cert dn '.$cert_dn
 my $dn_parser = OpenXPKI::DN->new($cert_dn);
 my @rdns     = $dn_parser->get_rdns();
 my %rdn_hash = $dn_parser->get_hashed_content();
 my @dn_parsed = $dn_parser->get_parsed();

 # number of RDNS
 my $n_dns = scalar @dn_parsed;

 # setting the schema for nodes to be added
 my $schema_profile='default';
 
 # here we store already processed attributes 
 my $dn_hash= { };
 
 # current node DN is empty yet
 my $node_dn = $ldap_suffix;

 ##! 129: 'LDAP PUBLIC ADD NODE parsing DN - found $n_dns nodes' 
 for ( my $i= $n_dns - $suffix_length-1 ; $i > -1 ; $i--){

  if ( $i == 0 ){ 
      # we are going to add a certificate to this node and so use a different
      # set of attributes and object classes
      ##! 129: 'LDAP PUBLIC ADD NODE last node' 
      $schema_profile='certificate';
  };

  #building DN for the current node
  $node_dn = $rdns[$i].",".$node_dn;

  ##! 129: 'LDAP PUBLIC ADD NODE parsing RDN '. $node_dn  

  
  my $n_as =  scalar @{$dn_parsed[$i]};
  ##! 129: 'LDAP PUBLIC ADD NODE found attributes: '. $n_as  
  
  # hash for already processed attributes of the current RDN
  my %seen_object_classes = ();
  my %seen_attributes = ();

  # hash of attributes detected in the current RDN
  my $rdn_hash = { };
  
  # array for ldap->add arguments (attributes and objectClasses)
  my $add_ldap_args = [ ];
  
  ##! 129: 'LDAP ADD NODE store attributes'  
  for ( my $j=0 ; $j < $n_as ; $j++){
   my $attr_name  = $dn_parsed[$i][$j]->[0];
   my $attr_value = $dn_parsed[$i][$j]->[1];
   $self->__push_to_hash( $rdn_hash, $attr_name, $attr_value );
   $self->__push_to_hash(  $dn_hash, $attr_name, $attr_value );
  };

  ##! 129: 'LDAP ADD NODE process attributes using realm SCHEMA'  
  for ( my $j=0 ; $j < $n_as ; $j++){
   my $attr_name  = $dn_parsed[$i][$j]->[0];
   my $attr_value = $dn_parsed[$i][$j]->[1];
   ##! 129: 'LDAP ADD NODE attribute $attr_name =  $attr_value'

   $attr_name= lc $attr_name;

   if ( ! defined $realm_config->{schema}->{$schema_profile}->{$attr_name}){
       $ldap->unbind;
       OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_ADD_DN_ATTRIBUTE_NOT_IN_SCHEMA",
            params  => {
                            'NODE DN'  => $node_dn,
			 'ATTTRIBUTE'  => $attr_name,
	         	},
                log => {
	                  logger => CTX('log'),
		        priority => 'error',
			facility => 'monitor',
		        },
	);
   };

   ##! 129: 'LDAP ADD NODE structural classes'
   my @s_classes = @{$realm_config->{schema}->{$schema_profile}->{$attr_name}->{structural}};
   my $n_class = scalar @s_classes;
   ##! 129: 'LDAP ADD NODE number of structural classes $n_class.'
   for ( my $k=0 ; $k < $n_class ; $k++){
    my $attr_class = $s_classes[$k];
    $seen_object_classes{$attr_class}++;
    ##! 129: 'LDAP ADD NODE structural class $attr_class'
   }; 

   ##! 129: 'LDAP ADD NODE auxiliary classes'
   if ( ! defined $realm_config->{schema}->{$schema_profile}->{$attr_name}->{auxiliary}){
       ##! 129: 'LDAP ADD NODE no auxiliary'
   } else { 
      my @a_classes = @{$realm_config->{schema}->{$schema_profile}->{$attr_name}->{auxiliary}}; 
      my $n_class = scalar @a_classes;
      ##! 129: 'LDAP ADD NODE number of auxiliary classes $n_class'
      for ( my $k=0 ; $k < $n_class ; $k++){
       my $attr_class = $a_classes[$k];
       $seen_object_classes{$attr_class}++;
       ##! 129: 'LDAP ADD NODE auxiliary class $attr_class added to hash'
      };
   };

   ##! 129: 'LDAP ADD NODE must attributes'
   my @m_attrs = @{$realm_config->{schema}->{$schema_profile}->{$attr_name}->{must}};
   my $n_attr = scalar @m_attrs;
   
   ##! 129: 'LDAP ADD NODE number of MUST attributes detected $n_attr'
   for ( my $k=0 ; $k < $n_attr ; $k++){
    my $m_attr = $m_attrs[$k];
    if ( $seen_attributes{$m_attr} ){
        ##! 129: 'LDAP ADD NODE attribute $m_attr already processed'
        next;
    }

    ##! 129: 'LDAP ADD NODE must attribute '.$m_attr
    # check rdn first
    if ( defined $rdn_hash->{$m_attr} ) {
       push @{$add_ldap_args},  $m_attr;
       push @{$add_ldap_args},  $rdn_hash->{ $m_attr };
       ##! 129: 'LDAP ADD NODE $m_attr found in RDN'
    } else {
    
       # check all rdns processed before
       if ( defined $dn_hash->{$m_attr} ) {
          push @{$add_ldap_args},  $m_attr;
          push @{$add_ldap_args},  $dn_hash->{ $m_attr };
          ##! 129: 'LDAP ADD NODE $m_attr found in RDN processed before'
       } else {
            if ( defined $cert_extra_attrs->{$m_attr} ) {
                push @{$add_ldap_args},  $m_attr;
                push @{$add_ldap_args},  $cert_extra_attrs->{$m_attr};
                ##! 129: 'LDAP ADD NODE extra MUST attribute $m_attr added'
            } else {  
                 OpenXPKI::Exception->throw(
                 message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTIFICATEPUBLISH_ADD_DN_ATTRIBUTE_MISSING",
                 params  => {
                                'NODE DN'  => $node_dn,
			     'ATTTRIBUTE'  => $m_attr,
	         	    },
                     log => {
	                        logger => CTX('log'),
		              priority => 'error',
		   	      facility => 'monitor',
		            },
	         );

            }; 
       };
    };
    # keep in mind this attribute
    $seen_attributes{$m_attr}++;   
   };

   ##! 129: 'LDAP ADD NODE may attributes'
   if ( ! defined $realm_config->{schema}->{$schema_profile}->{$attr_name}->{may}){
    ##! 129: 'LDAP ADD NODE may attributes not detected'
   }
   else {
       my @may_attrs = @{$realm_config->{schema}->{$schema_profile}->{$attr_name}->{may}}; 
       my $n_attr = scalar @may_attrs; 
       ##! 129: 'LDAP ADD NODE detected $n_attr MAY attributes'
       for ( my $k=0 ; $k < $n_attr ; $k++){
        my $may_attr = $may_attrs[$k]; 

        if ( $seen_attributes{$may_attr} ){
          ##! 129: 'LDAP ADD NODE attribute already processed '.$m_attr
          next;
        };

        ##! 129: 'LDAP ADD NODE processing attribute '.$may_attr
	# check rdn first
	if ( defined $rdn_hash->{$may_attr} ) {
	    push @{$add_ldap_args},  $may_attr;
	    push @{$add_ldap_args},  $rdn_hash->{ $may_attr };
	} else {
	     # check rdns processed before
             if ( defined $dn_hash->{$may_attr} ) {
	        push @{$add_ldap_args},  $may_attr;
	        push @{$add_ldap_args},  $dn_hash->{ $may_attr };
             } else {
	          # check extra hash - sn,mail,serialNumber
                  if ( defined $cert_extra_attrs->{$may_attr} ) {
                       push @{$add_ldap_args},  $may_attr;
                       push @{$add_ldap_args},  $cert_extra_attrs->{$may_attr};
                  };
	     };	  
	};
	# keep in mind this attribute
        $seen_attributes{$may_attr}++;   
       };  
   };
  };
  ##! 129: 'LDAP ADD NODE all attributes have been processed' 
  push @{$add_ldap_args}, 'objectclass';
  push @{$add_ldap_args}, [ keys %seen_object_classes ];
  if( $i < $n_dns-2 ){
       ##! 129: 'LDAP ADD NODE trying to add a node to $node_dn'
       $self->__add_node( $node_dn,$add_ldap_args,$ldap);
  }; 
 };

$ldap->unbind;  
##! 129: 'LDAP ADD NODE ldap connection closed'
return 1;
}

sub __add_node {
    my $self            = shift;
    my $cert_dn         = shift;
    my $attr_array      = shift;
    my $ldap_connection = shift;

    my $result = $ldap_connection->add( $cert_dn, attr => $attr_array );
    if ( ! $result->code ) {
        ##! 129: 'LDAP ADD NODE entry $cert_dn added SUCCESSFULLY' 
    }
    else {
        ##! 129: 'LDAP ADD NODE adding entry $cert_dn FAILED $result->error'
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CERTLDAPPUBLISH_ADDMISSING_NODE_ADD_FAILED',
            params  => {
                ATTRIBUTES => Dumper $attr_array,
                DN         => $cert_dn,
                ERROR      => $result->error,
            }
        );
    }
    return 1;
}

sub __push_to_hash {
    my $self = shift;
    my $attr_hash = $_[0];
    my $attribute_name = lc $_[1];
    my $attribute_value = $_[2];
    if (exists $attr_hash->{lc $attribute_name}) {
       ##! 129: 'LDAP ADD NODE attribute $attribute_name exists in hash'
       if ( ref($attr_hash->{$attribute_name}) eq 'ARRAY') {
            push @{$attr_hash->{$attribute_name}} , $attribute_value;
       } else {
            $attr_hash->{$attribute_name} = [
	                                     $attr_hash->{$attribute_name},
                           		     $attribute_value,
					    ],
       };
    } else {
         $attr_hash->{$attribute_name} = $attribute_value;             
    };   
 return 1;
} 

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CertLdapPublish::AddMissingNode

=head1 Description

This activity adds missing LDAP nodes to prepaire adding a certificate. 
Object classes and attributes for nodes are selected from realm schema
specified in ldappublic.xml. Last RDN attributes are used to find schema
entry. Restrictions of the current version (in comparison with OpenCA):

=over

=item Multiple LDAP suffixes are not supported at the moment 

=item No suffix check implemented yet

=item No CN evaluation from e-mail implemeted yet

=item Artificial SN 'NOT SUBSTITUTED YET' is used if required

=item Alternative Name Attribute DirName is not used as DN even if present

=item No TLS

=back

That means DC-style and OU-style certificates cannot be published
simultaneously in one realm - their DNs have different suffixes.

=head2 Context parameters

Expects the following context parameters:

=over

=item cert_mail

Comma separated E-mail addresses or empty

=item cert_serial

Serial number of the certificate 

=item cert_subject

Certificate subject 

=back

=head1 Functions

=head2 execute

Executes the action.

## OpenXPKI::LdapUtils
## Largerly based on code of the OpenCA project 2004
## Rewritten 2007 by Petr Grigoriev for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project
package OpenXPKI::LdapUtils;


use strict;
use warnings;
use English;
use OpenXPKI::Debug 'OpenXPKI::LdapUtils';
use OpenXPKI::Exception;
use OpenXPKI::DN;
use Data::Dumper;
use utf8;

use Net::LDAP;
use Net::LDAP::Util qw( ldap_error_text
		        ldap_error_name
		        ldap_error_desc
		    );

sub new
{
   my $that = shift;
    my $class = ref($that) || $that;
    my $self = {
		 'ldap'       => undef,
		 'ldap_error' => undef,	
	       };
    bless $self, $class;
    return $self;
}

sub reset_error
{
    my $self         = shift;

    $self -> {'ldap_error'}= undef;	
    return 1;
}


sub ldap_connect {
    my $self         = shift;
    my $realm_config = shift;

    ##! 129: 'LDAP UTILS ldap_connect - getting parameters'
    if ( !defined $realm_config  ) {
	$self->__set_nonldap_error(
			    'NO REALM CONFIG PASSED',
			    'LDAP_CONNECT',
			    'READING_PARAMETERS',
	);
	return undef;
    };

    ##! 129: 'LDAP UTILS connecting to LDAP server'
    my $ldap_passwd  = $realm_config->{ldap_password};
    my $ldap_user    = $realm_config->{ldap_login};
    my $ldap_server  = $realm_config->{ldap_server};
    my $ldap_port    = $realm_config->{ldap_port};
    my $ldap_version = $realm_config->{ldap_version};
    my $ldap_tls     = $realm_config->{ldap_tls};
    my $ldap_sasl    = $realm_config->{ldap_sasl};
    my $ldap_sasl_mech    = '';
    my $ldap_client_cert  = '';
    my $ldap_client_key   = '';
    my $ldap_ca_cert      = '';

    if( $ldap_tls  eq 'yes' ){
        $ldap_client_cert = $realm_config->{ldap_client_cert};
        $ldap_client_key  = $realm_config->{ldap_client_key};
        $ldap_ca_cert     = $realm_config->{ldap_ca_cert};
    };

    my $sasl = undef;
    if( $ldap_sasl  eq 'yes' ){
        ##! 129: 'LDAP UTILS creating sasl object'
        $ldap_sasl_mech   = $realm_config->{ldap_sasl_mech};

        eval "use Authen::SASL qw( Perl );";
        if ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_LDAPUTILS_AUTHEN_SASL_USE_FAILED',
                params  => {
                    'ERROR' => $EVAL_ERROR,
                },
            );
        }
        if( $ldap_sasl_mech  eq 'EXTERNAL' ){
                $sasl = Authen::SASL->new(
                                          mechanism => 'EXTERNAL',
                                           callback => {
	                                                user => "",
                                           },
                        );
        } else {
                $sasl = Authen::SASL->new(
                                          mechanism => $ldap_sasl_mech,
                                           callback => {
	                                                user => $ldap_user,
							pass => $ldap_passwd,
                                           },
                        );
        };
        if ( !defined $sasl )  {
	    $self->__set_nonldap_error(
	    			'CREATE SASL OBJECT FAILED, MECH: ' .
			                         $ldap_sasl_mech,
				'LDAP_CONNECT',
				'SASL_NEW_FAILED',
	    );
    	    ##! 129: 'LDAP UTILS create sasl object FAILED'
	    return undef;
        };																
        ##! 129: 'LDAP UTILS sasl object created OK'
    };

    my $ldap = Net::LDAP->new(
                              "$ldap_server",
            		      port => $ldap_port,
                          );
    if ( !defined $ldap) {
	    $self->__set_nonldap_error(
	    			'LDAP NEW FAILED, ' .
				         'SERVER: ' .  $ldap_server .
					  ' PORT: ' .  $ldap_port,
				'LDAP_CONNECT',
				'LDAP_NEW_FAILED',
	    );
    	    ##! 129: 'LDAP UTILS create LDAP object FAILED'
	    return undef;
    };																
    ##! 129: 'LDAP UTILS connected to LDAP server OK'

    if( $ldap_tls  eq 'yes' ){
        ##! 129: 'LDAP UTILS statrting TLS'

        my $tlsmsg = $ldap->start_tls( verify => 'require',
                                   clientcert => $ldap_client_cert,
                                    clientkey => $ldap_client_key,
                                       cafile => $ldap_ca_cert,
                     );
        if ( defined $self->__checkset_ldap_error(
	                                        $tlsmsg,
				                'LDAP_CONNECT',
				                'START_TLS' ) ) {
            ##! 129: 'LDAP UTILS start TLS OK'
        } else {
            ##! 129: 'LDAP UTILS start TLS FAILED'
	    return undef;	
	};
    };       # the end of START TLS block

    ##! 129: 'LDAP UTILS binding to LDAP'
    if( $ldap_sasl  eq 'yes' ){
        ##! 129: 'LDAP UTILS statrting SASL authentication'
        my $bindmsg = $ldap->bind(   "",
	                               sasl=> $sasl,
				    version=> $ldap_version,
				 );
				
        if ( defined $self->__checkset_ldap_error(
	                        $bindmsg,
				'LDAP_CONNECT',
				'SASL_BIND') ) {
	    ##! 129: 'LDAP UTILS sasl bind OK'
        } else {
	    ##! 129: 'LDAP UTILS sasl bind FAILED'
	    return undef;	
	};
    } else {
        ##! 129: 'LDAP UTILS starting authentication without sasl'
        my $bindmsg = $ldap->bind (              "$ldap_user",
                                   password => "$ldap_passwd",
                                    version => "$ldap_version",
         	                  );
        if ( defined $self->__checkset_ldap_error(
	                                        $bindmsg,
			                        'LDAP_CONNECT',
			                        'BIND') ) {
	    ##! 129: 'LDAP UTILS bind without sasl OK'
        } else {
	    ##! 129: 'LDAP UTILS bind without sasl FAILED'
	    return undef;	
	};
    };      # the end of BIND block


    $self->{'ldap'} = $ldap;

    return $ldap;
}

sub ldap_disconnect
{
    my $self   = shift;
    my $ldap = shift;
    $ldap->unbind();
    $self->{'ldap'} = undef;
    return 1;
}


sub get_suffix
{
   my $self     = shift;
    my $cert_dn  = shift;
    my $suffixes = shift;

    # detection flag
    my $flag     = undef;

    foreach my $suffix (@{$suffixes}){
	$flag = $self->__check_suffix($cert_dn,$suffix);
	if ( defined $flag) {
	    ##! 129: 'LDAP UTILS get suffix  --- '. $suffix
	    return $suffix;
	};
    };
    $self->__set_nonldap_error(
        	'NO SUFFIX DETECTED FOR DN ' .
				     $cert_dn,
				 'GET_SUFFIX',
				      'MATCH',
    );
    return undef;
    ##! 129: 'LDAP UTILS get suffix  ---  NOT FOUND'
}

sub get_ldap_node_attributes
{
    my $self             = shift;
    my $schema           = shift;
    my $cert_extra_attrs = shift;
    my $dn_hash          = shift;
    my $rdn_parsed        = shift;

  my $n_as =  scalar @{$rdn_parsed};
  ##! 129: 'LDAP UTILS found attributes: '. $n_as

  # hash for already processed attributes of the current RDN
  my %seen_object_classes = ();
  my %seen_attributes = ();

  # hash of attributes detected in the current RDN
  my $rdn_hash = { };

  # array for ldap->add arguments (attributes and objectClasses)
  my $add_ldap_args = [ ];

  ##! 129: 'LDAP UTILS store attributes'
  for ( my $j=0 ; $j < $n_as ; $j++){
   my $attr_name  = $rdn_parsed->[$j]->[0];
   my $attr_value = $rdn_parsed->[$j]->[1];
   $self->__push_to_hash( $rdn_hash, $attr_name, $attr_value );
   $self->__push_to_hash(  $dn_hash, $attr_name, $attr_value );
  };

  ##! 129: 'LDAP UTILS process attributes using realm SCHEMA'
  for ( my $j=0 ; $j < $n_as ; $j++){
   my $attr_name  = $rdn_parsed->[$j]->[0];
   my $attr_value = $rdn_parsed->[$j]->[1];
   ##! 129: 'LDAP UTILS attribute '. $attr_name .' = '. $attr_value

   $attr_name= lc $attr_name;

   if ( !defined $schema->{$attr_name} ){
	$self->__set_nonldap_error(
        	'NO ENTRY IN SCHEMA FOR ATTRIBUTE ' .
				    	  $attr_name,
			  'GET_LDAP_NODE_ATTRIBUTES',
				      'MATCH_SCHEMA',
        );
        return undef;
   };

   ##! 129: 'LDAP UTILS structural classes'
   my @s_classes = @{$schema->{$attr_name}->{'structural'}};
   my $n_class = scalar @s_classes;
   ##! 129: 'LDAP UTILS number of structural classes ' . $n_class
   for ( my $k=0 ; $k < $n_class ; $k++){
    my $attr_class = $s_classes[$k];
    $seen_object_classes{$attr_class}++;
    ##! 129: 'LDAP UTILS structural class ' . $attr_class
   };

   ##! 129: 'LDAP UTILS auxiliary classes'
   if ( !defined $schema->{$attr_name}->{'auxiliary'}){
       ##! 129: 'LDAP UTILS no auxiliary'
   } else {
      my @a_classes = @{$schema->{$attr_name}->{'auxiliary'}};
      my $n_class = scalar @a_classes;
      ##! 129: 'LDAP UTILS number of auxiliary classes ' . $n_class
      for ( my $k=0 ; $k < $n_class ; $k++){
       my $attr_class = $a_classes[$k];
       $seen_object_classes{$attr_class}++;
       ##! 129: 'LDAP UTILS auxiliary class ' . $attr_class . ' added to hash'
      };
   };

   ##! 129: 'LDAP UTILS must attributes'
   my @m_attrs = @{$schema->{$attr_name}->{'must'}};
   my $n_attr = scalar @m_attrs;

   ##! 129: 'LDAP UTILS number of MUST attributes detected ' . $n_attr
   for ( my $k=0 ; $k < $n_attr ; $k++){
    my $m_attr = $m_attrs[$k];
    if ( $seen_attributes{$m_attr} ){
        ##! 129: 'LDAP UTILS attribute ' . $m_attr . ' already processed'
        next;
    }

    ##! 129: 'LDAP UTILS must attribute ' . $m_attr
    # check rdn first
    if ( defined $rdn_hash->{$m_attr} ) {
       push @{$add_ldap_args},  $m_attr;
       push @{$add_ldap_args},  $rdn_hash->{ $m_attr };
       ##! 129: 'LDAP UTILS ' . $m_attr . ' found in RDN'
    } else {

       # check all rdns processed before
       if ( defined $dn_hash->{$m_attr} ) {
          push @{$add_ldap_args},  $m_attr;
          push @{$add_ldap_args},  $dn_hash->{ $m_attr };
          ##! 129: 'LDAP UTILS ' . $m_attr . ' found in RDN processed before'
       } else {
            if ( defined $cert_extra_attrs->{$m_attr} ) {
                push @{$add_ldap_args},  $m_attr;
                push @{$add_ldap_args},  $cert_extra_attrs->{$m_attr};
                ##! 129: 'LDAP UTILS extra MUST attribute ' . $m_attr . ' added'
            } else {
		    $self->__set_nonldap_error(
        	    		'MUST ATTRIBUTE ' .
				          $m_attr .
			            ' IS MISSING ',
		        'GET_LDAP_NODE_ATTRIBUTES',
				     'SEARCH_MUST',
		    );
                    ##! 129: 'LDAP UTILS attribute ' . $m_attr . ' not found'
     ##! 129: 'I18N_OPENXPKI_LDAP_UTILS_GET_LDAP_NODE_ATTRIBUTES_SEARCH_MUST'
		    return undef;
            };
       };
    };
    # keep in mind this attribute
    $seen_attributes{$m_attr}++;
   };

   ##! 129: 'LDAP UTILS may attributes'
   if ( !defined $schema->{$attr_name}->{'may'}){
    ##! 129: 'LDAP UTILS may attributes not detected'
   }
   else {
       my @may_attrs = @{$schema->{$attr_name}->{'may'}};
       my $n_attr = scalar @may_attrs;
       ##! 129: 'LDAP UTILS detected '.  $n_attr . ' MAY attributes'
       for ( my $k=0 ; $k < $n_attr ; $k++){
        my $may_attr = $may_attrs[$k];

        if ( $seen_attributes{$may_attr} ){
          ##! 129: 'LDAP UTILS attribute already processed ' . $may_attr
          next;
        };

        ##! 129: 'LDAP UTILS processing attribute ' . $may_attr
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
                       push @{$add_ldap_args},  $cert_extra_attrs->
		                                    {$may_attr};
                  };
	     };	
	};
	# keep in mind this attribute
        $seen_attributes{$may_attr}++;
       };
   };
  };
  ##! 129: 'LDAP UTILS all attributes have been processed'
  push @{$add_ldap_args}, 'objectclass';
  push @{$add_ldap_args}, [ keys %seen_object_classes ];

  return  @{$add_ldap_args};
}


sub add_branch
{
 my $self             = shift;
 my $ldap             = shift;
 my $schema           = shift;
 my $cert_dn          = shift;
 my $ldap_suffix      = shift;
 my $last_profile     = shift;
 my $cert_extra_attrs = shift;

 ##! 129: 'LDAP UTILS add branch, cert_dn: ' . $cert_dn 
 ##! 129: 'LDAP UTILS add branch,  suffix: ' . $ldap_suffix 
 ##! 129: 'LDAP UTILS add branch, last profile: ' .  $last_profile

 # hash of attributes detected in the current RDN
 my $rdn_hash = { };

 my $suffix_parser = OpenXPKI::DN->new($ldap_suffix);
 my $suffix_parsed = scalar $suffix_parser->get_parsed();
 my $suffix_length = scalar $suffix_parsed;


 ##! 129: 'LDAP UTILS add branch -  parsing cert dn ' . $cert_dn
 my $dn_parser = OpenXPKI::DN->new($cert_dn);
 my @rdns      = $dn_parser->get_rdns();
 my %rdn_hash  = $dn_parser->get_hashed_content();
 my @dn_parsed = $dn_parser->get_parsed();

 # number of RDNS
 my $n_dns = scalar @dn_parsed;
 ##! 129: 'LDAP UTILS add branch found ' . $n_dns . ' nodes in DN'

 # setting the schema for nodes to be added
 my $schema_profile='default';

 # here we store already processed attributes
 my $dn_hash= { };

 my $existing_depth = get_existing_path( $self,
                        $ldap,
                        $cert_dn,
                        $n_dns - $suffix_length + 1,
                      );

 ##! 129: 'Exists at depth ' . $existing_depth
 my @dns = $self->__get_sub_paths(
             $cert_dn,
             $n_dns - $suffix_length + 1,
           );


 ##! 129: 'LDAP UTILS Starting processing all the rdns'
 my $nodes_added = 0;
 for( my $i= $n_dns - $suffix_length-1 ; $i > -1 ; $i--) {
    # DN for the current node
    my $node_dn = $dns[$i];
    ##! 129: 'LDAP UTILS add branch -  parsing RDN ' . $node_dn
    if ( $i == 0 ){
    # we are going to add an crypto object to this node and
    # so we use a different set of attributes and object classes
    ##! 129: 'LDAP UTILS add branch -  last node'
	$schema_profile = $last_profile;
    };

    my $n_as =  scalar @{$dn_parsed[$i]};
    ##! 129: 'LDAP UTILS add branch -  found attributes: '. $n_as
    ##! 129: 'LDAP UTILS process attributes using realm SCHEMA'
    if( $i < ($existing_depth-1) ){
	# array for ldap->add arguments (attributes and objectClasses)
        my @add_ldap_args =
    		get_ldap_node_attributes(
            	    $self,
                    $schema->{$schema_profile},
                    $cert_extra_attrs,
                    $dn_hash,
                    $dn_parsed[$i],
                );
        ##! 129: 'LDAP UTILS trying to add a node to' . $node_dn
        if( !add_node($self, $ldap, $node_dn, \@add_ldap_args) ) {
    	    return $nodes_added;
        } else {
    	    $nodes_added++;
        };
    };
 };
 return $nodes_added;
}


sub get_existing_path
{
    my $self        = shift;
    my $ldap        = shift;
    my $dn_to_check = shift;
    my $depth       = shift;

    my $dn_existing = $dn_to_check;
    my @dn_list     = $self->__get_sub_paths($dn_to_check, $depth);
    if ( scalar @dn_list){
	my $index=1;
	foreach my $dn ( @dn_list ){
    	    ##! 129: 'LDAP UTILS get existing path, checking ' . $dn
    	    if ( $self->check_node( $ldap, $dn) ){
		return $index;
	    } else {
		$index++;
	    };
	};
        return 0;
    } else {
	$self->__set_nonldap_error(
        	    	      'CANNOT REDUCE DN ' .
				     $dn_to_check .
			             ' TO DEPTH ' .	
				            $depth,
		               'GET_EXISTING_PATH',
				     'MAKING_LIST',
		    );

	return -1;
    };	
}

sub check_node
{
    my $self = shift;
    my $ldap = shift;
    my $dn   = shift;

    my $result = $ldap->search(   base  => $dn,
                                scope   => 'base',
                	         filter => 'objectclass=*',	
			          attrs => ['1.1']
        		);
    my $done = $self->__checkset_ldap_error(
                      $result,
                 'CHECK_NODE',
                     'SIMPLE',
               );
    if ( $done ) {
	##! 129: 'LDAP UTILS CHECK NODE node EXISTS'
	return 1;
    } else {
        ##! 129: 'LDAP UTILS CHECK NODE node NOT FOUND'
	return 0;
    };
}


sub add_node
{
    my $self       = shift;
    my $ldap       = shift;
    my $dn         = shift;
    my $attr_array = shift;

    my $result = $ldap->add( $dn, attrs => $attr_array );

    my $done = $self->__checkset_ldap_error( $result,'ADD_NODE','SIMPLE');

    if ( $done ) {
	  ##! 129: 'LDAP UTILS ADD NODE entry ' . $dn . ' added successfully'
          return 1;
    } else {
	  ##! 129: 'LDAP UTILS ADD NODE adding entry ' . $dn . ' failed'
        return 0;
    };
}
				
sub delete_node
{
    my $self = shift;
    my $ldap = shift;
    my $dn   = shift;

    my $result = $ldap->delete( $dn );
    my $done = $self->__checkset_ldap_error(
                      $result,
                'DELETE_NODE',
                     'SIMPLE',
               );
    if ( $done ) {
       ##! 129: 'LDAP UTILS entry ' . $dn . ' deleted successfully'
       return 1;
    } else {
       ##! 129: 'LDAP UTILS deleting node ' . $dn . ' failed'
       return 0;
    };
}

###################################################################
# PRIVATE METHODS
#
#

sub __get_sub_paths
{
    my $self  = shift;
    my $dn    = shift;
    my $depth = shift;



    my @dn_list  = ( $dn );

    while ( $depth > 1 ) {
	if ( $dn =~ m/.*[^\\],.*/  ) {
    	     $dn =~ s/^.*?[^\\],//;
	     push @dn_list, $dn;
	     $depth--;
	} else {
	    return ();
	};
    };
    return @dn_list;
}

sub __set_nonldap_error
{
    my $self   = shift;
    my $msg    = shift;
    my $method = shift;
    my $action = shift;

    $self->{ldap_error} = {
				"ACTION"  =>
			           'I18N_OPENXPKI_LDAPUTILS_' .
    			           $method . "_" . $action,
			    	  "CODE"  => '',
    			          "ERROR" => '',
    	                    	  "NAME"  => '',
                    	          "TEXT"  => $msg,
                	    "DESCRIPTION" => '',
                           };
    return 1;

#  i18n TAGS for pot file (error types)
# 'I18N_OPENXPKI_LDAPUTILS_ADD_NODE_SIMPLE'
# 'I18N_OPENXPKI_LDAPUTILS_DELETE_NODE_SIMPLE'
# 'I18N_OPENXPKI_LDAPUTILS_CHECK_NODE_SIMPLE'
# 'I18N_OPENXPKI_LDAPUTILS_GET_LDAP_NODE_ATTRIBUTES_SEARCH_MUST'
# 'I18N_OPENXPKI_LDAPUTILS_GET_LDAP_NODE_ATTRIBUTES_MATCH_SCHEMA'
# 'I18N_OPENXPKI_LDAPUTILS_GET_EXISTING_PATH_MAKING_LIST'
# 'I18N_OPENXPKI_LDAPUTILS_GET_SUFFIX_MATCH'
# 'I18N_OPENXPKI_LDAPUTILS_LDAP_CONNECT_LDAP_NEW_FAILED'
# 'I18N_OPENXPKI_LDAPUTILS_LDAP_CONNECT_SASL_NEW_FAILED'
# 'I18N_OPENXPKI_LDAPUTILS_LDAP_CONNECT_READING_PARAMETERS'
}

sub __checkset_ldap_error
{
    my $self   = shift;
    my $msg    = shift;
    my $method = shift;
    my $action = shift;

    if ( $msg->is_error()) {
         $self->{ldap_error} = {
				"ACTION"  =>
			           'I18N_OPENXPKI_LDAPUTILS_' .
    			           $method . "_" . $action,
			    	  "CODE"  => $msg->code(),
    			          "ERROR" => $msg->error(),
    	                    	  "NAME"  => ldap_error_name($msg),
                    	          "TEXT"  => ldap_error_text($msg),
                	    "DESCRIPTION" => ldap_error_desc($msg),
                           };
	  return undef;				
    } else {
	  $self->{ldap_error} = undef;
	  return 1;
    };
}


sub __check_suffix
{
my $self    = shift;
my $cert_dn = shift;
my $suffix  = shift;
my $cis_attr={'dc'=>1,'mail'=>1};

##! 129: 'LDAP UTILS check suffix      dn: ' . $cert_dn
##! 129: 'LDAP UTILS check suffix  suffix: ' . $suffix

my $dn_parser = OpenXPKI::DN->new($cert_dn);
my $sf_parser = OpenXPKI::DN->new($suffix);

my @dn_parsed = reverse $dn_parser->get_parsed();
my @sf_parsed = reverse $sf_parser->get_parsed();


my $n_rdns_dn = scalar @dn_parsed;
my $n_rdns_sf = scalar @sf_parsed;

##! 129: 'LDAP UTILS parsing - found ' . $n_rdns_dn . ' rdns in dn'
##! 129: 'LDAP UTILS parsing - found ' . $n_rdns_sf . ' rdns in suffix'

if ( $n_rdns_dn > $n_rdns_sf){
   for ( my $i = 0; $i < $n_rdns_sf; $i++){
       my $n_as_dn  =  scalar @{$dn_parsed[$i]};
       my $n_as_sf  =  scalar @{$sf_parsed[$i]};
       #! 129: 'LDAP UTILS parsing dn  # ' . $i . ' got '. $n_as_dn .' attribs'
       #! 129: 'LDAP UTILS parsing suf # ' . $i . ' got '. $n_as_sf .' attribs'
       if ( $n_as_dn == $n_as_sf){
          for ( my $j=0 ; $j < $n_as_sf ; $j++){
              my $attr_name_dn  =  $dn_parsed[$i][$j]->[0];
              my $attr_name_sf  =  $sf_parsed[$i][$j]->[0];
	      $attr_name_dn = lc $attr_name_dn;
	      $attr_name_sf = lc $attr_name_sf;
              if ( $attr_name_dn eq $attr_name_sf){
                 ##! 129: 'LDAP UTILS attribute ' . $attr_name_sf
                 my $attr_value_dn = $dn_parsed[$i][$j]->[1];
                 my $attr_value_sf = $sf_parsed[$i][$j]->[1];
                 if ( exists $cis_attr->{$attr_name_dn} ){
         ##! 129: 'LDAP UTILS lc-ing '. $attr_value_sf . ' ' . $attr_value_dn
		     $attr_value_dn = lc  $attr_value_dn;
		     $attr_value_sf = lc  $attr_value_sf;
                 };
		 if ( $attr_value_dn eq $attr_value_sf){
		    next;
		 } else {         		
         ##! 129: 'LDAP UTILS ' . $attr_value_dn . ' !match ' . $attr_value_sf
                      return undef;
		 };
              } else {
         ##! 129: 'LDAP UTILS ' . $attr_name_dn .' !match '. $attr_name_sf
                   return undef;
              };
          };
       } else {
         ##! 129: 'LDAP UTILS attr numbers ' . $n_as_dn . ' ne '. $n_as_sf
            return undef;
       };
   };
} else {
     ##! 129: 'LDAP UTILS rdn numbers '. $n_rdns_dn .' le ' . $n_rdns_sf
 return undef;
};
##! 129: 'LDAP UTILS suffix match'
return 1;
}

sub __push_to_hash {
    my $self = shift;
    my $attr_hash = $_[0];
    my $attribute_name = lc $_[1];
    my $attribute_value = $_[2];

    if (exists $attr_hash->{$attribute_name}) {
       ##! 129: 'LDAP UTILS attribute ' .  $attribute_name . ' exists in hash'
       if ( ref($attr_hash->{$attribute_name}) eq 'ARRAY') {
            push @{$attr_hash->{$attribute_name}} , $attribute_value;
       } else {
            $attr_hash->
	       {$attribute_name} = [ $attr_hash->
	                                {$attribute_name},
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

=head1 NAME

OpenXPKI::LdapUtils - LDAP utilities

=head1 DESCRIPTION

This module was designed to provide LDAP interface
for managing certificate and CRL publishing.

=head1 INITIALIZATION

No special initialization is required.

=head2 new

This is a static function which requires no parameters.
An example of using this function:

    my $utils=OpenXPKI::LdapUtils->new();

After  the instance is created  tags 'ldap' and
'ldap_error' can be used to access the connected ldap handle
and error information hash:

    $self->{'ldap_error'} = {
	'ACTION' => 'Here one can find info on function and action failed',
	  'CODE' => 'Here we store returned by Net::LDAP error code',
	 'ERROR' => 'Here we store returned by Net::LDAP error',
	  'NAME' => 'Here we store returned by Net::LDAP error name',
	  'TEXT' => 'Here we store returned by Net::LDAP error text 
                     or non LDAP error comments',
   'DESCRIPTION' => 'Here we store returned by Net::LDAP error description',
 };

=head1 ERROR HANDLING FUNCTIONS

=head2 reset_error 

This is a static function which requires no parameters.
Use it to clear up the error information hash before
asking LdapUtils to do something. 

An example of using this function:

    my $utils=OpenXPKI::LdapUtils->new();
    my $pki_realm = CTX('api')->get_pki_realm();
    my $realm_config = 
	CTX('pki_realm_by_cfg')->{$self->{CONFIG_ID}}->{$pki_realm};
    my $ldap = $utils->ldap_connect($realm_config);

    $utils->reset_error;

    $utils->check_node( $ldap, '=cn=A,dc=B,dc=C' );
    my $error_hash = $utils->{'ldap_error'}; 
    if( defined $error_hash ) {
        # 'Looks like the DN is bad'
    );

=head1 CONNECTION HANDLING FUNCTIONS

=head2 ldap_connect

This is a static function which requires a reference to
the ldap configuration section of OpenXPKI realm.
The function performs connection and binds to LDAP server
using the realm configuration (server name, port, etc.). 
Function does not try to check whether SASL mechanism 
and START_TLS are supported by the server.
It returns a ready to use Net::LDAP handle.
In the case of errors the ldap_error hash is filled with the
information describing the stage that fails and the reason. 
In such a case the function returns undef.

An example of using this function:

    my $utils=OpenXPKI::LdapUtils->new();
    my $pki_realm = CTX('api')->get_pki_realm();
    my $realm_config = 
	CTX('pki_realm_by_cfg')->{$self->{CONFIG_ID}}->{$pki_realm};
    my $ldap = $utils->ldap_connect($realm_config);
    if( !defined $ldap){
	# Something is going wrong, check $utils->{'ldap_error'} hash
	# to find the reason.
    }

The function does not use suffixes stored in realm.
To use LDAP database with several suffixes one should
preset the proper value of 

    $realm_config->{ldap_login}

or (if binding via sasl and TLS) the proper

     $realm_config->{ldap_client_cert}

and

     $realm_config->{ldap_client_key}

to tell LDAP server what database should be used for bind.
The rigth way is to use realm configuration as a template and
reset bind credentials after the database is determined
to which it is necessary to bind (e.g. by extracting the LDAP
suffix from the certificate DN).

=head2 ldap_disconnect

This is a static function which requires no arguments.
Call it to finish communication with the LDAP database.
The function calls B<unbind> method of Net::LDAP and
switches the previously created by ldap_connect 
handle into B<undef> state.

=head1 ADDING NODE FUNCTIONS

=head2 get_suffix

This is a static function which requires a DN-string to be
compared to suffixes and a reference to an array of 
supported suffixes ( e.g. @{$realm_config->{ldap_suffix}} ).
The function makes a search through the suffixes list
trying to match the suffixes the 'tail' of the given DN.
It returns the first matching suffix or
fills the 'ldap_error' hash if no matching suffixes were found
and returns undef.

An example of using this function:

 my $suffixes = [ 
		    'dc=openxpki,dc=org',
		    'dc=openxpki,c=DE', 
		    'dc=openxpki,c=RU',
		];
 my $utils = OpenXPKI::LdapUtils->new();
 my $suffix = 
    $utils->get_suffix(
	'cn=John,ou=IT,ou=Security,o=University,dc=openxpki,dc=org',
	$suffixes,
    );
 #
 # $suffix will be set to 'dc=openxpki,dc=org'
 #


=head2 get_ldap_node_attributes

This is a static function which requires a reference to
the schema which will be used to create a node,
a reference to the hash of additional attributes,
which may be useful to satisfy the objectclasses requirements,
a reference to the hash of previously added attributes
(the function will try to find required attribute values
in that hash too) and a reference to the array of
the node attributes defined in RDN.
Hashe values are strings or array references
(the last is for multivalued attributes).
Schema is the proper subtree of the realm configuration structure.

The function checks if all the attributes required by
the schema are defined and puhes their values to the array
which may be used to add a node to LDAP tree.
The function returns that array if all requirements are
satisfied. Otherwise it returns undef and sets the parameters
of ldap_error specifying the stage that failed to be completed.

An example of using this function:

    my $pki_realm = CTX('api')->get_pki_realm();
    my $realm_config = 
	CTX('pki_realm_by_cfg')->{$self->{CONFIG_ID}}->{$pki_realm};
    my $schema_profile='certificate';
    my $schema = $realm_config->{schema}->{$schema_profile};

    my $cert_extra_attrs = { 'mail' => 'max@ox.org',
                             'sn'   => 'Max'
                           };
    my $dn_hash          = { 'dc' => ['ox','org'],
                             'ou' => 'Security',
			     'o'  => 'University'
			   };
    my $rdn_parsed        = [
                              [ 'cn' ,'Max'],
                              [ 'uid','max'],
                            ];   '	
    my $utils = OpenXPKI::LdapUtils->new();
    my @add_ldap_args = $utils->get_ldap_node_attributes(
                            	    $schema,
                            	    $cert_extra_attrs,
			    	    $dn_hash,
                            	    $rdn_parsed,
                        );

    # then we can use @add_ldap_args to add a node to LDAP database

=head2 add_branch

This is a static high-level function which requires 6 parameters:
a reference to the Net::LDAP connected object,
the schema which will be used to create nodes,
DN of the last node to be created,
node suffix to exclude it from the DN,
schema profile name which will be used to create the last node and
a reference to the hash of additional attributes,
which may be useful to satisfy the objectclasses requirements,
(the function will try to find required attribute values
in that hash too).

The function adds the missing intermediate nodes using 'default'
schema of the realm configuration and then adds the last node,
using the schema profile named specified as a parameter number 5.
The function returns the number of added nodes.
It also sets the parameters of ldap_error specifying the stage
that failed to be completed.

An example of using this function in workflow activity
(no error handling in the example):

       my $pki_realm = CTX('api')->get_pki_realm();
       my $realm_config = 
	    CTX('pki_realm_by_cfg')->{$self->{CONFIG_ID}}->{$pki_realm};
       my $utils = OpenXPKI::LdapUtils->new();
       my $cert_dn = 'cn=John+uid=Bill,ou=IT,o=Factory,dc=openxpki,dc=org',
       my $cert_extra_attrs = {
				    'mail' => 'jmax@openxpki.org',
                            	    'sn'   => 'Maxwell',
                              };
       my $suffix = $utils->get_suffix(
                                $cert_dn,
                                $realm_config->{ldap_suffix},
                            );
       $ldap = $utils->ldap_connect($realm_config);
       $utils->add_branch(
	            $ldap,
                    $realm_config->{'schema'},
                    $cert_dn,
                    $suffix,
                    'certificate',
                    $cert_extra_attrs,
                );
       $utils->ldap_disconnect($ldap);


=head2 get_existing_path

This is a static function which requires a reference to
the Net::LDAP connected object, a DN-string and a "depth"
parameter specifying how far should the function go up the
LDAP-tree searching the existing node.
The function checks if all the nodes specified in the DN exist and
returns the "depth" of the last (the deepest) node in the DN path that exists.
The depth is calculated relative to the passed DN.

An example of using this function:

 my $utils = OpenXPKI::LdapUtils->new();
 my $ldap = $utils->ldap_connect($realm_config);
 my $index = $utils->get_existing_path(
                         $ldap,
                         'cn=John,ou=IT,ou=Security,' .
                             'o=University,dc=openxpki,dc=org',
                         5,
                     );

If the node 'o=University,dc=openxpki,dc=org' exists but 'ou' subtrees
are not created yet the function will return 4. If we replace the
third call parameter with '3' the function will return 0 (which
means that nothing was found at given depth). If the passed 'depth'
is larger than number of RDN in DN (more than 6 for the example at hand)
the function returns '-1'. The same value will be returned in the case
of wrong using commas in DN (they must be accompanied with a backslash
character in the case they are used in RDN).

=head2 check_node

This is a static function which requires a reference to
the Net::LDAP connected object and a DN-string.
The function checks if the node exists for the DN.
Returns 1 if the node exists and 0 otherwise.
Errors are stored in 'ldap_error' hash.

An example of using this function:

 my $utils = OpenXPKI::LdapUtils->new();
 my $ldap = $utils->ldap_connect($realm_config);
 my $result = $utils->check_node(
                          $ldap,
                          'cn=John,ou=IT,ou=Security,' .
                              'o=University,dc=openxpki,dc=org',
                      );

=head2 add_node

This is a static function which requires a reference to
the Net::LDAP connected object, a DN-string and a reference to
array of attributes for the node to be created
(it can be built using get_ldap_node_attributes function).
The function adds a node. It returns 1 if the node
is successfully created and 0 otherwise.
Errors are stored in 'ldap_error' hash.

An example of using this function:

 my $utils = OpenXPKI::LdapUtils->new();
 my $ldap = $utils->ldap_connect($realm_config);
 my $result = $utils->add_node(
                          $ldap,
                          'cn=John,ou=IT,ou=Security,' .
                              'o=University,dc=openxpki,dc=org',
                          $attributes_array,
                      );


=head2 delete_node

This is a static function which requires a reference to
the Net::LDAP connected object and  a DN-string of the node
to be deleted. The function deletes a node. It returns 1 if the node
is successfully deleted and 0 otherwise.
Errors are stored in 'ldap_error' hash.

An example of using this function:

 my $utils = OpenXPKI::LdapUtils->new();
 my $ldap = $utils->ldap_connect($realm_config);
 my $result = $utils->delete_node(
                          $ldap,
                          'cn=BadBoy,ou=IT,ou=Security,' .
                          'o=University,dc=openxpki,dc=org',
                      );



=head1 PRIVATE METHODS

=head2 __get_sub_paths

This is a static function which requires a DN string and
'depth'(a number) as parametes.
It cuts off RDNs one by one storing the reduced DNs in an array,
which is returned in the case of success. Cut off is performed as
many times as specified in the second parameter (depth).
An empty list is returned in the case of fail. 

=head2 __set_nonldap_error

This is a static function which requires 3 parameters: 
message string, LdapUtils method name and an action name.
Call the function to store the information about some error
in $self->{ldap_error} hash.

=head2 __checkset_ldap_error

This is a static function which requires a reference to
the Net::LDAP connected object and two strings: method and action.
It checks if an error happened while performing the last operation
with Net::LDAP object and returns 1 if no error detected.
Otherwise it fills 'ldap_error' hash with the error information.
Information includes I18N tag built of method and action names.

=head2 __check_suffix

This is a static function which requires a DN string and
a suffix string as parametes.
It makes a check whether the suffix matches the DN
and returns 1 in the case of match. Otherwise it returns undef.
By default B<dc> and B<mail> attributes are compared
ignoring the case. 

=head2 __push_to_hash 

This is a static function which requires 3 parameters: 
hash reference, attribute name and attribute value.
The pair name-value is added to the hash as key-value.
In the case the key is already exists the function adds the
new value forming an array if necessary. 
The function does not check existing values so two same
values can be pushed in one array.





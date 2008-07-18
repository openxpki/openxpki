## OpenXPKI::Server::Authentication::LDAP.pm 
##
## Written 2005 by Peter Gietz
## Rewritten 2006 by Michael Bell
## (C) Copyright 2003-2006 by The OpenXPKI Project

# FIXME 2007-02-06 Alexander Klink/Martin Bartosch
# This code does not support the new login_step semantics and will hence
# not work at all (was untested before the change as well). Will need
# some refactoring.
# Starting refactoring 2007-07-13 Petr Grigoriev


package OpenXPKI::Server::Authentication::LDAP;

use strict;
use warnings;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Digest::MD5;
use Digest::SHA1;

my $is_ldaps;

eval ( "use Net::LDAPS;" );
if ($@) {
    print STDERR "Error in use Net::LDAPS"; 
    $is_ldaps=0;
} else {
    $is_ldaps=1;
}

use Net::LDAP;

use Net::LDAP::Util qw(ldap_error_text
		   ldap_error_name
		   ldap_error_desc
		   );

## constructor and destructor stuff

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = shift;
    ##! 1: "start"

    my $config = CTX('xml_config');
    
    ##! 2: "load name and description for handler"
    $self->{DESC} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "description" ],
                                        COUNTER => [ @{$keys->{COUNTER}}, 0 ],
                                      CONFIG_ID => $keys->{CONFIG_ID},
    );
    $self->{NAME} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "name" ],
                                        COUNTER => [ @{$keys->{COUNTER}}, 0 ],
                                      CONFIG_ID => $keys->{CONFIG_ID},
    );



    ## load network configuration

    $self->{HOST} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "host" ],
                                        COUNTER => [ @{$keys->{COUNTER}}, 0],
                                      CONFIG_ID => $keys->{CONFIG_ID},
    );
    $self->{PORT} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "port" ],
                                        COUNTER => [ @{$keys->{COUNTER}}, 0],
                                      CONFIG_ID => $keys->{CONFIG_ID},
    );
    $self->{BASE} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "base" ],
                                        COUNTER => [ @{$keys->{COUNTER}}, 0],
                                      CONFIG_ID => $keys->{CONFIG_ID},
    );
    $self->{VERSION} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "version" ],
                                           COUNTER => [ @{$keys->{COUNTER}}, 0],
                                         CONFIG_ID => $keys->{CONFIG_ID},
    );
    $self->{BIND_DN} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "bind_dn" ],
                                           COUNTER => [ @{$keys->{COUNTER}}, 0],
                                         CONFIG_ID => $keys->{CONFIG_ID},
    );
    $self->{BIND_PW} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "bind_pw" ],
                                           COUNTER => [ @{$keys->{COUNTER}}, 0],
                                         CONFIG_ID => $keys->{CONFIG_ID},
    );
    ##! 2: "version ::= ".$self->{VERSION}
    ##! 2: "server  ::= ldap://".$self->{HOST}.":".$self->{PORT}."/".$self->{BASE}
    ##! 2: "user    ::= ".$self->{BIND_DN}

    ## check for a TLS protected connection
    ## FIXME: who checks when that TLS is supported?

    $self->{USE_TLS} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "use_tls" ],
                                           COUNTER => [ @{$keys->{COUNTER}}, 0],
                                         CONFIG_ID => $keys->{CONFIG_ID},
    );
    if( lc($self->{USE_TLS}) eq "false" ) {
	$self->{START_TLS} = 0;
	$self->{USE_LDAPS} = 0; 
    } else {
	##! 2: "use_tls ::= ".$self->{USE_TLS}
        $self->{CA_PATH} = 
	    $config->get_xpath (
		  XPATH   => [ @{$keys->{XPATH}},   "capath" ],
                  COUNTER => [ @{$keys->{COUNTER}}, 0],
                CONFIG_ID => $keys->{CONFIG_ID},
            );
	##! 4: "capath ::= ".$self->{CA_PATH}
	if( lc($self->{USE_TLS}) eq "true_ssl" ){
	    $self->{USE_LDAPS} = $is_ldaps; 
	    $self->{START_TLS} = $is_ldaps ^ 1;
	} else {
	    if( lc($self->{USE_TLS}) eq "true_tls" ){
		$self->{START_TLS} = 1;
		$self->{USE_LDAPS} = 0; 
	    } else {
    		OpenXPKI::Exception->throw(
        	    message => 
			'I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_WRONG_TLS_CONFIGURATION',
        	    params  => {
            		TLS_CONFIG => $self->{USE_TLS},
        	    },
    		);
    	    };
	};
    };	

    ## load search config

    $self->{SEARCH_ATTRIBUTE} = $config->get_xpath (
                XPATH   => [ @{$keys->{XPATH}},   "searchattr" ],
                COUNTER => [ @{$keys->{COUNTER}}, 0],
              CONFIG_ID => $keys->{CONFIG_ID},
    );
    $self->{SEARCH_VALUE_PREFIX} = $config->get_xpath (
                XPATH   => [ @{$keys->{XPATH}},   "searchvalueprefix" ],
                COUNTER => [ @{$keys->{COUNTER}}, 0],
              CONFIG_ID => $keys->{CONFIG_ID},
    );
    ##! 2: "search->attribute    ::= ".$self->{SEARCH_ATTRIBUTE}
    ##! 2: "search->value_prefix ::= ".$self->{SEARCH_VALUE_PREFIX}

    ## load authentication config

    $self->{AUTH_METH_ATTR} = $config->get_xpath (
                XPATH   => [ @{$keys->{XPATH}},   "auth_meth_attr" ],
                COUNTER => [ @{$keys->{COUNTER}}, 0],
              CONFIG_ID => $keys->{CONFIG_ID},
    );
    $self->{DEFAULT_AUTH_METHOD} = $config->get_xpath (
                XPATH   => [ @{$keys->{XPATH}},   "default_auth_meth" ],
                COUNTER => [ @{$keys->{COUNTER}}, 0],
              CONFIG_ID => $keys->{CONFIG_ID},
    );
    my $count = $config->get_xpath_count (
                XPATH   => [ @{$keys->{XPATH}},   "auth_meth_map" ],
               COUNTER  => $keys->{COUNTER},
              CONFIG_ID => $keys->{CONFIG_ID},
    );
    for (my $i=0; $i < $count; $i++)
    {
        my $condition = $config->get_xpath (
                XPATH   => [ @{$keys->{XPATH}},   "auth_meth_map", "attr_value" ],
                COUNTER => [ @{$keys->{COUNTER}}, $i, 0],
              CONFIG_ID => $keys->{CONFIG_ID},
        );
        my $method = $config->get_xpath (
                XPATH   => [ @{$keys->{XPATH}},   "auth_meth_map", "auth_meth" ],
                COUNTER => [ @{$keys->{COUNTER}}, $i, 0],
              CONFIG_ID => $keys->{CONFIG_ID},
        );
        $self->{AUTH_METHOD}->{$condition} = $method;
        ##! 4: "auth map $condition to $method"
    }
    $self->{PW_ATTR} = $config->get_xpath (
                XPATH   => [ @{$keys->{XPATH}},   "pw_attr" ],
                COUNTER => [ @{$keys->{COUNTER}}, 0],
              CONFIG_ID => $keys->{CONFIG_ID},
    );
    $self->{PW_ATTR_HASH} = $config->get_xpath (
                XPATH   => [ @{$keys->{XPATH}},   "pw_attr_hash" ],
                COUNTER => [ @{$keys->{COUNTER}}, 0],
              CONFIG_ID => $keys->{CONFIG_ID},
    );
    ##! 2: "auth->method_attr    ::= ".$self->{AUTH_METH_ATTR}
    ##! 2: "auth->default_method ::= ".$self->{DEFAULT_AUTH_METHOD}
    ##! 2: "auth->pw_attr        ::= ".$self->{PW_ATTR}
    ##! 2: "auth->pw_attr_hash   ::= ".$self->{PW_ATTR_HASH}

    ## role mapping

    $self->{ROLE_ATTR} = $config->get_xpath (
                XPATH   => [ @{$keys->{XPATH}},   "role_attr" ],
                COUNTER => [ @{$keys->{COUNTER}}, 0],
                CONFIG_ID => $keys->{CONFIG_ID},
    );
    ##! 2: "role attribute ::= ".$self->{ROLE_ATTR}
    $count = $config->get_xpath_count (
                 XPATH   => [ @{$keys->{XPATH}},   "role_map" ],
                 COUNTER => $keys->{COUNTER},
               CONFIG_ID => $keys->{CONFIG_ID},
    );
    for (my $i=0; $i < $count; $i++)
    {
        my $value = $config->get_xpath (
                        XPATH   => [ @{$keys->{XPATH}},   "role_map", "value" ],
                        COUNTER => [ @{$keys->{COUNTER}}, $i, 0 ],
                      CONFIG_ID => $keys->{CONFIG_ID},
        );
        my $role  = $config->get_xpath (
                        XPATH   => [ @{$keys->{XPATH}},   "role_map", "role" ],
                        COUNTER => [ @{$keys->{COUNTER}}, $i, 0 ],
                      CONFIG_ID => $keys->{CONFIG_ID},
        );
        $self->{ROLE_MAP}->{$value} = $role;
        ##! 4: "role map $value to $role"
    }

    return $self;
}

sub login_step {
    ##! 1: 'start' 
    my $self    = shift;
    my $arg_ref = shift;

    my $name    = $arg_ref->{HANDLER};
    my $msg     = $arg_ref->{MESSAGE};
    my $answer  = $msg->{PARAMS};

    ##! 4: 'checking login data' 
    if (! exists $msg->{PARAMS}->{LOGIN} ||
        ! exists $msg->{PARAMS}->{PASSWD}) {
        ##! 4: 'no login data received (yet)' 
        return (undef, undef,
            {
                SERVICE_MSG => "GET_PASSWD_LOGIN",
                PARAMS      => {
                    NAME        => $self->{NAME},
                    DESCRIPTION => $self->{DESC},
                },
            },
        );
    } else {      # start of auth block
    
    my ($account, $passwd) = ($answer->{LOGIN}, $answer->{PASSWD});

    ##! 2: "credentials ... present"
    ##! 2: "account ... $account"

    ## now start an LDAP connection

    my $bindmsg = undef;
    my $ldap = undef;

    if ( $self->{USE_LDAPS} )
    {  
        ##! 4: "starting a SSL (ldaps) session on"

        $ldap = Net::LDAPS->new ($self->{HOST},
                                 port    => $self->{PORT},
                                 async   => 0,
                                 version => $self->{VERSION}, 
                                 capath  => $self->{CA_PATH});
    } else {
        $ldap = Net::LDAP->new ($self->{HOST},
                                port    => $self->{PORT},
                                async   => 0,
                                version => $self->{VERSION});
    }
    if (not $ldap)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_LOGIN_CONNECTION_FAILED");
    }
    ##! 2: "connect successfull"

    ## start TLS if necessary

    my $starttls_OID = "1.3.6.1.4.1.1466.20037";
    my $is_rootdse = undef;
   
    if ($self->{START_TLS})
    {
        my $root_dse = $ldap->root_dse();
        if ($root_dse)
        {
            my @namingContext = $root_dse->get_value( 'namingContexts', 
                                                      asref => 0 );
            foreach (0..$#namingContext)
            {
                ##! 16: "naming context: $namingContext[$_]"
            }
            $is_rootdse = 1;
        } else {
            ##! 8: "root_dse unsuccessfull"
        }
        if ( $is_rootdse and 
             not $root_dse->supported_extension ($starttls_OID))
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_START_TLS_NOT_POSSIBLE",
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => 'system',
		},
		);
        }
        ##! 4: "executing start_tls ..."

        my $tlsmsg = $ldap->start_tls ( 
                         verify =>'require',
                         capath => $self->{CA_PATH});
        if ( $tlsmsg->is_error() )
        {
            # LDAP Server failed during start_tls. 
	    # Possible reason: The directory in "capath" must 
	    # contain certificates.
	    # named using the hash value of the certificates' subject names.
	    # To generate these names, use OpenSSL like this in Unix:
	    # ln -s cacert.pem `openssl x509 -hash -noout < cacert.pem`.0

            ##! 8: join ",", $self->__get_ldap_error ($tlsmsg)

            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_START_TLS_NOT_POSSIBLE",
                params  => {
		    $self->__get_ldap_error ($tlsmsg),
		},
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => 'auth',
		},
		);
        } else {
            ##! 8: "starttls successful"
        }
    } ## end of START_TLS
    
    ## now OpenXPKI authenticates itself by binding to the 
    ## entry configured in bind_dn

    $bindmsg = $ldap->bind( $self->{BIND_DN}, 
                            'password' => $self->{BIND_PW} );
    if ($bindmsg->is_error())
    {
        if ( $bindmsg->code() == 49 ) {
            ##! 8: "invalid ldap credentials"
        } else {  
            ##! 8: "LDAP bind: ", join ", ", $self->__get_ldap_error ($bindmsg)
        }

        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_BIND_FAILED",
            params  => {
		$self->__get_ldap_error($bindmsg),
	    },
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'auth',
	    },
	    );
    }
    ##! 2: "bind successful"
		
    ## now search for an entry with an ID-attribute containing 
    ## the value input by the user

    my $searchfilter = "($self->{SEARCH_ATTRIBUTE}=".
                       "$self->{SEARCH_VALUE_PREFIX}$account)";
    ##! 2: "search filter: $searchfilter"

    my $searchmesg = $ldap->search(
                         base   => $self->{BASE},
                         filter => $searchfilter);
    if ($searchmesg->is_error())
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_SEARCH_FAILED",
            params  => {
		$self->__get_ldap_error ($searchmesg)
	    },
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'auth',
	    },
	    );
    }
    my $entrycount = $searchmesg->count();
		
    ## no user found?
    if ( not $entrycount )
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_NO_USER_FOUND",
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'auth',
	    },
	    );
    }

    ## more than one user found?
    if ( $entrycount > 1 )
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_MORE_THAN_ONE_USER_FOUND",
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'auth',
	    },
	    );
    }

    ## ok lets analyse the entry found:
    my $value = undef;
    my @rolevalues = undef;
    my @ldapauthmethattrvalues = undef;
    my @ldappwattrvalues = undef;
    my $rolevaluecount = 0;
    my $ldapauthmethattrvaluecount = 0;
    my $ldappwattrvaluecount = 0;

    my $entry = $searchmesg->entry ( 0 );
    $self->{DN} = $entry->dn();
    ##! 2: "analysing entry $self->{DN}"

    foreach my $attr ( $entry->attributes )
    {
        foreach $value ( $entry->get_value( $attr ) )
        { 
            ##! 8: "attr: |$attr| = $value"
            if ( lc($attr) eq lc($self->{ROLE_ATTR}) )
            {
                ##! 16: "Roleattribute = $value"
                $rolevalues[$rolevaluecount] = $value;
                $rolevaluecount ++;
            }
            elsif ( lc($attr) eq 
                    lc($self->{AUTH_METH_ATTR}) )
            {
                ##! 16: "ldapauthmethattribute = $value"
                $ldapauthmethattrvalues[$ldapauthmethattrvaluecount] = $value;
                $ldapauthmethattrvaluecount ++;
            }
            elsif ( lc($attr) eq 
                    lc($self->{PW_ATTR}) )
            {
                ##! 16: "ldappwattribute = $value"
                $ldappwattrvalues[$ldappwattrvaluecount] = $value;
                $ldappwattrvaluecount ++;
            }
        }
    }
    ##! 2: "rolecount: $rolevaluecount;"
    ##! 2: "authmethcount: $ldapauthmethattrvaluecount;"
    ##! 2: "ldappwattrcount: $ldappwattrvaluecount"

    ## lets see which auth method to use:
    my $is_found = 0;
    my $valuekey;
    my $ldapauthmeth = undef;
    for (my $i = 0; $i < $ldapauthmethattrvaluecount; $i++)
    {
        foreach $valuekey (keys %{$self->{AUTH_METHOD}})
        {
            if ( $valuekey eq $ldapauthmethattrvalues[$i] )
            {
                $is_found = 1;
                $ldapauthmeth = $self->{AUTH_METHOD}->{$valuekey};
                last;
            }
        }
        last if ($is_found );
    }
    if ($is_found) {
        ##! 4: "Found auth meth"
        if ($ldapauthmeth eq "pwattr" and not $ldappwattrvaluecount )
        {
            # Error no value of ldap pw attribute 
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_MISSING_PW_ATTR_IN_ENTRY",
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => 'auth',
		},
		);
        }
    } else {
        $ldapauthmeth = $self->{DEFAULT_AUTH_METHOD};
    }
    ##! 2: "ldapauthmeth: $ldapauthmeth"
		
    ## Method pwattr 
    ## (use a configurable password attribute for authentication)
    if ( $ldapauthmeth eq "pwattr" )
    {
        my $algorithm = undef;
        my $digest = undef;

        my $ldapdigest = $ldappwattrvalues[0];

        ##! 4: "ldapdigest : |$ldapdigest| "

        ## create comparable value
        $self->{ALGORITHM} = lc ($self->{PW_ATTR_HASH});

        ## compute the digest
        if ($self->{ALGORITHM} eq "sha1")
        {
            $digest = Digest::SHA1->new;
            $digest->add ($passwd);
            ##! 8: "Digest: SHA1"
            my $b64digest = $digest->b64digest;
            ##! 8: "SHA1: $b64digest"
            $self->{DIGEST} = $b64digest;
        }
        elsif ($self->{ALGORITHM} eq "md5")
        {
            my $digest = Digest::MD5->new;
            $digest->add($passwd);
            $self->{DIGEST} = $digest->b64digest;
        }
        elsif ($self->{ALGORITHM} eq "crypt")
        {
            $self->{DIGEST} = crypt ($passwd, $ldapdigest);
        }
        elsif ($self->{ALGORITHM} =~ /^none$/i)
        {
            $self->{DIGEST} = $passwd;
        } else {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_MISSING_PW_ATTR_HASH_IN_ENTRY",
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => 'auth',
		},
		);
        }               
        ##! 4: "ident name ... ".$account
        ##! 4: "ident algorithm ... ".$self->{ALGORITHM}
        ##! 4: "ident digest ... ".$self->{DIGEST}
  
        ## compare passphrases

        ## sometimes hash creators put the algorithm used in front of 
        ## the value and a '=' at its end. We will strip that for 
        ## comparision
        if ( $ldapdigest =~ /^\{\w+\}(.+)=$/ )
        {
            $ldapdigest = $1;
            ##! 8: "value contains {X}Y="
        } else {
	    if ( $ldapdigest =~ /^\{\w+\}(.+)$/ ) {
        	 $ldapdigest = $1;
        	 ##! 8: "value contains {X}Y"
            };
	};    
        ##! 4: "comparing |".$self->{DIGEST}."| with |".$ldapdigest."|"

        if ($self->{DIGEST} ne $ldapdigest)
        {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_LOGIN_FAILED",
		
		);
        }
    }
    elsif ( $ldapauthmeth eq "bind" )
    {
        ## do simple ldap bind for authentication 

        my $bindmsg = $ldap->bind( $self->{DN}, 
                                   'password' => $passwd );

        if ($bindmsg->is_error())
        {
            if ( $bindmsg->code() == 49 )
            {
                CTX('log')->log (FACILITY => "auth",
                               PRIORITY => "error",
                               MESSAGE  => "LDAP bind failed. Invalid configuration.");
            } else {   
                CTX('log')->log (FACILITY => "auth",
                               PRIORITY => "error",
                               MESSAGE  => "LDAP bind failed.\n".
                                           "bind error:     ".$bindmsg->error()."\n".
                                           "bind servererr: ".$bindmsg->server_error()."\n".
                                           "bind mesg code: ".$bindmsg->code());
            }
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_LOGIN_FAILED");
        }
        ##! 8: "        LDAP Login successfull"

        my $unbindmesg = $ldap->unbind;
        if (not $unbindmesg->is_error ) {
            ##! 16: "        ldap unbind success "
        }

    } else {
        CTX('log')->log (FACILITY => "auth",
                       PRIORITY => "error",
                       MESSAGE  => "LDAP config error. Unknown authentication method.");
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_UNKNWON_AUTH_METHOD");
    }
    $self->{USER} = $account;
 
    ## OK the user seems to be authenticated properly, let's see if we can
    ## map him to a role:
    my $found = 0;
    my $rolefound = undef;

    ##! 2: "looking for the role"

    foreach my $role (@rolevalues)
    {
        if (exists $self->{ROLE_MAP}->{$role})
        {
            ##! 2: 'found role ' . $role
	    ##! 2" 'role mapped to ' . $self->{ROLE_MAP}->{$role}
	    $self->{ROLE} = $self->{ROLE_MAP}->{$role};
            $found     = 1;
            last;
        }
    }
    if ( not $found )
    {
        CTX('log')->log (FACILITY => "auth",
                       PRIORITY => "error",
                       MESSAGE  => "LDAP login: cannot find role for user $account.");
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_LOGIN_FAILED");
    }
    };   # the end of auth block
    
    ##! 4: 'got user >' . $self->{USER} . '<'
    ##! 4: 'got role >' . $self->{ROLE} . '<'

    return (
        $self->{USER},
        $self->{ROLE},
        {
            SERVICE_MSG => 'SERVICE_READY',
        },
    );
}

sub __get_ldap_error
{
    my $self = shift;
    my $msg  = shift;

    return ("CODE"  => $msg->code(),
            "ERROR" => $msg->error(),
            "NAME"  => ldap_error_name($msg),
            "TEXT"  => ldap_error_text($msg),
            "DESCRIPTION" => ldap_error_desc($msg));
}

1;
__END__

=head1 Name

OpenXPKI::Server::Authentication::LDAP - LDAP based authentication.

=head1 Description

This is the class which supports OpenXPKI with an internal passphrase based
authentication method. The parameters are passed as a hash reference.
LDAP database source (user/password stored in LDAP or AD server)        
This is the most complex authentication method.

=head1 Functions

=head2 new

is the constructor. The supported parameters are XPATH and COUNTER.
This is the minimum parameter set for any authentication class.
Parameters block in the configuration must also include:

=over

=item *

B<host> - LDAP server hostname (e.g. localhost);

=item *

B<port> - LDAP server port (e.g. 389);

=item *

B<base> - top DN for search in LDAP database;

=item *

B<version> - LDAP version (we support only 3); 

=item *

B<bind_dn> - DN for binding to LDAP server;

=item *

B<bind_pw> - password for binding to LDAP server;

=item *

B<use_tls> - use 'false' here if you do not want to use TLS
connection to LDAP server, 'true_tls' value will switch on
TLS mode via STARTTLS command to server, use 'true_ssl'
instead if you want to try Net::LDAPS SSL connection first
(if Net::LDAPS is not installed the STARTTLS will be used);

=item *

B<capath> - path to the certificates for TLS connection 
(makes sense only if B<use_tls> parameter is set to 'B<true_tls>' or
'B<true_ssl>');

=item *

B<searchattr> - LDAP entry attribute which value will be compared to account;

=item *

B<searchvalueprefix> - prefix which will be added 
in front of the account name before comparing it to the value of B<searchattr>;

=item *

B<auth_meth_attr> - LDAP entry attribute which value is used 
to specify authentication method;

=item *

B<default_auth_meth> - name of the authentication method which 
is used if no method found in user entry;

=item *

B<auth_meth_map> - a block containing a pair attr_value->auth_meth 
mapping auth_meth_attr value to real authentication method name;

=item *

B<pw_attr> -  LDAP entry attribute which value is used to compare to password;

=item *

B<pw_attr_hash> - name of the hash type stored in pw_attr (e.g. sha1 );

=item *

B<role_attr> - LDAP entry attribute which value is used to assign a role;

=item *

B<role_map> - block containg pair value->role
mapping role_attr value to real OpenXPKI role;

=back

=head2 login_step

The procedure goes in the following way:

=over

=item 1.

connect to LDAP server using parameters: 
B<host>, B<port>, B<version> and B<capath> 
(the last one - in the case of using TLS);	 

=item 2.

search LDAP entry starting from the B<base_dn> using filtering condition
built with B<search_attr>, B<searchvalueprefix> and account string
(exactly one entry is expected to exist);

=item 3.

read all values of the entry attributes whose names are specified in
B<auth_meth_attr>, B<pw_attr> and  B<role_attr>;

=item 4.

select an authetication method - 
find the value of B<auth_meth_attr> that is present in the set of 
mapping pairs B<attr_value>/B<auth_meth> 
(if no match detected the method specified in B<default_auth_meth> 
will be used);

=item 5.

authenticate user using the method selected: 
there are two variants at the moment - 
to compare a password hash in B<pw_attr> with
the hash of the password passed to the module 
(method name is 'B<pwattr>') 
or to try password-based bind to the same LDAP 
server account (method name is 'B<bind>');

=item 6. 

find the value of B<role_attr> that is present in the set of mapping pairs
B<value>/B<role> and assign the corresponding role to the user authenticated.

=back

The procedure returns (B<user>, B<role>, B<SERVICE_READY> message) triple 
if login was successful, (B<undef>, B<undef>, B<{}>) otherwise.




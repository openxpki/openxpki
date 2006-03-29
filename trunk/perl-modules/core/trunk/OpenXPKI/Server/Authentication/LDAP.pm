## OpenXPKI::Server::Authentication::LDAP.pm 
##
## Written by Peter Gietz 2005
## Re-Written by Michael Bell 2006
## Copyright (C) 2003-2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;

package OpenXPKI::Server::Authentication::LDAP;

use OpenXPKI qw(debug);
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

    my $self = {
                DEBUG     => 0,
               };

    bless $self, $class;

    my $keys = shift;
    $self->{DEBUG} = 1 if ($keys->{DEBUG});
    $self->debug ("start");

    my $config = CTX('config');

    ## load network configuration

    $self->{HOST} = $config->get_xpath (XPATH   => [ %{$keys->{XPATH}},   "host" ],
                                        COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->{PORT} = $config->get_xpath (XPATH   => [ %{$keys->{XPATH}},   "port" ],
                                        COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->{BASE} = $config->get_xpath (XPATH   => [ %{$keys->{XPATH}},   "base" ],
                                        COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->{VERSION} = $config->get_xpath (XPATH   => [ %{$keys->{XPATH}},   "version" ],
                                        COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->{BIND_DN} = $config->get_xpath (XPATH   => [ %{$keys->{XPATH}},   "bind_dn" ],
                                        COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->{BIND_PW} = $config->get_xpath (XPATH   => [ %{$keys->{XPATH}},   "bind_pw" ],
                                        COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->debug ("version ::= ".$self->{VERSION});
    $self->debug ("server  ::= ldap://".$self->{HOST}.":".
                                        $self->{PORT}."/".
                                        $self->{BASE});
    $self->debug ("user    ::= ".$self->{BIND_DN});

    ## check for a TLS protected connection
    ## FIXME: who checks when that TLS is supported?

    $self->{USE_TLS} = $config->get_xpath (XPATH   => [ %{$keys->{XPATH}},   "use_tls" ],
                                           COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->{USE_TLS} = 1 if (lc($self->{USE_TLS}) eq "true");
    $self->{USE_TLS} = 0 if (lc($self->{USE_TLS}) eq "false");
    if ($self->{USE_TLS})
    {
        $self->{CA_PATH} = $config->get_xpath (XPATH   => [ %{$keys->{XPATH}},   "capath" ],
                                               COUNTER => [ %{$keys->{COUNTER}}, 0]);
        $self->debug ("cacert ::= ".$self->{CA_CERT});
    }
    $self->debug ("use_tls ::= ".$self->{USE_TLS});

    ## load search config

    $self->{SEARCH_ATTRIBUTE} = $config->get_xpath (
                XPATH   => [ %{$keys->{XPATH}},   "searchattr" ],
                COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->{SEARCH_VALUE_PREFIX} = $config->get_xpath (
                XPATH   => [ %{$keys->{XPATH}},   "searchvalueprefix" ],
                COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->debug ("search->attribute    ::= ".$self->{SEARCH_ATTRIBUTE});
    $self->debug ("search->value_prefix ::= ".$self->{SEARCH_VALUE_PREFIX});

    ## load authentication config

    $self->{AUTH_METH_ATTR} = $config->get_xpath (
                XPATH   => [ %{$keys->{XPATH}},   "auth_meth_attr" ],
                COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->{DEFAULT_AUTH_METHOD} = $config->get_xpath (
                XPATH   => [ %{$keys->{XPATH}},   "default_auth_meth" ],
                COUNTER => [ %{$keys->{COUNTER}}, 0]);
    my $count = $config->get_xpath_count (
                XPATH   => [ %{$keys->{XPATH}},   "auth_meth_map" ],
                COUNTER => $keys->{COUNTER});
    for (my $i=0; $i < $count; $i++)
    {
        my $condition = $config->get_xpath (
                XPATH   => [ %{$keys->{XPATH}},   "auth_meth_map", "attr_value" ],
                COUNTER => [ %{$keys->{COUNTER}}, $i, 0]);
        my $method = $config->get_xpath (
                XPATH   => [ %{$keys->{XPATH}},   "auth_meth_map", "auth_meth" ],
                COUNTER => [ %{$keys->{COUNTER}}, $i, 0]);
        $self->{AUTH_METHOD}->{$condition} = $method;
    }
    $self->{PW_ATTR} = $config->get_xpath (
                XPATH   => [ %{$keys->{XPATH}},   "pw_attr" ],
                COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->{PW_ATTR_HASH} = $config->get_xpath (
                XPATH   => [ %{$keys->{XPATH}},   "pw_attr_hash" ],
                COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->debug ("auth->method_attr    ::= ".$self->{AUTH_METH_ATTR});
    $self->debug ("auth->default_method ::= ".$self->{DEFAULT_AUTH_METHOD});
    $self->debug ("auth->pw_attr        ::= ".$self->{PW_ATTR});
    $self->debug ("auth->pw_attr_hash   ::= ".$self->{PW_ATTR_HASH});

    ## role mapping

    $self->{ROLE_ATTR} = $config->get_xpath (
                XPATH   => [ %{$keys->{XPATH}},   "role_attr" ],
                COUNTER => [ %{$keys->{COUNTER}}, 0]);
    $self->debug ("role attribute ::= ".$self->{ROLE_ATTR});
    $count = $config->get_xpath_count (
                 XPATH   => [ %{$keys->{XPATH}},   "role_map" ],
                 COUNTER => $keys->{COUNTER});
    for (my $i=0; $i < $count; $i++)
    {
        my $value = $config->get_xpath (
                        XPATH   => [ %{$keys->{XPATH}},   "role_map", "value" ],
                        COUNTER => [ %{$keys->{COUNTER}}, $i, 0 ]);
        my $role  = $config->get_xpath (
                        XPATH   => [ %{$keys->{XPATH}},   "role_map", "role" ],
                        COUNTER => [ %{$keys->{COUNTER}}, $i, 0 ]);
        $self->{ROLE_MAP}->{$value} = $role;
        $self->debug ("role map $value to $role");
    }

    return $self;
}

sub login
{
    my $self = shift;
    $self->debug ("start");
    my $gui = CTX('service');

    my ($account, $passwd) = $gui->get_passwd_login ("");

    $self->debug ("account ... $account");


    ## now start an LDAP connection

    my $bindmsg = undef;
    my $ldap = undef;

    if ( $self->{USE_TLS} and not $is_ldaps )
    {
        ## we use start_tls because ldaps is not installed
        $self->{START_TLS} = 1;
        $self->{USE_TLS}   = 0;
    }

    if ( $self->{USE_TLS} )
    {  
        $self->debug("starting a SSL (ldaps) session on");

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
    $self->debug ("connect successfull");

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
                $self->debug("naming context: $namingContext[$_]");
            }
            $is_rootdse = 1;
        } else {
            $self->debug("root_dse unsuccessfull");
        }
        if ( $is_rootdse and 
             not $root_dse->supported_extension ($starttls_OID))
        {
            CTX('log')->log (FACILITY => "system",
                           PRIORITY => "error",
                           MESSAGE  => "LDAP Server does not support START_TLS.");
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_START_TLS_NOT_POSSIBLE");
        }
        $self->debug("executing start_tls ...");

        my $tlsmsg = $ldap->start_tls ( 
                         verify =>'require',
                         capath => $self->{CA_PATH});
        if ( $tlsmsg->is_error() )
        {
            my $msg = "Possible reason: The directory in \"capath\" must contain certificates ".
                      "named using the hash value of the certificates\' subject names. ".
                      "To generate these names, use OpenSSL like this in Unix: ".
                      "ln -s cacert.pem \`openssl x509 -hash -noout \< cacert.pem\`.0";
            CTX('log')->log (FACILITY => "system",
                           PRIORITY => "error",
                           MESSAGE  => "LDAP Server failed during start_tls.\n$msg\n".
                                       join ", ", $self->__get_ldap_error ($tlsmsg));
            $self->debug (join ",", $self->__get_ldap_error ($tlsmsg));
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_START_TLS_NOT_POSSIBLE",
                params  => {$self->__get_ldap_error ($tlsmsg)});
        } else {
            $self->debug("starttls successful");
        }
    } ## end of START_TLS
    
    ## now OpenXPKI authenticates itself by binding to the 
    ## entry configured in bind_dn

    $bindmsg = $ldap->bind( $self->{BIND_DN}, 
                            'password' => $self->{BIND_PW} );
    if ($bindmsg->is_error())
    {
        if ( $bindmsg->code() == 49 ) {
            $self->debug("invalid ldap credentials\n");
        } else {  
            $self->debug("LDAP bind: ", join ", ", $self->__get_ldap_error ($bindmsg));
        }
        CTX('log')->log (FACILITY => "system",
                       PRIORITY => "error",
                       MESSAGE  => "LDAP bind to server failed.\n".
                                   join ", ", $self->__get_ldap_error ($bindmsg));
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_BIND_NOT_POSSIBLE",
            params  => {$self->__get_ldap_error ($bindmsg)});
    }
    $self->debug("bind successful");
		
    ## now search for an entry with an ID-attribute containing 
    ## the value inputted by the user

    my $searchfilter = "($self->{SEARCH_ATTRIBUTE}=".
                       "$self->{SEARCH_VALUE_PREFIX}$account)";
    $self->debug("search filter: $searchfilter");

    my $searchmesg = $ldap->search(
                         base   => $self->{BASE},
                         filter => $searchfilter);
    if ($searchmesg->is_error())
    {
        CTX('log')->log (FACILITY => "system",
                       PRIORITY => "error",
                       MESSAGE  => "LDAP search on server failed.\n".
                                   join ", ", $self->__get_ldap_error ($searchmesg));
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_SEARCH_FAILED",
            params  => {$self->__get_ldap_error ($searchmesg)});
    }
    my $entrycount = $searchmesg->count();
		
    ## no user found?
    if ( not $entrycount )
    {
        CTX('log')->log (FACILITY => "system",
                       PRIORITY => "error",
                       MESSAGE  => "LDAP login found no matching user.");
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_NO_USER_FOUND");
    }

    ## more than one user found?
    if ( not $entrycount )
    {
        CTX('log')->log (FACILITY => "system",
                       PRIORITY => "error",
                       MESSAGE  => "LDAP login found more then one matching entry.");
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_MORE_THAN_ONE_USER_FOUND");
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
    $self->debug("analysing entry $self->{DN}");

    foreach my $attr ( $entry->attributes )
    {
        foreach $value ( $entry->get_value( $attr ) )
        { 
            #$self->debug("attr: |$attr| = $value");
            if ( lc($attr) eq lc($self->{ROLE_ATTR}) )
            {
                #$self->debug ("Roleattribute = $value");
                $rolevalues[$rolevaluecount] = $value;
                $rolevaluecount ++;
            }
            elsif ( lc($attr) eq 
                    lc($self->{AUTH_METH_ATTR}) )
            {
                #$self->debug ("ldapauthmethattribute = $value");
                $ldapauthmethattrvalues[$ldapauthmethattrvaluecount] = $value;
                $ldapauthmethattrvaluecount ++;
            }
            elsif ( lc($attr) eq 
                    lc($self->{PW_ATTR}) )
            {
                #$self->debug ("ldappwattribute = $value");
                $ldappwattrvalues[$ldappwattrvaluecount] = $value;
                $ldappwattrvaluecount ++;
            }
        }
    }
    $self->debug("rolecount: $rolevaluecount; ".
                 "authmethcount: $ldapauthmethattrvaluecount; ".
                 "ldappwattrcount: $ldappwattrvaluecount");

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
        $self->debug ("Found auth meth");		    
        if ($ldapauthmeth eq "pwattr" and not $ldappwattrvaluecount )
        {
            # Error no value of ldap pw attribute 
            CTX('log')->log (FACILITY => "system",
                           PRIORITY => "error",
                           MESSAGE  => "LDAP login found no password attribute in the entry.");
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_MISSING_PW_ATTR_IN_ENTRY");
        }
    } else {
        $ldapauthmeth = $self->{DEFAULT_AUTH_METHOD};
    }
    $self->debug("ldapauthmeth: $ldapauthmeth");
		
    ## Method pwattr 
    ## (use a configurable password attribute for authentication)
    if ( $ldapauthmeth eq "pwattr" )
    {
        my $algorithm = undef;
        my $digest = undef;

        my $ldapdigest = $ldappwattrvalues[0];

        $self->debug("ldapdigest : |$ldapdigest| ");

        ## create comparable value
        $self->{ALGORITHM} = lc ($self->{PW_ATTR_HASH});

        ## compute the digest
        if ($self->{ALGORITHM} eq "sha1")
        {
            $digest = Digest::SHA1->new;
            $digest->add ($passwd);
            $self->debug( "Digest: SHA1\n");
            my $b64digest = $digest->b64digest;
            $self->debug( "SHA1: $b64digest");
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
            CTX('log')->log (FACILITY => "system",
                           PRIORITY => "error",
                           MESSAGE  => "LDAP login found no hash algorithm for the entry.");
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_MISSING_PW_ATTR_HASH_IN_ENTRY");
        }               
        $self->debug ("ident name ... ".$account);
        $self->debug ("ident algorithm ... ".$self->{ALGORITHM});
        $self->debug ("ident digest ... ".$self->{DIGEST});
  
        ## compare passphrases

        ## sometimes hash creators put the algorithm used in front of 
        ## the value and a '=' at its end. We will strip that for 
        ## comparision
        if ( $ldapdigest =~ /^\{\w+\}(.+)=$/ )
        {
            $ldapdigest = $1;
            $self->debug ("value contains {X}Y=");
        }
        $self->debug ("comparing |".$self->{DIGEST}."| with |".$ldapdigest."|");

        if ($self->{DIGEST} ne $ldapdigest)
        {
             CTX('log')->log (FACILITY => "auth",
                            PRIORITY => "warn",
                            MESSAGE  => "LDAP login failed. Password is wrong.");
             OpenXPKI::Exception->throw (
                 message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LDAP_LOGIN_FAILED");
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
        $self->debug ("        LDAP Login successfull");

        my $unbindmesg = $ldap->unbind;
        if (not $unbindmesg->is_error ) {
            $self->debug ("        ldap unbind success ");
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

    $self->debug ("looking for the role");

    foreach my $role (@rolevalues)
    {
        if (exists $self->{ROLE_MAP}->{$role})
        {
            $self->{ROLE} = $role;
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

    return 1;
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

sub get_user
{
    my $self = shift;
    $self->debug ("start");
    return $self->{USER};
}

sub get_role
{
    my $self = shift;
    $self->debug ("start");
    return $self->{ROLE};
}

1;
__END__

=head1 Description

This is the class which supports OpenXPKI with an internal passphrase based
authentication method. The parameters are passed as a hash reference.
LDAP database source (user/password stored in LDAP or AD server)        
This is the most complex authentication method.
FIXME:

=head1 Functions

=head2 new

is the constructor. The supported parameters are DEBUG, XPATH and COUNTER.
This is the minimum parameter set for any authentication class.
We need here a complete description of the LDAP config stuff.

=head2 login

returns true if the login was successful. Here we need at minimum a description
of the algorithm. Otherwise this module is too critical.

=head2 get_user

returns the user which logged in successfully.

=head2 get_role

returns the role.

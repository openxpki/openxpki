# OpenXPKI::Crypto::TokenManager.pm 
## Rewritten 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2003-2006 by The OpenXPKI Project
package OpenXPKI::Crypto::TokenManager;

use strict;
use warnings;
use Switch;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;
use English;
use OpenXPKI::Crypto::Backend::API;
use OpenXPKI::Crypto::Tool::SCEP::API;
use OpenXPKI::Crypto::Tool::PKCS7::API;
use OpenXPKI::Crypto::Tool::CreateJavaKeystore::API;
use OpenXPKI::Crypto::Secret;

sub new {
    ##! 1: 'start'
    my $that = shift;
    my $class = ref($that) || $that;

    my $caller_package = caller;
    
    my $self = {};

    bless $self, $class;

    my $keys = { @_ };
    $self->{tmp} = $keys->{TMPDIR} if ($keys->{TMPDIR});

    $self->{called_from_testscript} = 1 if ($keys->{'IGNORE_CHECK'});

    if ($caller_package ne 'OpenXPKI::Server::Init' &&
        ! $self->{called_from_testscript}) {
        # TokenManager instances shall only be created during
        # the server initialization, the rest of the code can
        # use CTX('crypto_layer') as its token manager
        # IGNORE_CHECK is only meant for unit tests!
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOKENMANAGER_INSTANTIATION_OUTSIDE_SERVER_INIT',
            params => {
                'CALLER' => $caller_package,
            },
        );
    }
    ##! 1: "end - token manager is ready"
    return $self;
}

######################################################################
##                authentication management                         ##
######################################################################

=head2 __load_secret_groups()

Initialize all secrets configured for current realm

=cut
sub __load_secret_groups
{
    ##! 1: "start"
    my $self = shift;
    my $keys = shift;

    my $config = CTX('config');

    my @groups = $config->get_keys('crypto.secret');

    foreach my $group (@groups) {
        ##! 16: 'group: ' . $group
        $self->__load_secret ({GROUP => $group});
    }

    my $count = scalar @groups;
    ##! 1: "finished: $count"
    $self->{SECRET_COUNT} = $count;
    return $count;
}

=head2 __load_secret( {GROUP} ) 

Initialize the secret for the requested group

=cut
sub __load_secret
{
    ##! 1: "start"
    my $self = shift;
    my $keys = shift;

    ##! 2: "get the arguments"
    my $group  = $keys->{GROUP};
    my $realm = CTX('session')->get_pki_realm();
    
    ##! 16: 'group: ' . $group
    
    if (not $group)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_LOAD_SECRET_MISSING_GROUP");
    }

    # don't create a new object if we already have one
    if (exists $self->{SECRET}->{$realm}->{$group}) {
        ##! 4: '__load_secret called even though secret is already loaded'
        return 1;
    }
 
    my $config = CTX('config');

    ##! 2: "initialize secret object"
    my $method = $config->get("crypto.secret.$group.method");
    my $label = $config->get("crypto.secret.$group.label");
    $self->{SECRET}->{$realm}->{$group}->{TYPE}  = $method;
    $self->{SECRET}->{$realm}->{$group}->{LABEL} = ($label ? $label : $method);

    switch ($method)
    {
        case "literal" {
            my $value = $config->get("crypto.secret.$group.value");
            $self->{SECRET}->{$realm}->{$group}->{REF} = OpenXPKI::Crypto::Secret->new ({TYPE => "Plain", PARTS => 1});
            $self->{SECRET}->{$realm}->{$group}->{REF}->set_secret ($value);
        }
        case "plain"   {            
            $self->{SECRET}->{$realm}->{$group}->{REF} = OpenXPKI::Crypto::Secret->new ({
                    TYPE => "Plain",
                    PARTS => $config->get("crypto.secret.$group.total_shares") 
                });
             }
        case "split"  {
           
            $self->{SECRET}->{$realm}->{$group}->{REF} = OpenXPKI::Crypto::Secret->new ({
                    TYPE => "Split",
                    QUORUM => { 
                        K => $config->get("crypto.secret.$group.required_shares"), 
                        N => $config->get("crypto.secret.$group.total_shares"),  
                    },
                    TOKEN  => CTX('api')->get_default_token(),
            });
        }
        else {
              OpenXPKI::Exception->throw (
                  message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_LOAD_SECRET_WRONG_METHOD",
                  params  => {
                      REALM => $realm,
                      GROUP => $group,
                      METHOD => $method
                  });
             }
    }

    $self->__set_secret_from_cache({        
        GROUP     => $group,        
    });

    ##! 1: "finish"
    return 1;
}

=head2 __set_secret_from_cache ()

Load all secrets in the current realm from the cache

=cut
sub __set_secret_from_cache {
    my $self    = shift;
    my $arg_ref = shift;

    my $group  = $arg_ref->{'GROUP'};    
    my $realm = CTX('session')->get_pki_realm();    

    my $config = CTX('config');
    my $cache_config = $config->get_hash("crypto.secret.$group.cache");

    ##! 2: "load cache configuration"
    if (!$cache_config || ($cache_config->{type} ne "session" and
        $cache_config->{type} ne "daemon"))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_LOAD_SECRET_WRONG_CACHE_TYPE",
                  params  => {
                      TYPE => $cache_config->{type},
                      GROUP => $group
                  });
    }
    
    $self->{SECRET}->{$realm}->{$group}->{CACHE} = $cache_config->{type}; 
        
    ##! 2: "check for the cache"
    my $secret = "";
    if ($self->{SECRET}->{$realm}->{$group}->{CACHE} eq "session")
    {
        ## session mode
        ##! 4: "let's load the serialized secret in the session"
        $secret = CTX('session')->get_secret ($group);
        ##! 16: 'secret: ' . $secret
    } else {
        ## daemon mode
        ##! 4: "let's get the serialized secret from the database"
        if (! $self->{called_from_testscript}
            && CTX('dbi_backend')->is_connected()) {
            # do this only if the database is already connected
            # i.e. not during server startup
            # (this is senseless anyhow, as we will only find
            # outdated secrets at that point)
            # ... and not during test script execution, as we don't
            # have a dbi_backend context there
            my $secret_result = CTX('dbi_backend')->first (
                                    TABLE   => "SECRET",
                                    DYNAMIC => {
                                        PKI_REALM => {VALUE => $realm},
                                        GROUP_ID  => {VALUE => $group}});
            $secret = $secret_result->{DATA};
        }
        ##! 16: 'secret: ' . $secret
    }
    if (defined $secret and length $secret)
    {
        ##! 16: 'setting serialized secret'
        $self->{SECRET}->{$realm}->{$group}->{REF}->set_serialized ($secret);
    }
    return 1;
}

=head2 get_secret_groups

List type and name of all secret groups in the current realm

=cut
sub get_secret_groups
{
    ##! 1: "start"
    my $self = shift;

    ##! 2: "init"
    my $realm = CTX('session')->get_pki_realm();
    $self->__load_secret_groups()
        if (not exists $self->{SECRET_COUNT});

    ##! 2: "build list"
    my %result = ();
    foreach my $group (keys %{$self->{SECRET}->{$realm}})
    {
        $result{$group}->{LABEL} = $self->{SECRET}->{$realm}->{$group}->{LABEL};
        $result{$group}->{TYPE}  = $self->{SECRET}->{$realm}->{$group}->{TYPE};
    }

    ##! 1: "finished"
    return %result;
}

=head2 reload_all_secret_groups_from_cache 

Reload the secrets B<for the current pki realm>

FIXME: I dont see any benefit in loading the secret groups from other realms 
than the one in the session and changed the behaviour of this method.

=cut

sub reload_all_secret_groups_from_cache {
    ##! 1: 'start'
    my $self = shift;

    my $realm = CTX('session')->get_pki_realm();

    foreach my $group (keys %{$self->{SECRET}->{$realm}}) {
        ##! 16: 'group: ' . $group
        $self->__set_secret_from_cache({
            GROUP     => $group,        
        });
    }    
    
    ##! 1: 'end'
    return 1;
}

=head2

Check if the secret group is complete (all passwords loaded)

=cut
sub is_secret_group_complete
{
    ##! 1: "start"
    my $self  = shift;
    my $group = shift;

    ##! 2: "init"
    my $realm = CTX('session')->get_pki_realm();
    $self->__load_secret({ GROUP => $group})
        if (not exists $self->{SECRET} or
            not exists $self->{SECRET}->{$realm} or
            not exists $self->{SECRET}->{$realm}->{$group});
            
    $self->__set_secret_from_cache({        
        GROUP     => $group,        
    });

    ##FIXME: Why the double return? - oliwel
    
    ##! 2: "return true if it is complete"    
    my $boolean = $self->{SECRET}->{$realm}->{$group}->{REF}->is_complete();
    return $boolean if ($boolean); 

    ##! 1: "finished"
    return $self->{SECRET}->{$realm}->{$group}->{REF}->is_complete();
}

sub set_secret_group_part
{
    ##! 1: "start"
    my $self  = shift;
    my $args  = shift;
    my $group = $args->{GROUP};
    my $part  = $args->{PART};
    my $value = $args->{VALUE};

    ##! 2: "init"
    my $realm = CTX('session')->get_pki_realm();
    $self->__load_secret({  GROUP => $group})
        if (not exists $self->{SECRET} or
            not exists $self->{SECRET}->{$realm} or
            not exists $self->{SECRET}->{$realm}->{$group});

    ##! 2: "set secret"
    if (defined $part)
    {
        $self->{SECRET}->{$realm}->{$group}->{REF}->set_secret({SECRET => $value, PART => $part});
    } else {
        $self->{SECRET}->{$realm}->{$group}->{REF}->set_secret($value);
    }

    ##! 2: "store the secrets"
    my $secret = $self->{SECRET}->{$realm}->{$group}->{REF}->get_serialized();
    if ($self->{SECRET}->{$realm}->{$group}->{CACHE} eq "session")
    {
        ##! 4: "let's store the serialized secret in the session"
        CTX('session')->set_secret ({
            GROUP  => $group,
            SECRET => $secret});
    } else {
        ##! 4: "let's store the serialized secret in the database"
        my $result = CTX('dbi_backend')->select (
                         TABLE => "SECRET",
                         DYNAMIC => {
                             PKI_REALM => {VALUE => $realm},
                             GROUP_ID  => {VALUE => $group}});
        if (scalar @{$result})
        {
            ##! 8: "this is an update in daemon mode"
            CTX('dbi_backend')->update (
                TABLE => "SECRET",
                DATA  => {DATA => $secret},
                WHERE => {
                    PKI_REALM => $realm,
                    GROUP_ID  => $group});
        }
        else
        {
            ##! 8: "this is an insert in daemon mode"
            CTX('dbi_backend')->insert (
                TABLE => "SECRET",
                HASH  => {
                    DATA      => $secret,
                    PKI_REALM => $realm,
                    GROUP_ID  => $group});
        }
        CTX('dbi_backend')->commit();
    }

    ##! 1: "finished"
    return 1;
}

sub clear_secret_group
{
    ##! 1: "start"
    my $self  = shift;
    my $group = shift;

    ##! 2: "init"
    my $realm = CTX('session')->get_pki_realm();
    $self->__load_secret({ GROUP => $group})
        if (not exists $self->{SECRET} or
            not exists $self->{SECRET}->{$realm} or
            not exists $self->{SECRET}->{$realm}->{$group});

    ##! 2: "check for the cache"
    if ($self->{SECRET}->{$realm}->{$group}->{CACHE} eq "session")
    {
        ##! 4: "let's store the serialized secret in the session"
        CTX('session')->clear_secret ($group);
    } else {
        ##! 4: "let's store the serialized secret in the database"
        my $result = CTX('dbi_backend')->select (
                         TABLE => "SECRET",
                         DYNAMIC => {
                             PKI_REALM => {VALUE => $realm},
                             GROUP_ID  => {VALUE => $group}});
        if (scalar @{$result})
        {
            ##! 8: "we have to delete something"
            CTX('dbi_backend')->delete (
                TABLE => "SECRET",
                DATA  => {
                    PKI_REALM => $realm,
                    GROUP_ID  => $group});
        }
    }
    delete $self->{SECRET}->{$realm}->{$group};
    $self->__load_secret({
        PKI_REALM => $realm,
        GROUP     => $group,
    });

    ##! 1: "finished"
    return 1;
}

######################################################################
##                     slot management                              ##
######################################################################

=head2 get_token( { TYPE, NAME } )

Get a crypto token to execute commands for the current realm 

=item TYPE: Determines the used API, one of the values given in 
   system.crypto.tokenapi (certsign, crlsign, datasafe....)
   
=item NAME: The name of the token to initialize, for versioned tokens 
  including the generation identifier, e.g. server-ca-2.  

=cut
sub get_token
{
    my $self = shift;
    my $keys = shift;
    ##! 1: "start"

    #my $name   = $keys->{ID};        
    my $type   = $keys->{TYPE};
    my $name   = $keys->{NAME};

    my $realm = CTX('session')->get_pki_realm();

    ##! 32: "Load token $name of type $type"
    if (not $type)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_TYPE");
    }
        
    if (not $name)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_NAME");
    }
    if (not $realm)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_PKI_REALM");
    }
    ##! 2: "$realm: $type -> $name"

    if (not $self->{TOKEN}->{$realm}->{$type}->{$name}) {
        $self->__add_token({
            TYPE        => $type,
            NAME        => $name,
        });
    }
    ##! 2: "token added"

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_EXIST")
        if (not $self->{TOKEN}->{$realm}->{$type}->{$name});
    ##! 2: "token is present"

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_USABLE")
        if (not $self->__use_token (TYPE => $type, NAME => $name, PKI_REALM => $realm));
    ##! 2: "token is usable"

    return $self->{TOKEN}->{$realm}->{$type}->{$name};
}

=head2 get_system_token( { TYPE } )

Get a crypto token from the system namespace. This includes all non-realm
dependend tokens which dont have key material attached.

The tokens are defined in the system.crypto.token namespace. 
Common tokens are default, pkcs7 and javaks.
 
=cut
sub get_system_token {
    
    my $self = shift;
    my $keys = shift;
    ##! 1: "start"

    my $type   = lc($keys->{TYPE});
       
    ##! 32: "Load token system of type $type"
    if (not $type)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_TYPE");
    }
    
    my $config = CTX('config');
    my $backend = $config->get("system.crypto.token.$type.backend");
    
    if (not $backend) {    
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_SYSTEM_TOKENUNKNOWN_TYPE",
            params => { TYPE => $type }    
        );   
    }
        
    if (not $self->{TOKEN}->{system}->{$type}) {
        
        my $backend_api_class = CTX('config')->get("system.crypto.token.$type.api");
        
        ##! 16: 'instantiating token, API class: ' . $backend_api_class
        $self->{TOKEN}->{system}->{$type} =
                $backend_api_class->new ({
                    CLASS => $backend,
                    TMP   => $self->{tmp},      
                    TOKEN_TYPE => $type, 
                });     
    }
    ##! 2: "token added"

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_EXIST")
        if (not $self->{TOKEN}->{system}->{$type});
    ##! 2: "token is present"

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_USABLE")
        if (not $self->__use_token(TYPE => $type, PKI_REALM => 'system'));
    ##! 2: "token is usable"

    return $self->{TOKEN}->{system}->{$type};
    
}
 
sub __add_token
{
    my $self = shift;
    my $keys = shift;
    ##! 1: "start"

    my $type   = $keys->{TYPE};
    my $name   = $keys->{NAME};
    my $realm = CTX('session')->get_pki_realm();
    my $config = CTX('config');

    my $backend_class;
    my $secret;
    
    ##! 16: "add token type $type, name: $name" 
    my $backend_api_class = $config->get("system.crypto.tokenapi.$type");    
    $backend_api_class = "OpenXPKI::Crypto::Backend::API" unless ($backend_api_class);
    
    # FIXME - Need to put this somewhere for general use
    my $config_name = $name;    
    do {
        $backend_class = $config->get("crypto.token.$config_name.backend");                                
        $config_name = $config->get("crypto.token.$config_name.inherit");
    } while ( defined $config_name && not $backend_class);
    
    if (not $backend_class)  {
        OpenXPKI::Exception->throw (
            message  => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_NO_BACKEND_CLASS",
            params => { TYPE => $type, NAME => $name}
        );
    }
    
    $config_name = $name;
    do {
        $secret = $config->get("crypto.token.$config_name.secret");                                
        $config_name = $config->get("crypto.token.$config_name.inherit");
    } while ( defined $config_name && not $secret);    
    
    ##! 16: "Token backend: $backend_class, Secret group: $secret"
    
    ##! 2: "determine secret group"    
    if ($secret) {
        ##! 4: "secret is configured"        
        $self->__load_secret({ GROUP => $secret })
            if (not exists $self->{SECRET} or
                not exists $self->{SECRET}->{$realm} or
                not exists $self->{SECRET}->{$realm}->{$secret});
        $secret = $self->{SECRET}->{$realm}->{$secret}->{REF};
    } else {
        ##! 4: "the secret is not configured"
        $secret = undef;
    }
         
    eval {
        ##! 16: 'instantiating token, API class: ' . $backend_api_class . ' using backend ' . $backend_class
        $self->{TOKEN}->{$realm}->{$type}->{$name} =
                $backend_api_class->new ({
                    CLASS => $backend_class,
                    TMP   => $self->{tmp},
                    NAME  => $name,
                    TOKEN_TYPE => $type,
                    SECRET     => $secret,
                });
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        delete $self->{TOKEN}->{$realm}->{$type}->{$name}
            if (exists $self->{TOKEN}->{$realm}->{$type}->{$name});
        OpenXPKI::Exception->throw (
            message  => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_CREATE_FAILED",
            children => [ $exc ]);
    }
    elsif ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_EVAL_ERROR',
            params => {
                'EVAL_ERROR' => $EVAL_ERROR,
            }
        );
    }

    if (! defined $self->{TOKEN}->{$realm}->{$type}->{$name}) {
        delete $self->{TOKEN}->{$realm}->{$type}->{$name}
            if (exists $self->{TOKEN}->{$realm}->{$type}->{$name});
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_INIT_FAILED",
	    );
    }

    ##! 2: "$type token $name for $realm successfully added"
    return $self->{TOKEN}->{$realm}->{$type}->{$name};
}
 
sub __use_token
{
    ##! 16: 'start'
    my $self = shift;
    my $keys = { @_ };

    my $type  = $keys->{TYPE};
    my $name  = $keys->{NAME};
    my $realm = $keys->{PKI_REALM};
    
    my $instance; 
    if ($realm eq 'system') {
        $instance = $self->{TOKEN}->{system}->{$type};
    } else {
        $instance = $self->{TOKEN}->{$realm}->{$type}->{$name};
    }

    ## the token must be present
    if (not $instance) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_USE_TOKEN_NOT_PRESENT");
    } 
    
    return $instance->login()
        if (not $instance->online());

    return 1;
    ##! 16: 'end'
}

sub DESTROY {
    my $self = shift;

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::TokenManager

=head1 Description

This modules manages all cryptographic tokens. You can use it to simply
get tokens and to manage the state of a token.

=head1 Functions

=head2 new

If you want to
use an explicit temporary directory then you must specifiy this
directory in the variable TMPDIR.

=head2 get_token

needs TYPE, NAME and PKI_REALM of a token and will return a token which is ready to
use. Please remember that all tokens inside of one PKI realm need
distinguished names. The TYPE describes the use case of the token. This is required
to find the token configuration. TYPE can be today only CA and DEFAULT.

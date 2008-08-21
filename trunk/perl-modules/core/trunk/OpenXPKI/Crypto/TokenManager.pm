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

sub __load_secret_groups
{
    ##! 1: "start"
    my $self = shift;
    my $keys = shift;

    ##! 2: "get the arguments"
    my $realm = $keys->{PKI_REALM};
    ##! 16: 'realm: ' . $realm
    if (not $realm)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_LOAD_SECRET_GROUPS_MISSING_PKI_REALM");
    }

    ##! 2: "determine pki realm index"
    my $realm_index = $self->__get_list_member_by_id ({
                          XPATH    => ['pki_realm'],
                          COUNTER  => [],
                          ID_LABEL => 'name',
                          ID_VALUE => $realm});

    ##! 2: "load all groups"
    my $count = CTX('xml_config')->get_xpath_count (
                    XPATH   => [ 'pki_realm', 'common', 'secret', 'group' ],
                    COUNTER => [ $realm_index, 0, 0 ]);
    ##! 16: 'count: ' . $count
    for (my $i=0; $i < $count; $i++)
    {
        my $group = CTX('xml_config')->get_xpath (
                    XPATH   => [ 'pki_realm', 'common', 'secret', 'group', 'id' ],
                    COUNTER => [ $realm_index, 0, 0, $i, 0 ]);
        ##! 16: 'group: ' . $group
        $self->__load_secret ({PKI_REALM => $realm, GROUP => $group});
    }

    ##! 1: "finished: $count"
    $self->{SECRET_COUNT} = $count;
    return $count;
}

sub __load_secret
{
    ##! 1: "start"
    my $self = shift;
    my $keys = shift;

    ##! 2: "get the arguments"
    my $group  = $keys->{GROUP};
    my $realm  = $keys->{PKI_REALM};
    my $cfg_id = $keys->{CONFIG_ID};
    ##! 16: 'group: ' . $group
    ##! 16: 'realm: ' . $realm
    ##! 16: 'cfg_id: ' . $cfg_id

    if (not $realm)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_LOAD_SECRET_MISSING_PKI_REALM");
    }
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

    ##! 2: "get the position of the group configuration"

    my $realm_index = $self->__get_list_member_by_id ({
                          XPATH     => ['pki_realm'],
                          COUNTER   => [],
                          ID_LABEL  => 'name',
                          ID_VALUE  => $realm,
                          CONFIG_ID => $cfg_id,
    });
    my $group_index = $self->__get_list_member_by_id ({
                          XPATH     => ['pki_realm', 'common', 'secret', 'group'],
                          COUNTER   => [$realm_index, 0, 0],
                          ID_LABEL  => 'id',
                          ID_VALUE  => $group,
                          CONFIG_ID => $cfg_id,
    });

    ##! 2: "initialize secret object"
    my $method = CTX('xml_config')->get_xpath (
                          XPATH   => [ 'pki_realm', 'common', 'secret', 'group', 'method', 'id' ],
                          COUNTER => [ $realm_index, 0, 0, $group_index, 0, 0 ],
                          CONFIG_ID => $cfg_id,
    );
    $self->{SECRET}->{$realm}->{$group}->{TYPE}  = $method;
    $self->{SECRET}->{$realm}->{$group}->{LABEL} = 
        CTX('xml_config')->get_xpath (
                          XPATH   => [ 'pki_realm', 'common', 'secret', 'group', 'label' ],
                          COUNTER => [ $realm_index, 0, 0, $group_index, 0, 0 ],
                          CONFIG_ID => $cfg_id,
    );
    switch ($method)
    {
        case "literal" {
            my $value =
                CTX('xml_config')->get_xpath (
                    XPATH   => [ 'pki_realm', 'common', 'secret', 'group', 'method', 'value' ],
                    COUNTER => [ $realm_index, 0, 0, $group_index, 0, 0 ],
                    CONFIG_ID => $cfg_id,
                );
            $self->{SECRET}->{$realm}->{$group}->{REF} = OpenXPKI::Crypto::Secret->new ({TYPE => "Plain", PARTS => 1});
            $self->{SECRET}->{$realm}->{$group}->{REF}->set_secret ($value);
                         }
        case "plain"   {
            my $parts =
                CTX('xml_config')->get_xpath (
                    XPATH   => [ 'pki_realm', 'common', 'secret', 'group', 'method', 'total_shares' ],
                    COUNTER => [ $realm_index, 0, 0, $group_index, 0, 0 ],
                    CONFIG_ID => $cfg_id,
                );
            $self->{SECRET}->{$realm}->{$group}->{REF} = OpenXPKI::Crypto::Secret->new ({
                    TYPE => "Plain",
                    PARTS => $parts});
                         }
        case "split"   {
            my $total =
                CTX('xml_config')->get_xpath (
                    XPATH   => [ 'pki_realm', 'common', 'secret', 'group', 'method', 'total_shares' ],
                    COUNTER => [ $realm_index, 0, 0, $group_index, 0, 0 ],
                    CONFIG_ID => $cfg_id,
                );
            my $required =
                CTX('xml_config')->get_xpath (
                    XPATH   => [ 'pki_realm', 'common', 'secret', 'group', 'method', 'required_shares' ],
                    COUNTER => [ $realm_index, 0, 0, $group_index, 0, 0 ],
                    CONFIG_ID => $cfg_id,
                );
            my $default_token = $self->get_token(
                TYPE      => 'DEFAULT',
                PKI_REALM => $realm,
            );
            $self->{SECRET}->{$realm}->{$group}->{REF} = OpenXPKI::Crypto::Secret->new ({
                    TYPE => "Split",
                    QUORUM => { K => $required, N => $total },
                    TOKEN  => $default_token,
            });
                         }
        else {
              OpenXPKI::Exception->throw (
                  message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_LOAD_SECRET_WRONG_METHOD",
                  params  => {METHOD => $method});
             }
    }

    $self->__set_secret_from_cache({
        PKI_REALM => $realm,
        GROUP     => $group,
        CONFIG_ID => $cfg_id,
    });

    ##! 1: "finish"
    return 1;
}

sub __set_secret_from_cache {
    my $self    = shift;
    my $arg_ref = shift;

    my $realm  = $arg_ref->{'PKI_REALM'};
    my $group  = $arg_ref->{'GROUP'};
    my $cfg_id = $arg_ref->{'CONFIG_ID'};

    ##! 2: "get the position of the group configuration"

    my $realm_index = $self->__get_list_member_by_id ({
                          XPATH    => ['pki_realm'],
                          COUNTER  => [],
                          ID_LABEL => 'name',
                          ID_VALUE => $realm,
                          CONFIG_ID => $cfg_id });
    my $group_index = $self->__get_list_member_by_id ({
                          XPATH    => ['pki_realm', 'common', 'secret', 'group'],
                          COUNTER  => [$realm_index, 0, 0],
                          ID_LABEL => 'id',
                          ID_VALUE => $group,
                          CONFIG_ID => $cfg_id });
    ##! 2: "load cache configuration"
    $self->{SECRET}->{$realm}->{$group}->{CACHE} = 
        CTX('xml_config')->get_xpath (
            XPATH   => [ 'pki_realm', 'common', 'secret', 'group', 'cache', 'type' ],
            COUNTER => [ $realm_index, 0, 0, $group_index, 0, 0 ],
            CONFIG_ID => $cfg_id,
        );
    if ($self->{SECRET}->{$realm}->{$group}->{CACHE} ne "session" and
        $self->{SECRET}->{$realm}->{$group}->{CACHE} ne "daemon")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_LOAD_SECRET_WRONG_CACHE_TYPE",
                  params  => {TYPE => $self->{SECRET}->{$realm}->{$group}->{CACHE}});
    }
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
                                        PKI_REALM => $realm,
                                        GROUP_ID  => $group});
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

sub get_secret_groups
{
    ##! 1: "start"
    my $self = shift;

    ##! 2: "init"
    my $realm = CTX('session')->get_pki_realm();
    $self->__load_secret_groups({PKI_REALM => $realm})
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

sub reload_all_secret_groups_from_cache {
    ##! 1: 'start'
    my $self = shift;

    my $nr_of_realms = CTX('xml_config')->get_xpath_count(
        XPATH => 'pki_realm',
    );
    for (my $i = 0; $i < $nr_of_realms; $i++) {
        my $realm = CTX('xml_config')->get_xpath(
            XPATH   => [ 'pki_realm', 'name' ],
            COUNTER => [ $i         , 0      ],
        );
        ##! 16: 'realm: ' . $realm

        foreach my $group (keys %{$self->{SECRET}->{$realm}}) {
            ##! 16: 'group: ' . $group
            $self->__set_secret_from_cache({
                PKI_REALM => $realm,
                GROUP     => $group,
                CONFIG_ID => CTX('api')->get_current_config_id(),
            });
        }
    }
    
    ##! 1: 'end'
    return 1;
}

sub is_secret_group_complete
{
    ##! 1: "start"
    my $self  = shift;
    my $group = shift;

    ##! 2: "init"
    my $realm = CTX('session')->get_pki_realm();
    $self->__load_secret({PKI_REALM => $realm, GROUP => $group})
        if (not exists $self->{SECRET} or
            not exists $self->{SECRET}->{$realm} or
            not exists $self->{SECRET}->{$realm}->{$group});
    $self->__set_secret_from_cache({
        PKI_REALM => $realm,
        GROUP     => $group,
        CONFIG_ID => CTX('api')->get_current_config_id(),
    });

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
    $self->__load_secret({PKI_REALM => $realm, GROUP => $group})
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
                             PKI_REALM => $realm,
                             GROUP_ID  => $group});
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
    $self->__load_secret({PKI_REALM => $realm, GROUP => $group})
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
                             PKI_REALM => $realm,
                             GROUP_ID  => $group});
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

sub get_token
{
    my $self = shift;
    my $keys = { @_ };
    ##! 1: "start"

    my $type   = $keys->{TYPE};
    my $name   = $keys->{ID};
    my $realm  = $keys->{PKI_REALM};
    my $cert   = $keys->{CERTIFICATE};
    my $cfg_id = $keys->{CONFIG_ID};
    ##! 64: 'cfg_id: ' . $cfg_id

    if (not $type)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_TYPE");
    }
    $name = "default" if ($type  eq "DEFAULT");
    $name = "testcreatejavakeystore" if ($type eq 'CreateJavaKeystore');
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
        $self->__add_token(
            TYPE        => $type,
            NAME        => $name,
            PKI_REALM   => $realm,
            CERTIFICATE => $cert,
            CONFIG_ID   => $cfg_id,
        );
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

sub __add_token
{
    my $self = shift;
    my $keys = { @_ };
    ##! 1: "start"

    my $type   = $keys->{TYPE};
    my $name   = $keys->{NAME};
    my $realm  = $keys->{PKI_REALM};
    my $cert   = $keys->{CERTIFICATE};
    my $cfg_id = $keys->{CONFIG_ID};
    ##! 64: 'cfg_id: ' . $cfg_id

    ## build path from token type

    my $type_path = "";
    if ($type eq "CA")
    {
        $type_path = "ca";
    }
    elsif ($type eq 'SCEP')
    {
        $type_path = 'scep';
    }
    elsif ($type eq 'PASSWORD_SAFE')
    {
        $type_path = 'password_safe';
    }
    elsif ($type eq 'PKCS7')
    {
        $type_path = 'pkcs7';
    }
    elsif ($type eq 'CreateJavaKeystore')
    {
        $type_path = 'createjavakeystore';
    }
    elsif ($type eq "DEFAULT")
    {
        $type_path = "common";
    } else {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_INCORRECT_TYPE",
            params  => {"TYPE" => $type});
    }

    ## get matching pki_realm

    my $realm_index = $self->__get_list_member_by_id ({
                          XPATH     => ['pki_realm'],
                          COUNTER   => [],
                          ID_LABEL  => 'name',
                          ID_VALUE  => $realm,
                          CONFIG_ID => $cfg_id,
    });
 
    ## get matching type
    my $type_count = CTX('xml_config')->get_xpath_count (
                          XPATH     => [ 'pki_realm', $type_path ],
                          COUNTER   => [ $realm_index ],
                          CONFIG_ID => $cfg_id,
    );
    my $type_index;
    for (my $i=0; $i<$type_count; $i++)
    {
        ##! 4: "checking name of type"
        next if ($name ne CTX('xml_config')->get_xpath (
                              XPATH    => [ 'pki_realm', $type_path, 'id' ],
                              COUNTER  => [ $realm_index, $i, 0 ],
                              CONFIG_ID => $cfg_id));
        ##! 4: "pki_realm and name ok"
        $type_index = $i;
        last;
    }
    if (! defined $type_index)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_INCORRECT_NAME_OR_TYPE",
            params  => {"NAME" => $name, "TYPE" => $type});
    }

    ##! 2: "determine crypto backend"
    my $backend = CTX('xml_config')->get_xpath (
		XPATH     => [ 'pki_realm', $type_path, 'token', 'backend' ],
		COUNTER   => [ $realm_index, $type_index, 0, 0 ],
        CONFIG_ID => $cfg_id,
    );
    if (! defined $backend) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_BACKEND_UNDEFINED",
	    params  => {"NAME" => $name, 
			"TYPE" => $type, 
	    });
    }

    ##! 2: "determine secret group"
    my $secret;
    eval
    {
        ## try to get the secret
        ## the secret is not mandatory (e.g. default tokens)
        $secret = CTX('xml_config')->get_xpath (
                      XPATH     => [ 'pki_realm', $type_path, 'token', 'secret' ],
                      COUNTER   => [ $realm_index, $type_index, 0, 0 ],
                      CONFIG_ID => $cfg_id,
        );
    };
    if (not $EVAL_ERROR)
    {
        ##! 4: "secret is configured"
        if (! defined $secret) {
            OpenXPKI::Exception->throw (
                 message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_SECRET_UNDEFINED",
                 params  => {"NAME" => $name, 
                             "TYPE" => $type, 
                            });
        }
        $self->__load_secret({PKI_REALM => $realm, GROUP => $secret, CONFIG_ID => $cfg_id})
            if (not exists $self->{SECRET} or
                not exists $self->{SECRET}->{$realm} or
                not exists $self->{SECRET}->{$realm}->{$secret});
        $secret = $self->{SECRET}->{$realm}->{$secret}->{REF};
    } else {
        ##! 4: "the secret is not configured"
        $secret = undef;
    }

    ##! 2: "try to setup $backend token"
    eval {
        my $backend_api_class;
        if ($type eq 'SCEP') { # SCEP uses its own API
            $backend_api_class = 'OpenXPKI::Crypto::Tool::SCEP::API';
        }
        elsif ($type eq 'PKCS7') { # so does PKCS#7
            $backend_api_class = 'OpenXPKI::Crypto::Tool::PKCS7::API';
        }
        elsif ($type eq 'CreateJavaKeystore') { # so does nearly everyone
            $backend_api_class = 'OpenXPKI::Crypto::Tool::CreateJavaKeystore::API';
        }
        else { # use the 'default' backend
            $backend_api_class = 'OpenXPKI::Crypto::Backend::API';
        }
        ##! 16: 'instantiating token, API class: ' . $backend_api_class
        $self->{TOKEN}->{$realm}->{$type}->{$name} =
                $backend_api_class->new ({
                    CLASS => $backend,
                    TMP   => $self->{tmp},
                    NAME  => $name,
                    PKI_REALM_INDEX => $realm_index,
                    TOKEN_TYPE      => $type_path,
                    TOKEN_INDEX     => $type_index,
                    CERTIFICATE     => $cert,
                    SECRET          => $secret,
                    CONFIG_ID       => $cfg_id,
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

sub __get_list_member_by_id
{
    ##! 1: "start"
    my $self = shift;
    my $args = shift;
    my $xpath    = $args->{XPATH};
    my $counter  = $args->{COUNTER};
    my $id_label = $args->{ID_LABEL};
    my $id_value = $args->{ID_VALUE};
    my $cfg_id   = $args->{CONFIG_ID};
    ##! 64: 'cfg_id: ' . $cfg_id

    ##! 2: "get matching list member"

    my $count = CTX('xml_config')->get_xpath_count (
        XPATH     => $xpath,
        COUNTER   => $counter,
        CONFIG_ID => $cfg_id,
    );
    my $index = undef;
    for (my $i=0; $i<$count; $i++)
    {
        ##! 4: "checking id"
        next if ($id_value ne CTX('xml_config')->get_xpath (
                                  XPATH     => [ @{$xpath}, $id_label ],
                                  COUNTER   => [ @{$counter}, $i, 0 ],
                                  CONFIG_ID => $cfg_id));
        ##! 4: "pki_realm ok"
        $index = $i;
        last;
    }
    if (not defined $index)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_LIST_MEMBER_BY_ID_NOT_FOUND",
            params  => {
                "XPATH" => join (", ", @{$xpath}),
                COUNTER  => $args->{COUNTER},
                ID_LABEL => $args->{ID_LABEL},
                ID_VALUE => $args->{ID_VALUE},
                CFG_ID   => $args->{CONFIG_ID},
            }
        );
    }

    ##! 1: "finished: $index"
    return $index;
}
 
sub __use_token
{
    ##! 16: 'start'
    my $self = shift;
    my $keys = { @_ };

    my $type  = $keys->{TYPE};
    my $name  = $keys->{NAME};
    my $realm = $keys->{PKI_REALM};

    ## the token must be present

    if (! defined $self->{TOKEN}->{$realm}->{$type}->{$name}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_USE_TOKEN_NOT_PRESENT");
    } 

    my $instance = $self->{TOKEN}->{$realm}->{$type}->{$name};
    
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

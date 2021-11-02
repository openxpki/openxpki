package OpenXPKI::Server::Authentication;

use strict;
use warnings;
use utf8;

use English;
use OpenXPKI::Debug;
use Data::Dumper;
use Crypt::JWT qw(decode_jwt);
use Digest::SHA qw(sha1);
use MIME::Base64 qw(encode_base64url decode_base64);
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Server::Authentication::Handle;

# preload to get debug working
use  OpenXPKI::Server::Authentication::Base;
## constructor and destructor stuff

sub new {
    ##! 1: "start"
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys       = shift;

    $self->__load_config($keys);

    ##! 1: "end"
    return $self;
}

#############################################################################
##                         load the configuration                          ##
##                            (caching support)                            ##
#############################################################################

sub __load_config
{
    ##! 4: "start"
    my $self = shift;
    my $keys = shift;

    ##! 8: "load all PKI realms"

    my @realms = CTX('config')->get_keys('system.realms');

    foreach my $realm (@realms) {
        $self->__load_pki_realm ({
            PKI_REALM => $realm,
        });
    }

    ##! 4: "leaving function successfully"
    return 1;
}

sub __load_pki_realm
{
    ##! 4: "start"
    my $self   = shift;
    my $keys   = shift;
    my $realm  = $keys->{PKI_REALM};

    my $config = CTX('config');
    my $restore_realm = CTX('session')->data->pki_realm;

    # Fake Session for Config!
    CTX('session')->data->pki_realm( $realm );

    my %handlers;

    my @stacks = $config->get_keys(['auth','stack']);
    foreach my $stack (@stacks) {

        $self->{PKI_REALM}->{$realm}->{STACK}->{$stack} = {
            name => $stack,
            label => $stack, # might be overriden
        };

        foreach my $key ('label','description','type','logo') {
            my $val = $config->get(['auth','stack',$stack, $key]);
            next unless $val;
            $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{$key} = $val;
        }

        if (my $sign = $config->get_hash(['auth','stack',$stack,'sign'])) {
            my $pk = decode_base64($sign->{'key'});
            my $keyid = $sign->{'keyid'} || substr(encode_base64url(sha1($pk)),0,8);
            $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{keyid} = $keyid;
            $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{key} = \$pk;
        }

        ##! 8: "determine all used handlers"
        my @supported_handler = $config->get_scalar_as_list( ['auth','stack', $stack,'handler' ]);
        ##! 32: " supported_handler " . Dumper @supported_handler
        $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{handler} = \@supported_handler;

        # record the handler to be loaded later
        map { $handlers{$_} = 1; } @supported_handler;

    }

    foreach my $handler (keys %handlers) {
        $self->__load_handler ( $handler );
    }

    my @roles = CTX('config')->get_keys(['auth', 'roles']);
    foreach my $role (@roles) {
        $self->__load_tenant ( $role );
    }

    ##! 64: "Realm auth config " . Dumper $self->{PKI_REALM}->{$realm}

    CTX('session')->data->pki_realm( $restore_realm ) if $restore_realm;
    ##! 4: "end"
    return 1;
}

sub __load_handler
{
    ##! 4: "start"
    my $self  = shift;
    my $handler  = shift;

    my $realm = CTX('session')->data->pki_realm;
    my $config = CTX('config');

    ##! 8: "load handler type"

    my $type = $config->get(['auth','handler',$handler,'type']);

    OpenXPKI::Exception->throw (
        message => "No type given for authentication handler $handler"
    ) unless($type);

    $type =~ s/[^a-zA-Z0-9]//g;

    ##! 8: "name ::= $handler"
    ##! 8: "type ::= $type"
    my $class = "OpenXPKI::Server::Authentication::$type";
    eval "use $class;1";
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw (
            message => "Unable to load authentication handler class $type",
            params  => {ERRVAL => $EVAL_ERROR});
    }

    $self->{PKI_REALM}->{$realm}->{HANDLER}->{$handler} = $class->new( "auth.handler.$handler" );

    CTX('log')->auth()->info('Loaded auth handler ' . $handler);

    ##! 4: "end"
    return 1;
}

sub __load_tenant {

    ##! 4: "start"
    my $self  = shift;
    my $role  = shift;

    my $realm = CTX('session')->data->pki_realm;
    my $config = CTX('config');

    my $conf = $config->get_hash(['auth', 'roles', $role, 'tenant']);

    return unless ($conf);

    # always add the null handler if it does not exist
    if (!$self->{PKI_REALM}->{$realm}->{TENANT}->{_default}) {
        eval "use OpenXPKI::Server::AccessControl::Tenant::Null;1";
        $self->{PKI_REALM}->{$realm}->{TENANT}->{_default} = OpenXPKI::Server::AccessControl::Tenant::Null->new();
        CTX('log')->auth()->info('Loaded tenant null handler');
    }

    ##! 64: $conf
    # type or class must be defined
    my $class;
    # no tenant config defined for role, return null handler
    if ($conf->{class}) {
        $class = $conf->{class};
        delete $conf->{class};
    } elsif ($conf->{type}) {
        $class = 'OpenXPKI::Server::AccessControl::Tenant::'.$conf->{type};
        delete $conf->{type};
    } else {
        OpenXPKI::Exception->throw(
            message => 'Tenant handler has neither class nor type set',
            params => { role => $role, param => $conf }
        );
    }
    ##! 32: $class
    eval "use $class;1";
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw (
            message => "Unable to load access control handler class $class",
            params  => {ERRVAL => $EVAL_ERROR}
        );
    }

    $self->{PKI_REALM}->{$realm}->{TENANT}->{$role} = $class->new( %{$conf} );

    CTX('log')->auth()->info('Loaded tenant handler for role ' . $role);

    return 1;

}

########################################################################
##                          identify the user                         ##
########################################################################

sub list_authentication_stacks {
    my $self = shift;

    ##! 1: "start"

    ##! 2: "get PKI realm"
    my $realm = CTX('session')->data->pki_realm;
    my %ret = map {
        my %vv = %{$self->{PKI_REALM}->{$realm}->{STACK}->{$_}};
        delete $vv{handler};
        delete $vv{key};
        ($_ => \%vv);
    } keys %{$self->{PKI_REALM}->{$realm}->{STACK}};

    return \%ret;
}

sub __get_stack_info {

    ##! 1: "start"

    my $self = shift;
    my $stack = shift;
    my $realm = CTX('session')->data->pki_realm;

    CTX('log')->auth()->debug('Request stack info for ' . $stack);

    # no result at all usually means we even did not try to login
    # fetch the required "challenges" from the STACK!
    my $auth_type = $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{type};
    my $auth_param;
    if (!$auth_type) {
        ##! 8: "legacy config found for $stack"
        # for legacy handler / configs we call the first handler
        # to determine the type from the given service message
        my $handler = $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{handler}->[0];
        my $handlerClass = $self->{PKI_REALM}->{$realm}->{HANDLER}->{$handler};

        CTX('log')->deprecated()->error("Please add auth type to stack $stack");
        ##! 16: 'Handler is ' . $handler
        ##! 128: $handlerClass
        # custom handler using old pattern and old config - get type from login method
        if (!$handlerClass->isa('OpenXPKI::Server::Authentication::Base')) {
            ##! 32: 'Legacy class - call login_step'
            my ($user, $role, $return_msg) = $handlerClass->login_step({
                HANDLER => $handler,
                MESSAGE => { PARAMS => {}},
            });
            ##! 64: $return_msg
            my $auth_type = 'passwd';
            if ($return_msg->{SERVICE_MSG} eq 'GET_CLIENT_SSO_LOGIN') {
                $auth_type = 'client';
            } elsif ($return_msg->{SERVICE_MSG} eq 'GET_CLIENT_X509_LOGIN') {
                $auth_type = 'x509';
            }
            CTX('log')->auth()->debug("Determined auth type $auth_type from legacy handler");
            CTX('log')->deprecated()->error("Found old authentication handler for $handler - please upgrade");

        # get type based on class name for legacy configurations and migrated handlers
        } elsif ($handlerClass->isa('OpenXPKI::Server::Authentication::X509')) {
            ##! 32: 'Handler is x509 subclass'
            $auth_type = 'x509';
        } else {
            ##! 32: 'Handler is no special class, assign passwd'
            $auth_type = 'passwd';
        }
    } else {
        $auth_param = CTX('config')->get_hash(['auth','stack', $stack, 'param']);
        CTX('log')->auth()->trace("Handler $auth_type with params " . Dumper $auth_param) if CTX('log')->auth()->is_trace;
    }

    # we need to support this in the clients first but want to have it in the config already
    if ($auth_type eq 'anon') {
        $auth_type = 'passwd';
    }

    my $stack_reply = {
        type => $auth_type,
        params => ($auth_param //= {}),
    };

    if (my $keyid = $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{keyid}) {
        $stack_reply->{sign} = { keyid => $keyid };
    }

    ##! 8: "Auth Type $auth_type"
    ##! 32: $stack_reply
    return $stack_reply;

}

sub __legacy_login {

    ##! 8: "start"

    my $self = shift;
    my $handlerClass = shift;
    my $handler = shift;
    my $param = shift;

    my ($user, $role, $return_msg, $userinfo);

    # map back new keys to old keys in case somebody has an old handler
    $param->{LOGIN} //= $param->{username};
    $param->{PASSWD} //= $param->{password};
    # delete as it might show up in the userinfo otherwise
    delete $param->{password};
    eval {
        ($user, $role, $return_msg, $userinfo) = $handlerClass->login_step({
            HANDLER => $handler,
            MESSAGE => { PARAMS => $param },
        });
    };
    if ($EVAL_ERROR) {
        CTX('log')->auth()->debug("Login to $handler failed with error $EVAL_ERROR");
        return OpenXPKI::Server::Authentication::Handle->new(
            username => $param->{LOGIN} || 'unknown',
            userid => ($user || $param->{LOGIN} || 'unknown'),
            error => 128,
            error_message => "$EVAL_ERROR",
            handler => $handler,
        );
    }

    if ($user && $role) {
        return OpenXPKI::Server::Authentication::Handle->new(
            username => $user,
            userid => $user,
            role => $role,
            userinfo => $userinfo,
            handler => $handler,
        );
    }

    return;
}

sub login_step {

    ##! 1: "start"
    my $self    = shift;
    my $arg_ref = shift;

    ##! 128: $arg_ref
    my $param     = $arg_ref->{MESSAGE}->{PARAMS};
    my $stack   = $arg_ref->{STACK};
    my $realm   = CTX('session')->data->pki_realm;

    ##! 16: 'realm: ' . $realm
    ##! 16: 'stack: ' . $stack
    ##! 64: $param
    if (! exists $self->{PKI_REALM}->{$realm}->{STACK}->{$stack} ||
        ! scalar @{$self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{handler}}) {
        OpenXPKI::Exception->throw(
            message => "Got invalid authentication stack",
            params  => {
                STACK => $stack
            },
            log     => {
                priority => 'warn',
                facility => 'auth'
            },
        );
    }

    CTX('log')->auth()->debug('Incoming auth for stack ' . $stack);

    # empty request (incoming ping/stack info), no need to check authentication
    if (!defined $param || (ref $param && (scalar keys %{$param}) == 0)) {
        ##! 16: 'empty parameters'

    # stack requires signature
    } elsif (my $key = $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{key}) {
        OpenXPKI::Exception->throw(
            message => 'AuthStack configuration is broken - signature missing'
        ) if (ref $param);

        ##! 16: 'Incoming signature token, decoding'
        my $data;
        eval{$data = decode_jwt(token => $param, key => $key);};
        if ($EVAL_ERROR || !$data) {
            ##! 8: 'Got an error while decoding token'
            OpenXPKI::Exception->throw(
                message => 'AuthStack configuration is broken - decoding signature failed',
                params => { error => $EVAL_ERROR },
            );
        }
        ##! 32: $data
        OpenXPKI::Exception::Authentication->throw(
            message => 'I18N_OPENXPKI_UI_AUTHENTICATION_FAILED',
            params => { error => 'Replay Alert - session id does not match' },
            log     => { priority => 'error', facility => 'auth' }
        ) if ($data->{sid} ne CTX('session')->id);

        $param = $data->{param};

    } elsif (defined $param && !ref $param) {
        ##! 16: 'Unrequested signature token, decode without key'
        my $data = decode_jwt(token => $param, ignore_signature => 1);
        ##! 32: $data
        $param = $data->{param};

    } else {
        ##! 16: 'Default auth request - plain hash'
    }


    ##! 2: "try the different available handlers for the stack $stack"
    my $last_result;
  HANDLER:
    foreach my $handler (@{$self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{handler}}) {
        ##! 4: "handler $handler from stack $stack"
        my $handlerClass = $self->{PKI_REALM}->{$realm}->{HANDLER}->{$handler};

        OpenXPKI::Exception->throw (
            message => "Invalid handler given for stack",
            params  => {
                PKI_REALM => $realm,
                HANDLER => $handler,
            },
            log => {
                priority => 'error',
                facility => 'auth',
            }
        ) unless (ref $handlerClass);

        # The more modern classes inherit from this base class
        # so we test for it to fetch legacy implementations
        my $auth_result;
        if ($handlerClass->isa('OpenXPKI::Server::Authentication::Base')) {
            ##! 16: 'New handler'
            # just in case somebody wrote a custom login / client
            # we map back the old names to the new keys
            if (exists $param->{LOGIN}) {
                $param->{username} //= $param->{LOGIN};
                delete $param->{LOGIN};
            }
            if (exists $param->{PASSWD}) {
                $param->{password} //= $param->{PASSWD};
                delete $param->{PASSWD};
            }
            $auth_result = $handlerClass->handleInput( $param );
        } else {
            ##! 16: 'Legacy handler'
            # legacy stuff
            $auth_result = $self->__legacy_login( $handlerClass, $handler, $param);
        }

        # store the result if we got a result
        if ($auth_result) {
            ##! 8: 'Got auth result'
            ##! 64: Dumper $auth_result
            $last_result = $auth_result;
            # abort processing if the login was valid
            last HANDLER if ($auth_result->is_valid());
            CTX('log')->auth()->info('Got invalid auth result from handler ' . $handler);
            CTX('log')->auth()->debug($auth_result->error_message());
        }
    }

    ##! 16: Dumper $last_result
    # no result at all usually means we even did not try to login
    # fetch the required "challenges" from the STACK! We use the fast
    # path via the config layer - FIXME - check if we should cache this
    return $self->__get_stack_info($stack) unless ($last_result);

    # if we have a result but it is not valid we tried to log in but failed
    # we use the "old" exception pattern as we need to rework the error
    # handling first.....
    if (!$last_result->is_valid()) {
        CTX('log')->auth()->warn(sprintf('Login failed  (user: %s, error: %s)', $last_result->username() || 'not set', $last_result->error_message()));
        OpenXPKI::Exception::Authentication->throw(
            message => 'I18N_OPENXPKI_UI_AUTHENTICATION_FAILED',
            error => $last_result->error_message(),
            authinfo => $last_result->authinfo(),
        );
    }

    if ($self->has_tenant_handler( $last_result->role() ) && !$last_result->has_tenants()) {
        CTX('log')->auth()->error(sprintf('Login failed, no tenant information for user: %s, role: %s)', $last_result->username(), $last_result->role()));
        OpenXPKI::Exception::Authentication->throw(
            message => 'I18N_OPENXPKI_UI_AUTHENTICATION_FAILED_TENANT_REQUIRED',
            authinfo => $last_result->authinfo(),
            params => { username => $last_result->username(), role => $last_result->role() }
        );
    }

    CTX('log')->auth()->info(sprintf("Login successful (user: %s, role: %s)",
        $last_result->userid, $last_result->role));

    return $last_result;

};

sub has_tenant_handler {

    ##! 1: 'start'
    my $self = shift;

    my $role = shift;
    my $realm = CTX('session')->data->pki_realm;
    $role ||= (CTX('session')->data->role || 'Anonymous');

    return defined $self->{PKI_REALM}->{$realm}->{TENANT}->{$role};

}

sub tenant_handler {

    ##! 1: 'start'
    my $self = shift;

    my $role = shift;
    $role ||= (CTX('session')->data->role || 'Anonymous');
    ##! 8: 'role ' . $role
    my $realm = CTX('session')->data->pki_realm;

    # return the handler from the cache list by role or the null handler from _default
    return $self->{PKI_REALM}->{$realm}->{TENANT}->{$role} // $self->{PKI_REALM}->{$realm}->{TENANT}->{_default};
}

1;
__END__

=head1 Name

OpenXPKI::Server::Authentication

=head1 Description

This module is the top class of OpenXPKI's authentication
framework. Every authentication method is implemented in an
extra class but you only have to init this class and then
you have to call login if you need an authentication. The
XMl configuration and session handling is done via the servers
global context.

=head1 Functions

=head2 new

is the constructor and accepts no parameters.
If you call new then the complete
configuration is loaded. This makes it possible to cash
this object and to use login when it is required in a very
fast way.

=head2 login_step

is the function which performs the authentication.
Named parameters are STACK (the authentication stack to use)
and MESSAGE (the message received by the service).
It returns a triple (user, role, reply). The authentication
is not finished until user and role are defined. Multiple
calls can then be made until this state is achieved.
Reply is the reply message that is to be sent to the user
(i.e. a challenge, or the 'SERVICE_READY' message in case
the authentication has been successful).

=head2 has_tenant_handler

Return true/false if the given role (default session role) has a tenant
handler configured that needs to be used.

=head2 tenant_handler

Return the handler class that provides the filters and access
restrictions for multi-tenant setups. Handlers are bound to a role,
if you dont pass the role as parameter the value from the current
session is used.

Configuration for tenant handlers is done in I<auth.roles>:

    RA Operator:
        label: RA Operator
        # will load OpenXPKI::Server::AccessControl::Tenant::Base
        tenant:
            type: Base

    Local Registrar:
        label: Local Staff
        # will load OpenXPKI::Custom::TenantRules with "foo => bar"
        # passed to the constructor
        tenant:
            class: OpenXPKI::Custom::TenantRules
            foo: bar

=head1 See Also

OpenXPKI::Server::Authentication::Anonymous
OpenXPKI::Server::Authentication::ClientX509
OpenXPKI::Server::Authentication::Connector
OpenXPKI::Server::Authentication::NoAuth
OpenXPKI::Server::Authentication::OneTimePassword
OpenXPKI::Server::Authentication::Password

# OpenXPKI::Crypto::TokenManager.pm
## Rewritten 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2003-2006 by The OpenXPKI Project
package OpenXPKI::Crypto::TokenManager;

use strict;
use warnings;

use Carp;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;
use English;
use OpenXPKI::Crypto::Backend::API;
use OpenXPKI::Crypto::Tool::SCEP::API;
use OpenXPKI::Crypto::Tool::CreateJavaKeystore::API;
use OpenXPKI::Crypto::Secret;

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

=cut

sub new {
    ##! 1: 'start'
    my $that = shift;
    my $class = ref($that) || $that;

    my $caller_package = caller;

    my $self = {};

    bless $self, $class;

    my $keys = shift;
    $self->{tmp} = $keys->{TMPDIR} if ($keys->{TMPDIR});

    if ($caller_package ne 'OpenXPKI::Server::Init' and not ($ENV{TEST_ACTIVE} or $ENV{HARNESS_ACTIVE})) {
        # TokenManager instances shall only be created during
        # the server initialization, the rest of the code can
        # use CTX('crypto_layer') as its token manager
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOKENMANAGER_INSTANTIATION_OUTSIDE_SERVER_INIT',
            params => { 'CALLER' => $caller_package },
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
    my $realm = CTX('session')->data->pki_realm;

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
    my $method = $config->get(['crypto','secret',$group,'method']);
    my $label = $config->get(['crypto','secret',$group,'label']);
    my $export = $config->get(['crypto','secret',$group,'export']) || 0;

    $self->{SECRET}->{$realm}->{$group}->{TYPE}  = $method;
    $self->{SECRET}->{$realm}->{$group}->{LABEL} = ($label ? $label : $method);
    $self->{SECRET}->{$realm}->{$group}->{EXPORT}  = ($export ? 1 : 0);

    if ($method eq "literal") {
        my $value = $config->get(['crypto','secret',$group,'value']);
        $self->{SECRET}->{$realm}->{$group}->{REF} = OpenXPKI::Crypto::Secret->new ({TYPE => "Plain", PARTS => 1});
        $self->{SECRET}->{$realm}->{$group}->{REF}->set_secret ($value);
    }
    elsif ($method eq "plain") {
        my $total_shares = $config->get(['crypto','secret',$group,'total_shares']);
        $self->{SECRET}->{$realm}->{$group}->{REF} = OpenXPKI::Crypto::Secret->new ({
            TYPE => "Plain", PARTS => $total_shares
        });
    }
    elsif ($method eq "split") {

        my $total_shares = $config->get("crypto.secret.$group.total_shares");
        my $required_shares = $config->get("crypto.secret.$group.required_shares");
        $self->{SECRET}->{$realm}->{$group}->{REF} = OpenXPKI::Crypto::Secret->new ({
                TYPE => "Split",
                QUORUM => {
                    K => $required_shares,
                    N => $total_shares,
                },
                TOKEN  => $self->get_system_token({ TYPE => 'default'}),
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
    my $realm = CTX('session')->data->pki_realm;

    my $config = CTX('config');
    my $cache_config = $config->get("crypto.secret.$group.cache");

    ##! 2: "load cache configuration"
    if ($cache_config ne "session" and $cache_config ne "daemon")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_LOAD_SECRET_WRONG_CACHE_TYPE",
                  params  => {
                      TYPE => $cache_config,
                      GROUP => $group
                  });
    }

    $self->{SECRET}->{$realm}->{$group}->{CACHE} = $cache_config;

    ##! 2: "check for the cache"
    my $secret = "";
    if ($self->{SECRET}->{$realm}->{$group}->{CACHE} eq "session")
    {
        ## session mode
        ##! 4: "let's load the serialized secret in the session"
        $secret = CTX('session')->data->secret(group => $group);
        ##! 16: 'secret: ' . $secret
    } else {
        ## daemon mode
        ##! 4: "let's get the serialized secret from the database"
        my $row = CTX('dbi')->select_one(
            from    => "secret",
            columns => [ 'data' ],
            where => {
                pki_realm => $realm,
                group_id  => $group,
            }
        );
        $secret = $row->{data};
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
    my $realm = CTX('session')->data->pki_realm;
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

Reload the secrets for all realms.

FIXME: I think this is unnecessary or put in the wrong place (server init).
See #333

=cut

sub reload_all_secret_groups_from_cache {
    ##! 1: 'start'
    my $self = shift;

    my @realms = CTX('config')->get_keys('system.realms');
    foreach my $realm (@realms) {
        foreach my $group (keys %{$self->{SECRET}->{$realm}}) {
            ##! 16: 'group: ' . $group
            $self->__set_secret_from_cache({
                GROUP     => $group,
            });
        }
    }

    ##! 1: 'end'
    return 1;
}

=head2 is_secret_group_complete( group )

Check if the secret group is complete (all passwords loaded)

=cut

sub is_secret_group_complete
{
    ##! 1: "start"
    my $self  = shift;
    my $group = shift;

    ##! 2: "init"
    my $realm = CTX('session')->data->pki_realm;
    $self->__load_secret({ GROUP => $group})
        if (not exists $self->{SECRET} or
            not exists $self->{SECRET}->{$realm} or
            not exists $self->{SECRET}->{$realm}->{$group});

    $self->__set_secret_from_cache({
        GROUP     => $group,
    });

    ##! 1: "finished"
    return $self->{SECRET}->{$realm}->{$group}->{REF}->is_complete() ? 1 : 0;
}

=head2 get_secret( group )

Get the plaintext value of the stored secret. This requires that the
secret was created with the "export" flag set, otherwise an exception
is thrown. Returns undef if the secret is not complete.

=cut

sub get_secret
{
    ##! 1: "start"
    my $self  = shift;
    my $group = shift;

    if (!$self->is_secret_group_complete($group)) {
        return undef;
    }

    my $realm = CTX('session')->data->pki_realm;

    if (!$self->{SECRET}->{$realm}->{$group}->{EXPORT}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_SECRET_GROUP_NOT_EXPORTABLE");
    }

    return $self->{SECRET}->{$realm}->{$group}->{REF}->get_secret();

}

=head2 set_secret_group_part( { GROUP, VALUE, PART } )

Set the secret value of the given group, for plain secrets ommit PART.

=cut

sub set_secret_group_part
{
    ##! 1: "start"
    my $self  = shift;
    my $args  = shift;
    my $group = $args->{GROUP};
    my $part  = $args->{PART};
    my $value = $args->{VALUE};

    ##! 2: "init"
    my $realm = CTX('session')->data->pki_realm;
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
    if ($self->{SECRET}->{$realm}->{$group}->{CACHE} eq "session") {
        ##! 4: "store secret in session"
        CTX('session')->data->secret(group  => $group, value => $secret);
        CTX('session')->persist;
    } else {
        ##! 4: "merge secret into database"
        CTX('dbi')->merge(
            into => "secret",
            set  => { data => $secret },
            where => {
                pki_realm => $realm,
                group_id  => $group,
            },
        );
    }

    ##! 1: "finished"
    return 1;
}

=head2 clear_secret_group( group )

Purge the secret for the given group.

=cut

sub clear_secret_group
{
    ##! 1: "start"
    my $self  = shift;
    my $group = shift;

    ##! 2: "init"
    my $realm = CTX('session')->data->pki_realm;
    $self->__load_secret({ GROUP => $group})
        if (not exists $self->{SECRET} or
            not exists $self->{SECRET}->{$realm} or
            not exists $self->{SECRET}->{$realm}->{$group});

    ##! 2: "check for the cache"
    if ($self->{SECRET}->{$realm}->{$group}->{CACHE} eq "session") {
        ##! 4: "delete secret in session"
        CTX('session')->clear_secret($group);
    }
    else {
        ##! 4: "delete secret in database"
        my $result = CTX('dbi')->delete(
            from => "secret",
            where => {
                pki_realm => $realm,
                group_id  => $group,
            }
        );
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

=head2 get_token( { TYPE, NAME, CERTIFICATE } )

Get a crypto token to execute commands for the current realm

=over

=item TYPE

Determines the used API, one of the values given in
system.crypto.tokenapi (certsign, crlsign, datasafe....)

=item NAME

The name of the token to initialize, for versioned tokens
including the generation identifier, e.g. server-ca-2.

=item CERTIFICATE

A hashref as returned by API::Token::get_certificate_for_alias.
Can be omitted, if the API can resolve the given name.

=back

=cut

sub get_token {
    my ($self, $keys) = @_;
    ##! 1: "start"

    croak("parameter must be hash ref, but got '$keys'") unless ref($keys) eq 'HASH';

    #my $name   = $keys->{ID};
    my $type   = $keys->{TYPE};
    my $name   = $keys->{NAME};

    my $realm = CTX('session')->data->pki_realm;

    ##! 32: "Load token $name of type $type"
    OpenXPKI::Exception->throw(message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_TYPE")
        unless $type;
    OpenXPKI::Exception->throw(message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_NAME")
        unless $name;
    OpenXPKI::Exception->throw(message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_PKI_REALM")
        unless $realm;
    ##! 2: "$realm: $type -> $name"

    $self->__add_token($keys)
        unless $self->{TOKEN}->{$realm}->{$type}->{$name};

    OpenXPKI::Exception->throw(message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_EXIST")
        unless $self->{TOKEN}->{$realm}->{$type}->{$name};
    ##! 2: "token is present"

    OpenXPKI::Exception->throw(message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_USABLE")
        unless $self->__use_token(TYPE => $type, NAME => $name, PKI_REALM => $realm);
    ##! 2: "token is usable"

    return $self->{TOKEN}->{$realm}->{$type}->{$name};
}

=head2 get_system_token( { TYPE } )

Get a crypto token from the system namespace. This includes all non-realm
dependend tokens which dont have key material attached.

The tokens are defined in the system.crypto.token namespace.
Common tokens are default and javaks.
You neeed to specify at least C<api> and C<backend> for all tokens.

=cut

sub get_system_token {
    my ($self, $keys) = @_;
    ##! 1: "start"

    my $type   = lc($keys->{TYPE});

    ##! 32: "Load token system of type $type"
    OpenXPKI::Exception->throw(message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_SYSTEM_TOKEN_MISSING_TYPE")
        unless $type;

    my $config = CTX('config');
    my $backend = $config->get("system.crypto.token.$type.backend");

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_SYSTEM_TOKEN_UNKNOWN_TYPE",
        params => { TYPE => $type }
    ) unless $backend;

    if (not $self->{TOKEN}->{system}->{$type}) {
        my $backend_api_class = CTX('config')->get("system.crypto.token.$type.api");

        ##! 16: 'instantiating token, API:' . $backend_api_class . ' - Backend: ' .$backend
        $self->{TOKEN}->{system}->{$type} = $backend_api_class->new({
            CLASS => $backend,
            TMP   => $self->{tmp},
            TOKEN_TYPE => $type,
        });
    }
    ##! 2: "token added"

    OpenXPKI::Exception->throw(message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_EXIST")
        unless $self->{TOKEN}->{system}->{$type};
    ##! 2: "token is present"

    OpenXPKI::Exception->throw(message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_USABLE")
        unless $self->__use_token(TYPE => $type, PKI_REALM => 'system');
    ##! 2: "token is usable"

    return $self->{TOKEN}->{system}->{$type};

}

sub __add_token {
    my ($self, $keys) = @_;
    ##! 1: "start"

    my $type   = $keys->{TYPE};
    my $name   = $keys->{NAME};
    my $realm = CTX('session')->data->pki_realm;
    my $config = CTX('config');

    my $backend_class;
    my $secret;

    ##! 16: "add token type $type, name: $name"
    my $backend_api_class = $config->get("system.crypto.tokenapi.$type");
    $backend_api_class = "OpenXPKI::Crypto::Backend::API" unless ($backend_api_class);

    my $config_name_group = $name;
    # Magic inheritance code
    # tokens have generations and we want to map a generation identifier to its base group.
    # The generation tag is always a suffix "-X" where X is a decimal

    # A token config must have at least a backend (inherit is done by the connector)
    $backend_class = $config->get_inherit("crypto.token.$name.backend");

    # Nothing found with the full token name, so try to load from the group name
    if (!$backend_class) {
        $config_name_group =~ /^(.+)-(\d+)$/;
        $config_name_group = $1;
        ##! 16: 'use group config ' . $config_name_group
        $backend_class = $config->get_inherit("crypto.token.$config_name_group.backend");
    }

    if (not $backend_class)  {
        OpenXPKI::Exception->throw (
            message  => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_NO_BACKEND_CLASS",
            params => { TYPE => $type, NAME => $name, GROUP => $config_name_group}
        );
    }

    $secret = $config->get_inherit("crypto.token.$config_name_group.secret");

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
                CLASS       => $backend_class,
                TMP         => $self->{tmp},
                NAME        => $name,
                TOKEN_TYPE  => $type,
                SECRET      => $secret,
                CERTIFICATE => $keys->{CERTIFICATE},
            });
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
        delete $self->{TOKEN}->{$realm}->{$type}->{$name}
            if (exists $self->{TOKEN}->{$realm}->{$type}->{$name});
        OpenXPKI::Exception->throw (
            message  => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_CREATE_FAILED",
            children => [ $exc ],
        );
    }
    elsif ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_EVAL_ERROR',
            params => {
                'EVAL_ERROR' => Dumper $EVAL_ERROR,
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

sub __use_token {
    my $self = shift;
    my $keys = { @_ };
    ##! 16: 'start'

    my $type  = $keys->{TYPE};
    my $name  = $keys->{NAME};
    my $realm = $keys->{PKI_REALM};

    my $instance;
    if ($realm eq 'system') {
        $instance = $self->{TOKEN}->{system}->{$type};
    }
    else {
        $instance = $self->{TOKEN}->{$realm}->{$type}->{$name};
    }

    ## the token must be present
    OpenXPKI::Exception->throw(message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_USE_TOKEN_NOT_PRESENT")
        unless $instance;

    return $instance->login()
        unless $instance->online();

    return 1;
    ##! 16: 'end'
}

1;
__END__


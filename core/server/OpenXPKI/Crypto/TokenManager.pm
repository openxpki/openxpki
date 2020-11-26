package OpenXPKI::Crypto::TokenManager;
use strict;
use warnings;

# Core modules
use Carp;
use Data::Dumper;
use English;
use Module::Load ();

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::SecretManager;

=head1 Name

OpenXPKI::Crypto::TokenManager

=head1 Description

This module manages all cryptographic tokens. You can use it to simply
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

    $self->{secret_manager} = OpenXPKI::Crypto::SecretManager->new(
        default_token => $self->get_system_token({ TYPE => 'default'}),
    );

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

sub get_secret_infos            { return shift->{secret_manager}->get_infos(@_) }
sub is_secret_complete          { return shift->{secret_manager}->is_complete(@_) }
sub get_secret_required_part_count { return shift->{secret_manager}->get_required_part_count(@_) }
sub get_secret_inserted_part_count { return shift->{secret_manager}->get_inserted_part_count(@_) }
sub get_secret                  { return shift->{secret_manager}->get_secret(@_) }
sub set_secret_part             { return shift->{secret_manager}->set_part(@_) }
sub clear_secret                { return shift->{secret_manager}->clear(@_) }
sub request_secret_transfer     { return shift->{secret_manager}->request_transfer(@_) }
sub transfer_secret_groups      { return shift->{secret_manager}->perform_transfer(@_) }
sub accept_secret_transfer      { return shift->{secret_manager}->accept_transfer(@_) }


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

        eval { Module::Load::autoload($backend_api_class) };
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_FAILED_LOADING_BACKEND_API_CLASS",
            params => { class_name => $backend_api_class, message => $@ }
        ) if $@;

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

    OpenXPKI::Exception->throw (
        message  => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_NO_BACKEND_CLASS",
        params => { TYPE => $type, NAME => $name, GROUP => $config_name_group}
    ) unless $backend_class;

    eval { Module::Load::autoload($backend_class); Module::Load::autoload($backend_api_class); };
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_FAILED_LOADING_BACKEND_CLASS",
        params => { class_name => $backend_class, message => $@ }
    ) if $@;

    my $secret_alias = $config->get_inherit("crypto.token.$config_name_group.secret");

    ##! 16: "Token backend: $backend_class, Secret group: $secret_alias"

    ##! 2: "determine secret group"
    if ($secret_alias) {
        ##! 4: "secret is configured"
        $secret = $self->{secret_manager}->_get_secret_def($secret_alias)->{_ref};
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

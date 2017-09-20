## OpenXPKI::Server::API::Token.pm
##
## Written 2012 by Oliver Welter for the OpenXPKI project
## Copyright (C) 2012 by The OpenXPKI Project

=head1 NAME

OpenXPKI::Server::API::Token

=head1 Description

API methods for finding and accessing tokens from the crypto layer.

=cut

package OpenXPKI::Server::API::Token;

use strict;
use warnings;
use utf8;
use English;

# Core modules
use Data::Dumper;
use Digest::SHA qw( sha1_base64 );
use Scalar::Util qw( blessed );

# CPAN modules
use Class::Std;
use DateTime;
use Workflow;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::i18n qw( set_language );



sub START {

    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw( message =>
          'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED', );
}

# API: simple retrieval functions

=head2 get_default_token()

Return the default token from the system namespace.

=cut

sub get_default_token {
    ##! 1: 'start'
    return CTX('crypto_layer')->get_system_token({ TYPE => "DEFAULT" });
}

=head2 get_token_alias_by_type( { TYPE, VALIDITY } )

Return the name of the "best" token for the given token type.

Looks up the token group for that type at realm.crypto.type
and calls C<get_token_alias_by_group>.

=cut

sub get_token_alias_by_type {

    ##! 1: 'start'
    my $self = shift;
    my $keys = shift;

   if (not $keys->{TYPE}) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_API_TOKEN_ALIAS_BY_TYPE_NO_TYPE_GIVEN',
        );
    }

    ##! 32: "Lookup group for type $keys->{TYPE}"
    $keys->{GROUP} = CTX('config')->get("crypto.type.".$keys->{TYPE});

   if (not $keys->{GROUP}) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_API_TOKEN_ALIAS_BY_TYPE_NO_GROUP_FOUND',
            params => { TYPE => $keys->{TYPE} }
        );
    }
    delete $keys->{TYPE};

    ##! 32: " Found keys " . Dumper ($keys)

    return $self->get_token_alias_by_group($keys);
}


=head2 get_token_alias_by_group( { GROUP, VALIDITY } )

Return the name of the "best" token for the given token group.

By default, the best match is the token with the newest notbefore date, that
is usable now. You can specify an alternative time frame using the VALIDITY
parameter. It can hold two datetime objects, given as named parameter
notbefore and notafter. The method will try to find the newest token which can
sign a request with the given validity. Undef values default to now.

=cut

sub get_token_alias_by_group {
    my ($self, $keys) = @_;
    ##! 1: 'start'
    my $group  = $keys->{GROUP} or OpenXPKI::Exception->throw (
        message => 'I18N_OPENXPKI_API_TOKEN_GET_TOKEN_ALIAS_BY_GROUP_NO_GROUP',
    );
    my $pki_realm = CTX('session')->data->pki_realm;
    ##! 16: "Find token for group $group in realm $pki_realm"

    my $validity = $self->_validity_param_to_epoch($keys->{VALIDITY});

    my $alias = CTX('dbi')->select_one(
        from => 'aliases',
        columns => [ 'alias' ],
        where => {
            pki_realm => $pki_realm,
            group_id  => $group,
            notbefore => { '<' => $validity->{notbefore} },
            notafter  => { '>' => $validity->{notafter} },
        },
        order_by => [ '-notbefore' ],
    )
    or OpenXPKI::Exception->throw (
        message => 'I18N_OPENXPKI_API_TOKEN_GET_TOKEN_ALIAS_BY_GROUP_NO_RESULT',
        params => {
            'GROUP'     => $group,
            'NOTBEFORE' => $validity->{notbefore},
            'NOAFTER'   => $validity->{notafter},
            'PKI_REALM' => $pki_realm
        }
    );

    ##! 16: "Suggesting $alias->{'alias'} as best match"
    return $alias->{alias};

}

=head2 get_certificate_for_alias( { ALIAS } )

Find the certificate for the given alias. Returns a hashref with the
PEM encoded certificate (DATA), Subject (SUBJECT), Identifier (IDENTIFIER)
and NOTBEFORE/NOTAFTER as epoch. Dates are the real certificate dates!

=cut

sub get_certificate_for_alias {
    my ($self, $keys) = @_;
    ##! 1: 'start'

    OpenXPKI::Exception->throw (
        message => 'I18N_OPENXPKI_API_TOKEN_GET_CERTIFICATE_NO_ALIAS_GIVEN',
    ) unless $keys->{ALIAS};

    my $pki_realm = CTX('session')->data->pki_realm;
    ##! 32: "Search for alias $keys->{ALIAS}"
    my $certificate = CTX('dbi')->select_one(
        from_join => 'certificate identifier=identifier aliases',
        columns => [
            'certificate.data',
            'certificate.subject',
            'certificate.identifier',
            'certificate.notbefore',
            'certificate.notafter',
        ],
        where => {
            'aliases.alias'     => $keys->{ALIAS},
            'aliases.pki_realm' => $pki_realm,
        }
    )
    or OpenXPKI::Exception->throw (
        message => 'I18N_OPENXPKI_API_TOKEN_GET_CERTIFICATE_NOT_FOUND_FOR_ALIAS',
        params => { ALIAS => $keys->{ALIAS} }
    );
    ##! 32: "Found certificate $certificate->{subject}"
    ##! 64: "Found certificate " . Dumper $certificate
    return {
        DATA        => $certificate->{data},
        SUBJECT     => $certificate->{subject},
        IDENTIFIER  => $certificate->{identifier},
        NOTBEFORE   => $certificate->{notbefore},
        NOTAFTER    => $certificate->{notafter},
    };

}

=head2 list_active_aliases( { GROUP, VALIDITY, PKI_REALM, TYPE, CHECK_ONLINE } )

Get an arrayref with all tokens from the given GROUP, which are/were valid within
the validity period given by the VALIDITY parameter.
Each entry of the list is a hashref holding the full alias name and the
certificate identifier. The list is sorted by notbefore date, starting with
the newest date. See get_token_alias_by_group how validity works, dates are custom
dates from the alias table!
PKI_REALM is optional and defaults to the session's realm.
If you are looking for a predefined token, you can specify TYPE instead of GROUP.

If you set CHECK_ONLINE the is_token_usable method will be called for each
alias and the result of the check is included in the key STATUS

=cut

sub list_active_aliases {
    my ($self, $keys) = @_;
    ##! 1: 'start'
    my $group = $keys->{GROUP};
    my $type = $keys->{TYPE};
    my $pki_realm = $keys->{PKI_REALM} // CTX('session')->data->pki_realm;

    if (not $group) {
       $group = CTX('config')->get("realm.$pki_realm.crypto.type.$type") if $type;
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_API_TOKEN_GET_TOKEN_ALIAS_BY_GROUP_NO_GROUP',
        ) unless $group;
    }

    my $validity = $self->_validity_param_to_epoch($keys->{VALIDITY});

    my $aliases = CTX('dbi')->select(
        from => 'aliases',
        columns => [
            'aliases.notbefore',
            'aliases.notafter',
            'aliases.alias',
            'aliases.identifier',
        ],
        where => {
            'aliases.pki_realm' => $pki_realm,
            'aliases.group_id'  => $group,
            'aliases.notbefore' => { '<' => $validity->{notbefore} },
            'aliases.notafter'  => { '>' => $validity->{notafter} },
        },
        order_by => [ '-aliases.notbefore' ],
    );

    my @result;
    while (my $row = $aliases->fetchrow_hashref) {
        my $item = {
            ALIAS => $row->{alias},
            IDENTIFIER => $row->{identifier},
            NOTBEFORE => $row->{notbefore},
            NOTAFTER  => $row->{notafter},
        };
        if ($keys->{CHECK_ONLINE}) {
            $item->{STATUS} = $self->is_token_usable({ ALIAS => $row->{alias} })
                ? 'ONLINE'
                : 'OFFLINE';
        }
        push @result, $item;
    }
    ##! 32: "Found tokens " . Dumper @token

    return \@result;

}

=head2 get_ca_list( {PKI_REALM} )

List all items in the certsign group of the requested REALM.
REALM is optional and defaults to the session realm.
Each entry of the list is a hashref holding the full alias name (ALIAS),
the certificate identifier (IDENTIFIER), the notbefore/notafter date,
the subject and the verbose status of the token. Possbile status values
are EXPIRED, UPCOMING, ONLINE, OFFLINE OR UNKNOWN. The ONLINE/OFFLINE
check is only possible from within the current realm, for requests outside
the current realm the status of a valid token is always UNKNOWN.

The list is sorted by notbefore date, starting with the newest date.
Dates are taken from the alias table and therefore might differ
from the certificates validity!

=cut

sub get_ca_list {
    ##! 1: "start"

    my $self = shift;
    my $keys = shift;

    my $pki_realm = $keys->{PKI_REALM};
    my $session_pki_realm = CTX('session')->data->pki_realm;
    if (!$pki_realm) {
        $pki_realm = $session_pki_realm;
    }

    ##! 32: "Lookup group name for certsign"
    my $group = CTX('config')->get(['realm', $pki_realm, 'crypto', 'type', 'certsign']);

    my $db_results = CTX('dbi')->select(
        from_join => 'certificate identifier=identifier aliases',
        columns => [
            'certificate.data',
            'certificate.subject',
            'aliases.notbefore',
            'aliases.notafter',
            'aliases.alias',
            'aliases.identifier',
        ],
        where => {
            'aliases.pki_realm' => $pki_realm,
            'aliases.group_id'  => $group,
        },
        order_by => [ '-aliases.notbefore' ],
    );

    my @token;
    while (my $row = $db_results->fetchrow_hashref) {
        my $item = {
            ALIAS       => $row->{alias},
            IDENTIFIER  => $row->{identifier},
            SUBJECT     => $row->{subject},
            NOTBEFORE   => $row->{notbefore},
            NOTAFTER    => $row->{notafter},
            STATUS      => 'UNKNOWN'
        };

        # Check if the token is still valid - dates are already unix timestamps
        my $now = time;
        if ($row->{notbefore} > $now) {
            $item->{STATUS} = 'UPCOMING';
        } elsif ($row->{notafter} < $now) {
            $item->{STATUS} = 'EXPIRED';
        } elsif ($pki_realm eq $session_pki_realm) {
            # Check if the key is usable, only in current realm
            my $token;
            eval {
                $token = CTX('crypto_layer')->get_token({
                    TYPE => 'certsign',
                    NAME => $row->{alias},
                    CERTIFICATE => {
                        DATA => $row->{data},
                        IDENTIFIER => $row->{identifier},
                    }
                } );
                $item->{STATUS} = $self->is_token_usable({ TOKEN => $token })
                    ? 'ONLINE'
                    : 'OFFLINE';
            };
            if ($EVAL_ERROR) {
                CTX('log')->application()->error("Eval error getting ca token ".$row->{alias}." for ca_list");
            }

        }

        push @token, $item;
    }
    ##! 32: "Found tokens " . Dumper @token

    ##! 1: 'Finished'
    return \@token;
}


=head2 get_trust_anchors ( { PATH } )

Get the trust anchors as defined at the given config path.
Expects the config path to point to a structure like:

    path:
        realm:
        - ca-one
        cacert:
        - list of extra cert identifiers

Result is an arrayref of certificate identifiers.

=cut

sub get_trust_anchors {

    my $self = shift;

    my $args = shift;
    my $path = $args->{PATH};

    OpenXPKI::Exception->throw (
        message => 'I18N_OPENXPKI_API_TOKEN_GET_TRUST_ANCHOR_NO_PATH',
    ) unless($path);

    my $config = CTX('config');
    my @trust_certs =  $config->get_scalar_as_list("$path.cacert");
    my @trust_realms = $config->get_scalar_as_list("$path.realm");

    ##! 8: 'Trusted Certs ' . Dumper @trust_certs
    ##! 8: 'Trusted Realm ' . Dumper @trust_realms

    my @trust_anchors;

    @trust_anchors = @trust_certs if (@trust_certs);

    foreach my $trust_realm (@trust_realms) {
        ##! 16: 'Load ca signers from realm ' . $trust_realm
        next unless $trust_realm;
        my $ca_certs = CTX('api')->list_active_aliases({ TYPE => 'certsign', PKI_REALM => $trust_realm });
        ##! 16: 'ca cert in realm ' . Dumper $ca_certs
        if (!$ca_certs) { next; }
        push @trust_anchors, map { $_->{IDENTIFIER} } @{$ca_certs};
    }

   return \@trust_anchors;

}


=head2 is_token_usable ( { ALIAS | TOKEN, ENGINE })

Check if the token with given alias is usable, when used inline you can
directly pass the token object instead of the alias. By default, the method
executes a pkcs7 encrypt / decrypt cycle to test if the token is working.
If you pass ENGINE = 1, the engines key_usable method is used instead.
Returns true or false.

=cut
sub is_token_usable {

    my $self = shift;
    my $keys = shift;

    my $token;
    if ($keys->{ALIAS}) {
        my %types = reverse %{CTX('config')->get_hash('crypto.type')};
        # strip of the generation
        $keys->{ALIAS} =~ /^(.*)-(\d+)$/;
        if (!$1 || !$types{$1}) {
            OpenXPKI::Exception->throw (
                message => 'I18N_OPENXPKI_API_TOKEN_IS_TOKEN_USABLE_UNABLE_TO_GET_TOKEN_TYPE',
            );
        }
        $token = CTX('crypto_layer')->get_token({ TYPE => $types{$1}, NAME => $keys->{ALIAS} });
    } elsif ($keys->{TOKEN}) {
        $token = $keys->{TOKEN};
    } else {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_API_TOKEN_IS_TOKEN_USABLE_TOKEN_OR_ALIAS_REQURIED',
        );
    }

    # Shortcut method, ask the token engine
    if ($keys->{ENGINE}) {
        CTX('log')->application()->debug('Check if token is usable using engine');

        return $token->key_usable()
    }

    eval {

        CTX('log')->application()->debug('Check if token is usable using crypto operation');


        my $probe = 'OpenXPKI Encryption Test';

        my $value = $token->command({
            COMMAND => 'pkcs7_encrypt',
            CONTENT => $probe,
        });

        ##! 16: 'encryption done'

        $value = $token->command({
            COMMAND => 'pkcs7_decrypt',
            PKCS7   => $value,
        });

        ##! 16: 'decryption done'
        if (!defined $probe || $value ne $probe) {
            OpenXPKI::Exception->throw (
                message => 'I18N_OPENXPKI_API_TOKEN_IS_TOKEN_USABLE_VALUE_MISSMATCH',
            );
        }
        ##! 16: 'probe matches'
    };
    if (my $eval_err = $EVAL_ERROR) {
        ##! 16: 'got eval error ' . $eval_err
        return 0;
    }

    ##! 16: 'key is online'
    return 1;

}

#
# Expects undef or DateTime objects in a HashRef like this:
#    {
#        NOTBEFORE => DateTime->new(year => 1980, month => 12, day => 1),
#        NOTAFTER => undef, # means: now
#    }
#
# and converts it to:
#    {
#        notbefore => 344476800,
#        notafter => 1491328939,
#    }
#
sub _validity_param_to_epoch {
    my ($self, $validity) = @_;
    my $result = {};

    for my $key (qw(notbefore notafter) ) {
        my $value = $validity->{uc($key)};
        OpenXPKI::Exception->throw(
            message => 'Values in VALIDITY must be specified as DateTime object',
            params => { key => uc($key), type => blessed($value) },
        ) unless (not defined $value or (defined blessed($value) and $value->isa('DateTime')));
        $result->{$key} = $value ? $value->epoch : time;
    }

    return $result;
}

1;

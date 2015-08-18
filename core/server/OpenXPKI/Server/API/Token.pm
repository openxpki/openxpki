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

use Class::Std;

use Data::Dumper;

#use Regexp::Common;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::i18n qw( set_language );
use Digest::SHA qw( sha1_base64 );
use DateTime;

use Workflow;

sub START {

    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw( message =>
          'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED', );
}

# API: simple retrieval functions

=head2 get_default_token( { PKI_REALM } )

Return the default token for the given realm, if omitted the current realm.

=cut

sub get_default_token {

    ##! 1: 'start'
    my $self = shift;
    my $keys = shift;

    my $pki_realm = $keys->{PKI_REALM};
    if ( !$pki_realm ) {
        $pki_realm = CTX('session')->get_pki_realm();
    }

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

    ##! 1: 'start'
    my $self = shift;
    my $keys = shift;

    my $group  = $keys->{GROUP};

    if (!$group) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_API_TOKEN_GET_TOKEN_ALIAS_BY_GROUP_NO_GROUP',
        );
    }

    my $pki_realm = CTX('session')->get_pki_realm();

    ##! 16: "Find token for group $group in realm $pki_realm"

    my %validity;
    foreach my $key (qw(notbefore notafter) ) {
        if ($keys->{VALIDITY}->{NOTBEFORE}) {
            $validity{$key} = $keys->{VALIDITY}->{uc($key)}->epoch();
        } else {
            $validity{$key} = time();
        }
    }

    my $alias = CTX('dbi_backend')->first(
        TABLE   => 'ALIASES',
        COLUMNS => [
            'NOTBEFORE', # Necessary to use the column in ordering - FIXME: Pimp SQL Layer
            'ALIAS',
        ],
        DYNAMIC => {
            'PKI_REALM' => { VALUE => $pki_realm },
            'GROUP_ID' => { VALUE => $group },
            'NOTBEFORE' => { VALUE => $validity{notbefore}, OPERATOR => 'LESS_THAN' },
            'NOTAFTER' => { VALUE => $validity{notafter}, OPERATOR => 'GREATER_THAN' },
        },
        'ORDER' => [ 'NOTBEFORE' ],
        'REVERSE' => 1,
    );

    if (!$alias->{'ALIAS'}) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_API_TOKEN_GET_TOKEN_ALIAS_BY_GROUP_NO_RESULT',
            params => {
                'GROUP' => $group,
                'NOTBEFORE' => $validity{notbefore},
                'NOAFTER' => $validity{notafter},
                'PKI_REALM' => $pki_realm
            }
        );
    }

    ##! 16: "Suggesting $alias->{'ALIAS'} as best match"
    return $alias->{'ALIAS'};

}

=head2 get_certificate_for_alias( { ALIAS } )

Find the certificate for the given alias. Returns a hashref with the
PEM encoded certificate (DATA), Subject (SUBJECT), Identifier (IDENTIFIER)
and NOTBEFORE/NOTAFTER as epoch. Dates are the real certificate dates!

=cut

sub get_certificate_for_alias {

    ##! 1: 'start'
    my $self = shift;
    my $keys = shift;

    if (not $keys->{ALIAS}) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_API_TOKEN_GET_CERTIFICATE_NO_ALIAS_GIVEN',
        );
    }

    my $pki_realm = CTX('session')->get_pki_realm();
    ##! 32: "Search for alias $keys->{ALIAS}"
    my $certificate = CTX('dbi_backend')->first(
        TABLE   => [ 'CERTIFICATE', 'ALIASES' ],
        COLUMNS => [
            'CERTIFICATE.DATA',
            'CERTIFICATE.SUBJECT',
            'CERTIFICATE.IDENTIFIER',
            'CERTIFICATE.NOTBEFORE',
            'CERTIFICATE.NOTAFTER',
        ],
        JOIN => [
            [ 'IDENTIFIER', 'IDENTIFIER' ],
        ],
        DYNAMIC => {
            'ALIASES.ALIAS' => { VALUE => $keys->{ALIAS} },
            'ALIASES.PKI_REALM' => { VALUE => $pki_realm },
        }
    );

    if (not $certificate) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_API_TOKEN_GET_CERTIFICATE_NOT_FOUND_FOR_ALIAS',
            params => {
                'ALIAS' => $keys->{ALIAS},
            }
        );
    }

    ##! 32: "Found certificate $certificate->{SUBJECT}"
    ##! 64: "Found certificate " . Dumper $certificate
    return {
        DATA => $certificate->{"CERTIFICATE.DATA"},
        SUBJECT => $certificate->{"CERTIFICATE.SUBJECT"},
        IDENTIFIER => $certificate->{"CERTIFICATE.IDENTIFIER"},
        NOTBEFORE => $certificate->{'CERTIFICATE.NOTBEFORE'},
        NOTAFTER => $certificate->{'CERTIFICATE.NOTAFTER'},
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

    ##! 1: 'start'
    my $self = shift;
    my $keys = shift;

    my $group  = $keys->{GROUP};

    my $pki_realm = $keys->{PKI_REALM};
    $pki_realm = CTX('session')->get_pki_realm() unless($pki_realm);

    if (!$group) {

        if ($keys->{TYPE}) {
           $group = CTX('config')->get("realm.$pki_realm.crypto.type.".$keys->{TYPE});
        }

        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_API_TOKEN_GET_TOKEN_ALIAS_BY_GROUP_NO_GROUP',
        ) if (!$group);
    }

    my %validity;
    foreach my $key (qw(notbefore notafter) ) {
        if ($keys->{VALIDITY}->{NOTBEFORE}) {
            $validity{$key} = $keys->{VALIDITY}->{uc($key)}->epoch();
        } else {
            $validity{$key} = time();
        }
    }

    my $db_results = CTX('dbi_backend')->select(
        TABLE   => [ 'CERTIFICATE', 'ALIASES' ],
        COLUMNS => [
            #  Necessary to use the column in ordering - FIXME: Pimp SQL Layer
            'ALIASES.NOTBEFORE',
            'ALIASES.NOTAFTER',
            'ALIASES.ALIAS',
            'ALIASES.IDENTIFIER',
        ],
        JOIN => [
            [ 'IDENTIFIER', 'IDENTIFIER' ],
        ],
        DYNAMIC => {
            'ALIASES.PKI_REALM' => { VALUE => $pki_realm },
            'ALIASES.GROUP_ID' => { VALUE => $group },
            'ALIASES.NOTBEFORE' => { VALUE => $validity{notbefore}, OPERATOR => 'LESS_THAN' },
            'ALIASES.NOTAFTER' => { VALUE => $validity{notafter}, OPERATOR => 'GREATER_THAN' },
        },
        'ORDER' => [ 'ALIASES.NOTBEFORE' ],
        'REVERSE' => 1,
    );

    my @token;
    foreach my $entry (@{ $db_results }) {
        
        my $item = { 
            ALIAS => $entry->{'ALIASES.ALIAS'}, 
            IDENTIFIER => $entry->{'ALIASES.IDENTIFIER'},
            NOTBEFORE => $entry->{'ALIASES.NOTBEFORE'},
            NOTAFTER  => $entry->{ 'ALIASES.NOTAFTER'}, 
        };
        if ($keys->{CHECK_ONLINE}) {
            if ($self->is_token_usable({ ALIAS => $entry->{'ALIASES.ALIAS'} })) {
                $item->{STATUS} = 'ONLINE';
            } else {
                $item->{STATUS} = 'OFFLINE';
            }
        }
        push @token, $item;
    }
    ##! 32: "Found tokens " . Dumper @token

    return \@token;

}

=head2 get_ca_list( {REALM} )

List all items in the certsign group of the requested REALM.
REALM is optional and defaults to the session realm.
Each entry of the list is a hashref holding the full alias name (ALIAS),
the certificate identifier (IDENTIFIER), the notbefore/notafter date,
the subject and the verbose status of the token. Possbile status values are
EXPIRED, UPCOMING, ONLINE, OFFLINE OR UNKNOWN.

The list is sorted by notbefore date, starting with the newest date.
Dates are taken from the alias table and therefore might differ
from the certificates validity!

=cut

sub get_ca_list {
    ##! 1: "start"

    my $self = shift;
    my $keys = shift;

    my $pki_realm = $keys->{REALM};
    $pki_realm = CTX('session')->get_pki_realm() unless($pki_realm);

    ##! 32: "Lookup group name for certsign"
    my $group = CTX('config')->get("realm.$pki_realm.crypto.type.certsign");

    my $db_results = CTX('dbi_backend')->select(
        TABLE   => [ 'CERTIFICATE', 'ALIASES' ],
        COLUMNS => [
            'ALIASES.NOTBEFORE',
            'ALIASES.NOTAFTER',
            'CERTIFICATE.DATA',
            'CERTIFICATE.SUBJECT',
            'ALIASES.ALIAS',
            'ALIASES.IDENTIFIER',
        ],
        JOIN => [
            [ 'IDENTIFIER', 'IDENTIFIER' ],
        ],
        DYNAMIC => {
            'ALIASES.PKI_REALM' => { VALUE => $pki_realm },
            'ALIASES.GROUP_ID' => { VALUE => $group },
        },
        'ORDER' => [ 'ALIASES.NOTBEFORE' ],
        'REVERSE' => 1,
    );

    my @token;
    foreach my $entry (@{ $db_results }) {

        my $item = {
            ALIAS => $entry->{'ALIASES.ALIAS'},
            IDENTIFIER => $entry->{'ALIASES.IDENTIFIER'},
            SUBJECT => $entry->{'CERTIFICATE.SUBJECT'},
            NOTBEFORE => $entry->{'ALIASES.NOTBEFORE'},
            NOTAFTER => $entry->{'ALIASES.NOTAFTER'},
            STATUS => 'UNKNOWN'
        };

        # Check if the token is still valid - dates are already unix timestamps
        my $now = time();
        if ($entry->{'ALIASES.NOTBEFORE'} > $now) {
            $item->{STATUS} = 'UPCOMING';
        } elsif ($entry->{'ALIASES.NOTAFTER'} < $now) {
            $item->{STATUS} = 'EXPIRED';
        } else {
            # Check if the key is usable
            my $token;
            eval {
                $token = CTX('crypto_layer')->get_token({
                    TYPE => 'certsign',
                    'NAME' => $entry->{'ALIASES.ALIAS'},
                    'CERTIFICATE' => {
                        DATA => $entry->{'CERTIFICATE.DATA'},
                        IDENTIFIER => $entry->{'CERTIFICATE.IDENTIFIER'},
                    }
                } );
                if ($self->is_token_usable({ TOKEN => $token })) {
                    $item->{STATUS} = 'ONLINE';
                } else {
                    $item->{STATUS} = 'OFFLINE';
                }
            };
            if ($EVAL_ERROR) {

                CTX('log')->log(
                    MESSAGE  => 'I18N_OPENXPKI_API_TOKEN_GET_CA_LIST_TOKEN_STATUS_EVAL_ERROR',
                    PRIORITY => "error",
                    FACILITY => [ 'application', 'system', 'monitor' ],
                );
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
        CTX('log')->log(
            MESSAGE  => 'Check if token is usable using engine',
            PRIORITY => "debug",
            FACILITY => 'application',
        );
        return $token->key_usable()
    }

    eval {

        CTX('log')->log(
            MESSAGE  => 'Check if token is usable using crypto operation',
            PRIORITY => "debug",
            FACILITY => 'application',
        );

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
    if ($EVAL_ERROR) {
        my $ee = $EVAL_ERROR;
        ##! 16: 'got eval error ' . $ee
        return 0;
    }

    ##! 16: 'key is online'
    return 1;

}


1;

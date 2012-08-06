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
use Digest::SHA1 qw( sha1_base64 );
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
    
    ##! 32: "Lookup group for type $type"
    $keys->{GROUP} = CTX('config')->get("crypto.type.".$keys->{TYPE});
    delete $keys->{TYPE};

   if (not $keys->{GROUP}) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_API_TOKEN_ALIAS_BY_TYPE_NO_GROUP_FOUND',
        );
    }

    return get_token_alias_by_group($keys);
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

    my $alias      = $keys->{ALIAS};
        
    #FIXME - find, create and return token.

}

=head2

Find the certificate for the give alias. Returns a hashref with the 
PEM encoded certificate (CERTIFICATE) and the Subject (SUBJECT).

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
    
    ##! 32: "Search for alias $keys->{ALIAS}"  
    
    my $certificate = CTX('dbi_backend')->first(
        TABLE   => [ 'CERTIFICATE', 'ALIASES' ],
        COLUMNS => [
            'CERTIFICATE.DATA', 
            'CERTIFICATE.SUBJECT',
            'CERTIFICATE.IDENTIFIER'            
        ],
        JOIN => [
            [ 'IDENTIFIER', 'IDENTIFIER' ],
        ],
        DYNAMIC => {
            'ALIASES.ALIAS' => $keys->{ALIAS} 
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
        IDENTIFIER => $certificate->{"CERTIFICATE.IDENTIFIER"} 
    };
 
}

1;

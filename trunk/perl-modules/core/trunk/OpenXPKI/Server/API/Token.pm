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
    
    ##! 32: "Lookup group for type $keys->{TYPE}"
    $keys->{GROUP} = CTX('config')->get("crypto.type.".$keys->{TYPE});
    delete $keys->{TYPE};

   if (not $keys->{GROUP}) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_API_TOKEN_ALIAS_BY_TYPE_NO_GROUP_FOUND',
        );
    }
    
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
        TABLE   => [ 'CERTIFICATE', 'ALIASES' ],
        COLUMNS => [ 
            'CERTIFICATE.NOTBEFORE', # Necessary to use the column in ordering - FIXME: Pimp SQL Layer           
            'ALIASES.ALIAS',              
        ],
        JOIN => [
            [ 'IDENTIFIER', 'IDENTIFIER' ],
        ],
        DYNAMIC => {
            'ALIASES.PKI_REALM' => { VALUE => $pki_realm },
            'ALIASES.GROUP_ID' => { VALUE => $group },              
            'CERTIFICATE.NOTBEFORE' => { VALUE => $validity{notbefore}, OPERATOR => 'LESS_THAN' },
            'CERTIFICATE.NOTAFTER' => { VALUE => $validity{notafter}, OPERATOR => 'GREATER_THAN' },                          
        },
        'ORDER' => [ 'CERTIFICATE.NOTBEFORE' ],
        'REVERSE' => 1,
    );

    if (!$alias->{'ALIASES.ALIAS'}) {
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
    
    ##! 16: "Suggesting $alias->{'ALIASES.ALIAS'} as best match"      
    return $alias->{'ALIASES.ALIAS'};
    
}

=head2 get_certificate_for_alias( { ALIAS } )

Find the certificate for the give alias. Returns a hashref with the 
PEM encoded certificate (DATA), Subject (SUBJECT), Identifier (IDENTIFIER)
and NOTBEFORE/NOTAFTER as epoch

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

=head2 list_active_aliases( { GROUP, VALIDITY, REALM } )

Get an arrayref with all tokens from the given group, which are/were valid within 
the validity period given by the VALIDITY parameter.
Each entry of the list is a hashref holding the full alias name and the 
certificate identifier. The list is sorted by notbefore date, starting with 
the newest date. See get_token_alias_by_group how validity works.
REALM is optional and defaults to the session's realm.
  
=cut

sub list_active_aliases {
    
    ##! 1: 'start'
    my $self = shift;
    my $keys = shift;
    
    my $group  = $keys->{GROUP};    
    
    if (!$group) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_API_TOKEN_GET_TOKEN_ALIAS_BY_GROUP_NO_GROUP',
        );        
    }
    
    my $pki_realm = $keys->{REALM};
    $pki_realm = CTX('session')->get_pki_realm() unless($pki_realm);
    
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
            'CERTIFICATE.NOTBEFORE',            
            'ALIASES.ALIAS',              
            'ALIASES.IDENTIFIER',
        ],
        JOIN => [
            [ 'IDENTIFIER', 'IDENTIFIER' ],
        ],
        DYNAMIC => {
            'ALIASES.PKI_REALM' => $pki_realm,
            'ALIASES.GROUP_ID' => $group,              
            'CERTIFICATE.NOTBEFORE' => { VALUE => $validity{notbefore}, OPERATOR => 'LESS_THAN' },
            'CERTIFICATE.NOTAFTER' => { VALUE => $validity{notafter}, OPERATOR => 'GREATER_THAN' },                          
        },
        'ORDER' => [ 'CERTIFICATE.NOTBEFORE' ],
        'REVERSE' => 1,
    );
    
    my @token;
    foreach my $entry (@{ $db_results }) {
        push @token, { ALIAS => $entry->{'ALIASES.ALIAS'}, IDENTIFIER => $entry->{'ALIASES.IDENTIFIER'}};
    }
    ##! 32: "Found tokens " . Dumper @token
    
    return \@token;
    
}

1;

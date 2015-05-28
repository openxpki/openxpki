# OpenXPKI::Server::Workflow::Activity::SmartCard::ComputePUK
# Written by Oliver Welter for the OpenXPKI project 2012
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::ComputePUK;

use strict;
use English;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Debug;

use base qw( OpenXPKI::Server::Workflow::Activity );

sub execute {
    ##! 1: 'start'
    my $self = shift;
    my $workflow = shift;
    my $context = $workflow->context();

    my $token_id = $context->param('token_id');
    my $chip_id = $context->param('chip_id');
    
    my $config = CTX('config');
    
    # if smartcard type is "rsa[23]": throw an error (PUK is static and has to be administratively 
    # imported into the datapool before a personalization can happen). End processing.
    if ($token_id !~ /^gem2/) {
        OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_COMPUTEPUK_TOKEN_NOT_SUPPORTED',
            params  => {
            TOKEN_ID => $token_id,
            },
        log => {
            logger => CTX('log'),
            priority => 'error',
            facility => [ 'system', ],
        },
        );
    }
    
    # Check Connector for Puk Id (Lot Id)
    my $lot_id = $config->get( "smartcard.cardinfo.lotid.$token_id" );
            
    if (!$lot_id) {
        if ($chip_id eq '000000000000000000000000') {
            $lot_id = 'null'; 
        } else {
            $lot_id = 'unknown';
        }
    }
    
    ##! 32: 'got lot id ' . $lot_id
    
    my $puk = $config->get( "smartcard.cardinfo.defaultpuk.$lot_id.$chip_id" );
 
    if (!$puk) {
        OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_COMPUTEPUK_NO_DEFAULT_PUK_AVAILABLE',
        params  => {
            TOKEN_ID => $token_id,
            CHIP_ID => $chip_id,
            LOT_ID => $lot_id,
            },
        log => {
            logger => CTX('log'),
            priority => 'error',
            facility => [ 'system', ],
        },
        );
    }

    ##! 32: 'got puk ' . $puk
    
    CTX('log')->log(
        MESSAGE => "SmartCard $token_id from lot id $lot_id, puk was computed",
        PRIORITY => 'info',
        FACILITY => [ 'application' ],
    );  
    $context->param({ _default_puk => $puk });
       
}    

1;

__END__

=head1 Name OpenXPKI::Server::Workflow::Activity::SmartCard::ComputePUK

=head1 Description

Compute the default PUK for a smartcard based on chip_id and token_id.

=head2 Context parameters

=over 12

=item token_id

Serialnumber of the token.

=item chip_id  

Chip Id of the token.

=item _default_puk (out)

Contains the computed default puk.

=back

=head1 Algorithm

Only Gemalto cards with a card id starting with gem2_ are supported.
There are multiple generations of cards in use and we need to obtain a 
"lot id" to get the correct puk deriviation algorithm.

The lot id is queried from the config at I<smartcard.cardinfo.lotid.$tokenid>.
If no lot id is found, the lot id is set to "unknown.", except for cards where 
the chip id is 0...0. Those are set to "null".

Lot Id and chip id are used to calculate the puk through a connector:  

   my $puk = $conn->get('smartcard.cardinfo.defaultpuk.$lotid.$chipid')
   
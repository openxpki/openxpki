# OpenXPKI::Server::Workflow::Activity::SmartCard::FetchTokens
# Written by Scott Hardin for the OpenXPKI project 2010
#
# Copyright (c) 2009 by The OpenXPKI Project

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::FetchTokens

=head1 Description

This activity searches the Connectors for smartcard entries and returns
the results.

=head2 Context parameters

The following context parameters set during initialize are read:

=over 8

=item token_id

Token ID assigned to given person. If more than one token is found, this should be the preferred entry.

=item token_status

Status of the token in I<token_id>.

=item person_N_KEY

Stores the given I<KEY> parameter for person I<N>. This is a kludge to support when
more than one person is found.

=item scb_N_KEY

Stores the given I<KEY> parameter for scb I<N>. This is a kludge to support when
more than one scb is found.

=back

=cut

package OpenXPKI::Server::Workflow::Activity::SmartCard::FetchTokens;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use English;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

=head1 Functions

=head2 execute

This is the entry point for the Workflow action.

Based on the value of the context parameter E<token_owner>, this activity
searches the OpenXPKI configuration (e.g.: via the connector) for
the key 'smartcard.user2card.E<token_owner>'. The value is a list of
token ids belonging to the given user.

Depending on the results, the following will occur:

=over

=item User has unique token ID 

If a unique token_id is found for the given user, the context parameter
I<token_id> is set to contain the value found.

=item User has multiple token IDs

If multiple token_ids were found for the given user, the context parameter
I<multi_ids> is set to contain a list of the values found.

=item User not found or has no token ID

If no token is found, no additional context parameters are set.

=cut

sub execute {
    ##! 1: 'Entered FetchTokens::execute()'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();

    my $email = $context->param('token_owner');

    my $config = CTX('config');

    #
    # Before we start, we need to see which config key contains
    # the mapping from user to token id.
    #

    my $res = $config->walkQueryPoints( 'smartcard.user2card', $email );

    ##! 16: 'walkQueryPoints returned: ' . Dumper $res
    ##! 16: 'walkQueryPoints returned VALUE: ' . $res->{VALUE};

    #    my $res = $config->get('smartcard.owners', $email);

    # DEBUG STUFF
    $context->param( 'DEBUG_res_dump', Dumper($res) );

    # NOTE: To get this stuff running this "Ass-u-me"s a few things:
    #
    # - The walkQueryPoints returns 0 or 1 tokens for the given user.
    #   If the user has more than one token... too bad.
    # - If the token_id was retrieved from LDAP, it is wrapped in an ugly
    #   'seealso' record. We just manually parse out the relevant data

    my $token_id = $res->{VALUE};

    ##! 16: '  token_id returned from smartcard.user2card: ' . $token_id
    if ( defined $token_id ) {
        $token_id =~ s/^scbserialnumber=([^,]+),.+/$1/;
    }
    ##! 16: '  token_id after removing scbserialnumber...: ' . $token_id
    #
    $context->param( 'token_id', $token_id );

#    # TODO: verify that arrays are handled correctly
#    if ( ref( $res->{VALUE} ) eq 'ARRAY' ) {
#        if ( @{ $res->{VALUE} } > 1 ) {
#            my $scbs = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
#                {   workflow    => $workflow,
#                    context_key => 'multi_ids',
#                }
#            );
#            foreach my $scb ( @{ $res->{VALUE} } ) {
#                $scbs->push($scb);
#            }
#        }
#        elsif ( @{ $res->{VALUE} } == 1 ) {
#            $context->param( 'token_id', $res->{VALUE}->[0] );
#        }
#    } else { 
#        $context->param( 'token_id', $res->{VALUE} );
#    }

    return $self;
}

1;


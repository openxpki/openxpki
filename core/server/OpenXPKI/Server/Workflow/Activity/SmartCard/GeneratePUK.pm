# OpenXPKI::Server::Workflow::Activity::SmartCard::GeneratePUK
#
# Written by Scott Hardin for the OpenXPKI project 2005
#
# Based on OpenXPKI::Server::Workflow::Activity::Skeleton,
# written by Martin Bartosch for the OpenXPKI project 2005
#
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::GeneratePUK;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Digest::SHA qw( sha1_hex );
use MIME::Base64;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self          = shift;
    my $workflow      = shift;
    my $context       = $workflow->context();

    my $default_token = CTX('api')->get_default_token();
    my $puk_policy = $self->param('puk_policy');

    # Because this code must be easy for colleagues to review, it
    # is optimized for readability and not performance or programmer laziness.

    $puk_policy ||= 'gem2';
    my ( $puk_length, $puk );


    if ( $puk_policy =~ /gem[23]/ ) {
        $puk_length = 24; # bytes

        my $command = {
            COMMAND       => 'create_random',
            RETURN_LENGTH => $puk_length,
            RANDOM_LENGTH => $puk_length,
        };
        my $puk_base64 = $default_token->command($command);

        # Extract raw binary data from base64 encoded string
        my $puk_raw = decode_base64($puk_base64);

        # Convert to hex string
        my $puk_hex = unpack( 'H*', $puk_raw );
        $puk_hex = substr($puk_hex . "00" x ($puk_length * 2),
              0,
              $puk_length * 2);

        # In this next block, we fetch the current puk from the datapool
        # and save this new puk together with the current puk in an array.
        # If no puk is found and a default puk is available as a context
        # parameter (set during the prereq api), it is used as the current
        # puk.

        my $ser = OpenXPKI::Serialization::Simple->new();
        my $params = {
            PKI_REALM => CTX('api')->get_pki_realm(),
            NAMESPACE => 'smartcard.puk',
            KEY => $context->param('token_id'),
        };
        my $msg = CTX('api')->get_data_pool_entry($params);

        my $currpuk = $msg->{VALUE};
        my $puks;

        if (not defined $currpuk) {
            my $defaultpuk = $context->param('_default_puk');
            if ( defined $defaultpuk ) {
                $currpuk = $defaultpuk;
                $puks = [ $currpuk ];
            }
        } elsif ( $currpuk =~ /^[a-zA-Z\d]+$/ ) {
                $puks = [ $currpuk ];
        } else {
            # a puk string probably contains alpha-numeric, so
            # if we get more than just that, assume that we need
            # to deserialize.
            $currpuk = $ser->deserialize($currpuk);
            if ( ref($currpuk) eq 'ARRAY' ) {
                $puks = $currpuk;
            } else {
                $puks = [ $currpuk ];
            }
        }

        # serialize new data and write to datapool
        unshift @{ $puks }, $puk_hex;

        my $raw = $ser->serialize( $puks );
        $params->{VALUE} = $raw;
        $params->{ENCRYPT} = 1;
        $msg = CTX('api')->set_data_pool_entry($params);

        CTX('log')->application()->info('SmartCard new puk generated for token ' . $context->param('token_id'));

#        # set a flag in the context so the wf knows this was successful
        $context->param( 'generated_new_puk', 'yes' );
#        ##! 128: 'TEMP DEBUG OUTPUT - Set _newpuk to ' . $puk_hex
        return $self;
    }
    else {
        OpenXPKI::Exception->throw(
            message =>
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GENERATEPUK_BAD_POLICY',
        );
    }

}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::GeneratePUK

=head1 Description

Implements the GeneratePUK workflow action.

=head2 Context parameters

=over 12

=item _default_puk

If no datapool entry is found for the token, but this context value is
present, it is also added to the datapool.

=back

=head2 Activity parameters

Expects the following activity parameters

=over 12

=item puk_policy

B<Note:> Planned for future version. For now, 'gem2' is always used.

Specifies the name of the puk policy to use. Possible choices are:

 gem2/gem3  48 hex chars, as required by Gemalto 2 cards [default]

=back

After completion, the following context parameters will be set:

=over 12

=item generated_new_puk

Indicates that the new PUK code has been written to the datapool.

=back

=head1 Functions

=head2 execute

Executes the action.

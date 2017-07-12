=head1 NAME

OpenXPKI::Client::SC::Utilities

=cut

package OpenXPKI::Client::SC::Utilities;

use Moose;
use English;
use Data::Dumper;
use OpenXPKI::DateTime;
use OpenXPKI::Crypto::Backend::OpenSSL::ECDH;
use Digest::SHA qw(sha256_hex);

extends 'OpenXPKI::Client::SC::Result';

=head2 handle_get_server_status

Run without any user/login information.

=head3 parameters

none

=head3 response

#TODO
use in frontend unclear, seems like it just pops up the value of
get_server_status as message. Should be moved to server to check if
capacity for personalizaion is available (volatile workflow)

=cut
sub handle_get_server_status {

    my $self = shift;

    my $wf_info = $self->_client()->handle_workflow({ TYPE => 'sc_server_load' });
    my $context = $wf_info->{CONTEXT};

    my $result = {
        'active_processes' => $context->{'proc_count'},
        'loadavg' => $context->{'system_load'},
        'get_server_status' => 'Server ' . $context->{'server_status'}
    };

    if ($result->{get_server_status} ne 'OK') {
        $self->logger()->warn( "Server Status is : " . $result->{get_server_status} );
    }

    $self->logger()->trace( "Server Status " . Dumper $result );

    $self->_result($result);

    return 0;
}


=head2 handle_get_card_status

Calls the backend API to evaluate the status of the given card

=head3 parameters

=over

=item cardID

cardSerialNumber

=item cardType

CardType String

=item cert[int] (optional)

certificates cert0 ,cert1 etc.

=back

=head3 response

TODO

=cut

sub handle_get_card_status {

    my $self = shift;

    my $session = $self->_session();
    my $log = $self->logger();

    my $config = $self->config();

    my $cardData = $self->cardData();

    my $result = {};

    $log->info('Request for card status for cardID ' .  $cardData->{'cardID'} );

    my $p = $self->param();
    $log->trace('Request params ' . Dumper $p );

    # Load the certificates from the request
    my @certs;

    my $wf_type_unblock = $config->{workflow}->{pinunblock};
    my $wf_type_pers = $config->{workflow}->{personalization};


  CERTS:
    for ( my $i = 0 ; $i < 15 ; $i++ ) {
        my $index = sprintf( "%02d", $i );
        last CERTS if !defined $self->param("cert$index");
        push( @certs, $self->param("cert$index") );
    }

    my %params = (
        'CERTS'          => \@certs,
        'CERTFORMAT'     => 'BASE64',
        'WORKFLOW_TYPES' => [ $wf_type_unblock, $wf_type_pers ],
        'SMARTCARDID' => $cardData->{'id_cardID'},
        'SMARTCHIPID' => $cardData->{'ChipSerial'},
    );


    # run analyze with default client (system user)
    $log->info( "Analyze: " . Dumper(%params) );
    my $reply;
    eval {
        $reply = $self->_client()->run_command( 'sc_analyze_smartcard', \%params );
    };
    if ($EVAL_ERROR) {
        my $err = $self->_client()->last_error();
        if (!$err) { $err = 'I18N_OPENXPKI_UI_SCANALYZE_UNKNOWN_BACKEND_ERROR'; }
        $self->_add_error($err);
        return 1;
    }

    $result->{'msg'} = { PARAMS => $reply };

    # set card data from analyze result
    $cardData->{'cardOwner'} = $reply->{SMARTCARD}->{assigned_to}->{card_owner};
    $cardData->{'dbntloginid'} = $reply->{SMARTCARD}->{assigned_to}->{loginids};

    # record the card owner to the session
    $session->param('cardOwner', $cardData->{'cardOwner'} );
    $log->debug( "Card owner: " . $cardData->{'cardOwner'} );


    my @workflows;

    $log->trace( 'sc_analyse reply ' . Dumper $reply );



    if ( scalar @{$reply->{WORKFLOWS}->{ $wf_type_unblock }} ) {
        @workflows = @{$reply->{WORKFLOWS}->{ $wf_type_unblock }};
    }

    if ( scalar @{$reply->{WORKFLOWS}->{ $wf_type_pers }} ) {
        @workflows = @{[ @workflows, @{$reply->{WORKFLOWS}->{ $wf_type_pers }} ]};
    }

    my @mangled_workflows;

    WORKFLOW:
    foreach my $entry ( @workflows ) {

        # Filter out failed workflows
        if ( $entry->{'WORKFLOW.WORKFLOW_STATE'} eq 'FAILURE' ) {

            next WORKFLOW;
        }

        my %newentry;
        # strip the WORKFLOW prefix from the columns
        foreach my $key ( keys %{$entry} ) {
            my $newkey = $key;
            $newkey =~ s{ \A WORKFLOW\. }{}xms;
            $newentry{$newkey} = $entry->{$key};
        }

        $newentry{'LAST_UPDATE_EPOCH'} =
            OpenXPKI::DateTime::parse_date_utc( $entry->{'WORKFLOW.WORKFLOW_LAST_UPDATE'} )->epoch();

        my $wf_info = $self->_client()->handle_workflow({ 'ID' => $newentry{'WORKFLOW_SERIAL'} });

        $log->trace( 'user workflow ' . Dumper $wf_info );

        if ($wf_info->{'TYPE'} eq $wf_type_unblock) {
            $newentry{'auth1_ldap_mail'} = $wf_info->{CONTEXT}->{auth1_mail};
            $newentry{'auth2_ldap_mail'} = $wf_info->{CONTEXT}->{auth2_mail};
            $newentry{'TOKEN_ID'} = $wf_info->{CONTEXT}->{token_id};
        } elsif ($wf_info->{'TYPE'} eq $wf_type_pers) {
            $newentry{'TOKEN_ID'} = $wf_info->{CONTEXT}->{token_id};
        }

        $log->trace( 'Workflow Item after process ' . Dumper \%newentry );
        push @mangled_workflows, \%newentry;
    }

    $result->{'userWF'} = \@mangled_workflows;


    foreach my $key (qw(id_cardID cardtype cardID cardOwner)) {
        $result->{$key} = $cardData->{$key};
    }


    #$result->{'creator_userID'} = 'set:' . $cardData->{'creator_userID'};

    # calculate transport key from ecdh key
    if ( defined $self->param("ECDHPubkey") ) {

        my $ECDHPubkey = $self->param("ECDHPubkey");
        # trim whitespace from key
        $ECDHPubkey =~ s/^\s+//;
        $ECDHPubkey =~ s/\s+$//;

        $log->info( "ECDHPeerPubkey:\n " . $ECDHPubkey );

        $session->param('rndPIN', '');

        my $ecdhkey;
        eval {
            $ecdhkey = OpenXPKI::Crypto::Backend::OpenSSL::ECDH::get_ecdh_key($ECDHPubkey);
        };
        if ( $EVAL_ERROR || !$ecdhkey) {
            $log->error( "Error getting ECDH Key:" . $EVAL_ERROR);

        } else {

            $log->info( "ECDHPubkey:\n " . $ecdhkey->{'PEMECPubKey'} );

            $result->{'ecdhpubkey'} = $ecdhkey->{'PEMECPubKey'};

            # this is the transport secret
            $session->param('aeskey', sha256_hex( $ecdhkey->{'ECDHKey'} ) );

        }
    }



    # copy info from config as it is required in the output
    my $conf_outlook = $config->{'outlook'};
    foreach my $key (keys %{ $conf_outlook }) {
        $result->{'outlook_'.$key} = $conf_outlook->{$key};
    }

    $self->_result( $result );

    return 0;

}


=head2 server_log

Write a log message to the log file

=head3 parameters

=over

=item cardID

cardSerialNumber

=item cardType

CardType String

=item message

Message to write (String)

=item level

Log level, one of info|debug|error|warn

=back

=head3 response

TODO

=cut

sub handle_server_log {

    my $self  = shift;

    my $level = $self->param("level");
    my $message = $self->param("message");

    if (!$level) {
        $level = 'info';
    } elsif ( $level !~ /(info|debug|error|warn)/ ) {
        $self->logger()->error(sprintf('Log request from frontend with improper level (%s)!', $message));
        $level = 'warn';
    }
    $self->logger()->$level( 'Frontend: '. $message );

    return 0;
}


1;
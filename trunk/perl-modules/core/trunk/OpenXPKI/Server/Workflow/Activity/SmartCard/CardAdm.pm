# OpenXPKI::Server::Workflow::Activity::SmartCard::CardAdm
# Written by Scott Hardin for the OpenXPKI project 2011
# Copyright (c) 2011 by The OpenXPKI Project
#
# STATUS:
#
# This module is currently being re-worked. It originally was hard-coded
# to work with a single LDAP server. With the Connector handling multiple
# data sources, the modification commands have been disabled until we
# implement updates in the LDAP Connector.

package OpenXPKI::Server::Workflow::Activity::SmartCard::CardAdm;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use Crypt::DES;
use MIME::Base64;

use Data::Dumper;

# usage: $self->throw( MESSAGE, { PARAM1, VAL1 [, PARAMN, VALn ] }, PRIO, FACILITY );
sub throw {
    my ( $self, $message, $params, $priority, $facility ) = @_;
    $message  ||= '<unknown message>';
    $params   ||= {};
    $priority ||= 'warn';
    $facility ||= 'system';
    warn "CardAdm::throw($message, $params, $priority, $facility) called";
    OpenXPKI::Exception->throw(
        message => $message,
        params  => $params,
        log     => {
            logger   => CTX('log'),
            priority => $priority,
            facility => $facility,
        },
    );
}

sub _get_conf {
    my $self    = shift;
    my $arg_ref = shift;

    return CTX('config');
}

sub _get_ldap_conn {
    my $self = shift;
    my $conf = shift;
    my $ldap;

    my $ldap_conf = $conf->{directory}->{ldap};

    eval {
        if ( $ldap_conf->{uri} =~ /^ldaps:/ )
        {
            require Net::LDAPS;
            import Net::LDAPS;
            $ldap = Net::LDAPS->new( $ldap_conf->{uri}, onerror => undef, );
        }
        else {
            require Net::LDAP;
            import Net::LDAP;
            $ldap = Net::LDAP->new( $ldap_conf->{uri}, onerror => undef, );
        }
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message =>
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_NET_LDAP_EVAL_ERR',
            params => { 'EVAL_ERROR' => $EVAL_ERROR, },
            log    => {
                logger   => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }

    if ( !defined $ldap ) {
        OpenXPKI::Exception->throw(
            message =>
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_CONNECTION_FAILED',
            params => { 'LDAP_URI' => $ldap_conf->{uri}, },
            log    => {
                logger   => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }

    my $mesg = $ldap->bind( $ldap_conf->{bind_dn},
        password => $ldap_conf->{pass} );
    if ( $mesg->is_error() ) {
        OpenXPKI::Exception->throw(
            message =>
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_BIND_FAILED',
            params => {
                ERROR      => $mesg->error(),
                ERROR_DESC => $mesg->error_desc(),
            },
            log => {
                logger   => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }
    ##! 2: 'ldap->bind() done'

    return $ldap;
}

# This works as follows:
#
# - fetch entry for current user
# - fetch entry for new user
# - do some sanity checking
# - remove link to card from current user(s)
# - add link to card for new user
#
sub modify_user {
    my $self     = shift;
    my $workflow = shift;
    
    # SORRY, BUT WE JUST BAIL AT THE MOMENT
    $self->throw( "modify_user() has been temporarily disabled", {}, 'error', 'monitor' );

=begin DISABLED

    my $conf = $self->_get_conf();
    my $ldap = $self->_get_ldap_conn($conf);

    my $context  = $workflow->context();
    my $token_id = $context->param('token_id');
    my $new_user = $context->param('new_user');
    my $force    = $context->param('force');
    my $nodel    = $context->param('nodel');

    # vars for current user record
    my ( $curr_mesg, $curr );

    # vars for the new user
    my ( $new_mesg, $new_entry );

    # vars for all person records
    my $pers_key   = 'cn';
    my @pers_attrs = qw( cn mail tel );

    # vars for scb records
    my $scb_key = 'seeAlso';
    my $scb_value
        = 'scbserialnumber='
        . $token_id . ','
        . $conf->{directory}->{smartcard}->{basedn};

    ##! 64: "Entered modify_user: token_id=$token_id, new_user=$new_user, force=$force"
    ##! 128: "\tworkflow context=" . Dumper($context)

    #
    # Get current user record that has seeAlso refering to smartcard
    #

    $curr_mesg = $ldap->search(
        base      => $conf->{directory}->{person}->{basedn},
        scope     => 'sub',
        filter    => "($scb_key=$scb_value)",
        attrs     => \@pers_attrs,
        timelimit => $conf->{directory}->{ldap}->{timeout},
    );
    if ( $curr_mesg->is_error() ) {
        $self->throw(
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_SEARCH_FAILED',
            {   ERROR      => $curr_mesg->error(),
                ERROR_DESC => $curr_mesg->error_desc(),
            },
        );
    }

    #
    # Get new user record (only if new user was set)
    #

    if ($new_user) {
        $new_mesg = $ldap->search(
            base      => $conf->{directory}->{person}->{basedn},
            scope     => 'sub',
            filter    => "($pers_key=$new_user)",
            attrs     => \@pers_attrs,
            timelimit => $conf->{directory}->{ldap}->{timeout},
        );

        ##! 64: 'return value from search for new user: ' . Dumper($new_mesg)
        if ( $new_mesg->is_error() ) {
            $self->throw(
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_SEARCH_FAILED',
                {   ERROR      => $new_mesg->error(),
                    ERROR_DESC => $new_mesg->error_desc(),
                },
            );
        }

        if ( $new_mesg->count == 0 ) {
            $self->throw(
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_ENTRY_NOT_FOUND',
                { FILTER => "$pers_key=$new_user", },
            );
        }

        #
        # TODO: add check for multiple records matching new user?
        #

        #
        # Check that user record doesn't already have a token assigned to it
        #

        $new_entry = $new_mesg->entry(0);
        my @seeAlso = $new_entry->get_value('seeAlso');
        if ( grep /^scbserialnumber=/, @seeAlso ) {
            $self->throw(
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_USER_ALREADY_HAS_TOKEN',
                { FILTER => "$pers_key=$new_user", },
            );
        }
    }

    #
    # Delete seeAlso attribute for current user, if necessary
    #

    if ( $curr_mesg->count != 0 and not $nodel ) {

        ##! 16: 'found ' . $curr_mesg->count . ' records for token ' . $token_id

        if ( $curr_mesg->count > 1 and not $force ) {

            # if force is not enabled, throw error if there is more than
            # one person found for this token

            $self->throw(
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_MORE_THAN_ONE_LDAP_ENTRY_FOUND',
                { FILTER => "$scb_key=$scb_value", },
            );
        }

        # delete specific seeAlso entry that we searched for earlier

        foreach my $entry ( $curr_mesg->entries ) {
            $ldap->modify( $entry, delete => { $scb_key => $scb_value }, );
        }
    }

#
# Modify seeAlso attribute of new user record to refer to token (only if new user was given)
#

    if ($new_user) {
        $new_mesg = $ldap->modify(
            $new_entry,
            add => {
                      seeAlso => 'scbserialnumber='
                    . $token_id . ','
                    . $conf->{directory}->{smartcard}->{basedn}
            },
        );

        if ( $new_mesg->is_error() ) {
            OpenXPKI::Exception->throw(
                message =>
                    'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_ADD_SEEALSO_FOR_TOKEN',
                params => {
                    ERROR      => $new_mesg->error(),
                    ERROR_DESC => $new_mesg->error_desc(),
                },
                log => {
                    logger   => CTX('log'),
                    priority => 'error',
                    facility => 'monitor',
                },
            );
        }
    }

=end DISABLED

=cut

}

# This works as follows:
#
# - fetch entry for current token
# - do some sanity checking
#   (should we prevent multiple cards from being enabled?)
# - update status value
#
sub modify_status {
    my $self     = shift;
    my $workflow = shift;
    
    # SORRY, BUT WE JUST BAIL AT THE MOMENT
    $self->throw( "modify_status() has been temporarily disabled", {}, 'error', 'monitor' );

=begin DISABLED

    my $conf = $self->_get_conf();
    my $ldap = $self->_get_ldap_conn($conf);

    my $context    = $workflow->context();
    my $token_id   = $context->param('token_id');
    my $new_status = $context->param('new_status');

    # vars for scb records
    my $mesg;
    my $scb_key   = 'scbserialnumber';
    my $scb_value = $token_id;
    my @scb_attrs = qw( scbserialnumber scbstatus );

    ##! 64: "Entered modify_status: token_id=$token_id, new_status=$new_status, force=$force"
    ##! 128: "\tworkflow context=" . Dumper($context)

    #
    # Get current token entry
    #

    $mesg = $ldap->search(
        base      => $conf->{directory}->{smartcard}->{basedn},
        scope     => 'sub',
        filter    => "($scb_key=$scb_value)",
        attrs     => \@scb_attrs,
        timelimit => $conf->{directory}->{ldap}->{timeout},
    );
    if ( $mesg->is_error() ) {
        $self->throw(
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_SEARCH_FAILED',
            {   ERROR      => $mesg->error(),
                ERROR_DESC => $mesg->error_desc(),
            },
        );
    }

    #
    # Sanity checks
    #
    # - unless we find exactly one entry, return error
    #

    if ( $mesg->count != 1 ) {
        $self->throw(
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_RESULT_NOT_UNIQUE',
            {   NUM_RECS_FOUND => $mesg->count,
                SCB_SERIALS    => join( ', ',
                    map { $_->get_value('scbserialnumber') } $mesg->entries )
            },
        );
    }

    #
    # Update entry
    #

    my $entry = $mesg->entry(0);

    ##! 64: "Replacing scbstatus of '$scb_value' with '$new_status'"
    $mesg
        = $ldap->modify( $entry, replace => { 'scbstatus' => $new_status }, );

    if ( $mesg->is_error() ) {

        $self->throw(
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_LDAP_STATUS_UPDATE_FAILED',
            {   ERROR      => $mesg->error(),
                ERROR_DESC => $mesg->error_desc(),
            },
        );
    }

=end DISABLED

=cut

}

# This works as follows:
#
# - create instance of requested workflow
# - Say the following to the instance: "AYE KEEEEELL YOUUUUU!!!!
#   (for exact pronunciation, search for "dunham achmed" on youtube)
#
sub kill_workflow {
    my $self     = shift;
    my $workflow = shift;

    my $context = $workflow->context();
    my $wf_ids  = $context->param('target_wf_id');

    #    my $wf_type = $context->param('target_wf_type');

    ##! 16: "entered kill_workflow() for ID $wf_id"

    foreach my $wf_id ( split( /[,:;]/, $wf_ids ) ) {

        my $wf_type
            = CTX('api')->get_workflow_type_for_id( { ID => $wf_id } );

        # load the workflow
        ##! 64: "Load workflow type=$wf_type, id=$wf_id"
        my $wf;

        my $config_id
            = CTX('api')->get_config_id( { ID => $workflow->id() } );
        my $realm      = CTX('session')->get_pki_realm();
        my $wf_factory = CTX('workflow_factory')->{$config_id}->{$realm};

        eval { $wf = $wf_factory->fetch_workflow( $wf_type, $wf_id ); };
        if ($EVAL_ERROR) {
            $self - throw(
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_CARDADM_FETCH_WF_FAILED',
                { ERROR_MSG => $@, EVAL_ERROR => $EVAL_ERROR },
            );
        }

        if ( not $wf ) {
            $self->throw(
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_CARDADM_FETCH_WF_FAILED',
                { ERROR_MSG => $@, },
            );
        }
        $wf->delete_observer(
            'OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');
        $wf->add_observer(
            'OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');

        ##! 64: "Set state of wf $wf_id to 'FAILURE'"

# BEGIN DIRTY HACK WARNING
#
# In this routine, we are trying to kill another workflow. Albeit, we could
# just write directly to the database and change the workflow state, it seemed
# better to use the workflow classes themselves to change the state. The
# workflow class doesn't like this. There is a check in the Workflow.pm that
# ensures that the caller of state() begins with /^Workflow/. Obviously, the
# OpenXPKI classes don't begin with this string, so we do a little impersonation
# here to sneak past the guarded Workflow gates. Putting this code into its
# own block "{ package ...} does the trick.
#
        my $old_state;
        {

            package Workflow::SneakyHack;
            $old_state = $wf->state;
            $wf->state('FAILURE');
        }

        # END DIRTY HACK WARNING

        $wf->notify_observers( 'execute', $old_state,
            'administratively kill workflow' );
        $wf->notify_observers( 'state change', $old_state,
            'administratively kill workflow' );
        $wf_factory->save_workflow($wf);

        # _commit_transaction doesn't seem to be in all versions of Workflow,
        # so let's wrap it in an eval
        eval { $wf_factory->_commit_transaction($wf); };

    }
    return $self;
}

# This works as follows:
#
# - fetch token_id and unblock_challenge from context
# - fetch PUK from database
# - generate unblock_response using magic
#
sub get_unblock_response {
    my $self     = shift;
    my $workflow = shift;

    my $context           = $workflow->context();
    my $token_id          = $context->param('token_id');
    my $pukraw            = $context->param('_puk');
    my $unblock_challenge = uc($context->param('unblock_challenge'));


    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $puk = $serializer->deserialize($pukraw);

    if ( not ref($puk) eq 'ARRAY' ) {

        # this is a tad harsh, but that's life
        die "FetchPUK should return ARRAY, but got '$puk'";
    }

    # do magic, which is to encrypt the challenge with 3DES using the
    # puk as the key. We use Crypt::DES and do the 3DES on it by hand
    # to reduce the number of CPAN dependencies.
    # Also, we only do one block, so don't worry about the mode.
    my $des    = {};
    my $deskey = $puk->[0];
    if ( not $deskey ) {
        $deskey = $context->param('smartcard_default_puk');
    }

    ##! 64: 'deskey: ' . $deskey

    my $keylen = length($deskey);

    ##! 64: 'keylen: ' . $keylen

    my $key = pack( "H$keylen", $deskey );
    for my $i ( 1 .. 3 ) {
        $des->{"des$i"} = Crypt::DES->new( substr $key, 8 * ( $i - 1 ), 8 );
    }

    my $blocklen = length($unblock_challenge);
    my $block    = pack( "H$blocklen", $unblock_challenge );
    my $resp     = $des->{des3}
        ->encrypt( $des->{des2}->decrypt( $des->{des1}->encrypt($block) ) );

    my $hexresp = unpack( "H$blocklen", $resp );

    ##! 16: 'unblock response: ' . $hexresp

    $context->param( 'unblock_response', $hexresp );

#    $context->param('verbose', join("\n\t", "DUUDE!!!", "\ttoken_id=$token_id", "pukraw=$pukraw", "puk=$puk", "unblock_challenge=$unblock_challenge",
#        "keylen=$keylen", "key=$key", "blocklen=$blocklen", "block=$block", "resp=$resp", "hexresp=$hexresp"));

    return $self;
}

sub execute {
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();

    my $next_action = $context->param('next_action');
    my $token_id    = $context->param('token_id');
    ##! 1: 'entered execute() with next_action=' . $next_action . ' and token_id=' . $token_id

    if ( $next_action eq 'modify_user' ) {
        $self->modify_user($workflow);
    }
    elsif ( $next_action eq 'modify_status' ) {
        $self->modify_status($workflow);
    }
    elsif ( $next_action eq 'kill_workflow' ) {
        $self->kill_workflow($workflow);
    }
    elsif ( $next_action eq 'get_unblock_response' ) {
        $self->get_unblock_response($workflow);
    }
    else {
        $self->throw(
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_CARDADM_ACTION_INVALID',
            { NEXT_ACTION => $next_action, },
        );
    }

    return;

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::CardAdm

=head1 Description

Based on the value of the attribute I<next_action>, one of the supported
smartcard administration tasks is executed.

=head2 modify_user

=over 8

=item Parameters

token_id, new_user, force, nodel

=item Task

Modify the LDAP directory entry, assigning the record for the given user CN
to the token. If the value of I<new_user> is empty, the current link from
token to user record is removed.

If more than one person record is found assigned to the given card, an error
is returned. To have those references removed automatically, specify the 
I<force> option.

For testing purposes only, it is possible to ignore the policy of allowing
only one person per smartcard. Specifying I<nodel> supresses the deletion of 
existing seeAlso references.

=back

=head2 modify_status

=over 8

=item Parameters

token_id, new_status

=item Task

Modify the LDAP directory entry for the token, assigning the status value to the 
value of I<new_status>.

=back

=head2 kill_workflow

=over 8

=item Parameters

target_wf_id, target_wf_type

=item Task

Forcibly change the state of the given workflow to FAILURE.

=back

=head2 get_unblock_response

=over 8

=item Parameters

token_id, unblock_challenge

=item Task

Using the given token_id, fetch the PUK from the database and generate the response using the PUK and the challenge.

=item Results

unblock_response

=back


# OpenXPKI::Server::Workflow::Activity::SmartCard::CheckPrereqs
# Written by Scott Hardin for the OpenXPKI project 2010
#
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::CheckPrereqs;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
    ##! 1: 'Entered CheckPrereqs::execute()'
    my $self = shift;
    my $workflow = shift;
    my $context = $workflow->context();
    my $token_id = $context->param('token_id');

    my %params;
    if ($context->param('user_id')) {
        $params{USERID} = $context->param('user_id');
    }
    if ($context->param('chip_id')) {
        $params{SMARTCHIPID} = $context->param('chip_id');
    }

    my @certs = split(/;/, $context->param('certs_on_card'));

    my $ser = OpenXPKI::Serialization::Simple->new();

    # In case we want to deal with exisiting workflows we need to load them
    # This is the case when using this activity from the admin wfl
    my $wf_types = $self->param('wf_types');
    if ($wf_types) {
        CTX('log')->application()->info('SmartCard will search for workflows of type : ' . $wf_types);

        my @wf_type_list = split /,/, $wf_types if ($wf_types);
        $params{WORKFLOW_TYPES} = \@wf_type_list;
    }

    my $result = CTX('api')->sc_analyze_smartcard(
        {
         CERTS => \@certs,
        CERTFORMAT => 'BASE64',
        SMARTCARDID => $context->param('token_id'),
        %params,
        });

    ##! 16: 'smartcard analyzed: ' . Dumper $result

    # Save the details on workflows in our context. Note: since complex data
    # structures cannot be persisted without serializing, use the underscore
    # prefix to surpress persisting.

    $context->param('_workflows', $result->{WORKFLOWS});
    if ($wf_types) {
        CTX('log')->application()->trace('SmartCard found existing workflows: ' . Dumper $result->{WORKFLOWS});
    }

    # set cert ids in context
    my $cert_ids = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        {
        workflow    => $workflow,
        context_key => 'certids_on_card',
        } );
    $cert_ids->push(
        map { $_->{IDENTIFIER} } @{$result->{PARSED_CERTS}}
        );


    my $cert_types = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        {
        workflow    => $workflow,
        context_key => 'certificate_types',
        } );


    foreach my $type (keys %{$result->{CERT_TYPE}}) {
        $cert_types->push($type);

        foreach my $entry (keys %{$result->{CERT_TYPE}->{$type}}) {
        # FIXME: find a better way to name the flags properly, currently
        # the resulting wf keys depend on the configuration (i. e.
        # configured certificate types)
        my $value = 'no';
        if ($result->{CERT_TYPE}->{$type}->{$entry}) {
            $value = 'yes';
        }

        #$context->param('flag_' . $type . '_' . $entry
    #               => $value);
        }
    }


    foreach my $flag (keys %{$result->{PROCESS_FLAGS}}) {
        # propagate flags
        my $value = 'no';
        if ($result->{PROCESS_FLAGS}->{$flag}) {
        $value = 'yes';
        }
        $context->param('flag_' . $flag => $value);
    }

    # Resolver name that returned the basic user info
    # not used at the moment but might be useful
    $context->param('user_data_source' =>
        $result->{SMARTCARD}->{user_data_source} );

    # Propagate the userinfo to the context
      USERINFO_ENTRY:
    foreach my $entry (keys (%{$result->{SMARTCARD}->{assigned_to}})) {
        my $value = $result->{SMARTCARD}->{assigned_to}->{$entry};
        if (ref $value eq 'ARRAY') {
        my $queue = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
            {
            workflow    => $workflow,
            context_key => 'userinfo_' . $entry ,
            } );
        $queue->push(@{$value});
        } else {
        $context->param('userinfo_' . $entry =>
                $result->{SMARTCARD}->{assigned_to}->{$entry});
        }
    }

    ############################################################
    # propagate wf tasks to context
    my $certs_to_install = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        {
        workflow    => $workflow,
        context_key => 'certs_to_install',
        } );
    $certs_to_install->push(
        map { $_->{IDENTIFIER} } @{$result->{TASKS}->{INSTALL}}
        );

    my $certs_to_delete = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        {
        workflow    => $workflow,
        context_key => 'certs_to_delete',
        } );
    $certs_to_delete->push(
        map { $_->{MODULUS_HASH} } @{$result->{TASKS}->{PURGE}}
        );


    my $certs_to_unpublish = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        {
        workflow    => $workflow,
        context_key => 'certs_to_unpublish',
        } );
    $certs_to_unpublish->push(
        map { $_->{IDENTIFIER} } @{$result->{TASKS}->{DIRECTORY}->{UNPUBLISH}}
        );


    my $certs_to_create_wf = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        {
        workflow    => $workflow,
        context_key => 'certs_to_create',
        } );
    $certs_to_create_wf->push(
        @{$result->{TASKS}->{CREATE}}
        );

    my $certs_to_revoke_wf = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        {
        workflow    => $workflow,
        context_key => 'certs_to_revoke',
        } );

    $certs_to_revoke_wf->push(
        map { $_->{IDENTIFIER} } @{$result->{TASKS}->{REVOKE}}
        );


    $context->param('smartcard_status' =>
            $result->{SMARTCARD}->{status});

    $context->param('keysize' =>
            $result->{SMARTCARD}->{keysize});

    $context->param('keyalg' =>
            $result->{SMARTCARD}->{keyalg});

    # Values are valid, new, mismatch
    $context->param('smartcard_token_chipid_match' =>
            $result->{SMARTCARD}->{token_chipid_match});

    # Record the max validity - sc_analyse returns an epoch, we need a terse date
    if ($result->{VALIDITY}->{set_to_value}) {
        my $max_validity = OpenXPKI::DateTime::convert_date({
            DATE      => DateTime->from_epoch( epoch => $result->{VALIDITY}->{set_to_value} ),
            OUTFORMAT => 'terse',
        });
        $context->param('max_validity' => $max_validity);
        $context->param('notafter' => $max_validity);

    } else {
        $context->param('max_validity' => 0);
    }

    CTX('log')->application()->info('SmartCard status: ' . $result->{SMARTCARD}->{status});


    ##! 1: 'Leaving Initialize::execute()'
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::CheckPrereqs

=head1 Description

This activity calls the API for determining which prerequisites have been
met and sets flags for the tasks that are still to be completed.

=head2 Context parameters

The following context parameters set during initialize are read:

token_id, login_id, certs_on_card, owner_id, user_group, token_status

=head1 Functions

=head2 execute

Executes the action.

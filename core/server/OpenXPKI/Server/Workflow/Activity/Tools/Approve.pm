package OpenXPKI::Server::Workflow::Activity::Tools::Approve;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Debug;
use Workflow::Exception qw(configuration_error);

use English;
use Data::Dumper;
use Digest::SHA qw( sha1_hex );

use Encode qw(encode decode);

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $serializer = OpenXPKI::Serialization::Simple->new();

    ## get needed information
    my $context   = $workflow->context();
    my $user      = CTX('session')->data->user;
    my $role      = CTX('session')->data->role;
    my $pki_realm = CTX('session')->data->pki_realm;

    # not supported / used at the moment
    if (defined $context->param('_check_hash')) {
        # compute SHA1 hash over the serialization of the context,
        # skipping volatile entries
        my $current_context;

       CONTEXT:
        foreach my $key (sort keys %{ $context->param() }) {
            next CONTEXT if ($key =~ m{ \A _ }xms);
            next CONTEXT if ($key =~ m{ \A wf_ }xms);
            $current_context->{$key} = $context->param($key);
        }
        ##! 16: 'current_context: ' . Dumper $current_context;

        my $serialized_context = OpenXPKI::Serialization::Simple->new()->serialize($current_context);
        ##! 16: 'serialized current context: ' . Dumper $serialized_context

        my $context_hash = sha1_hex($serialized_context);

        ##! 16: 'context_hash: ' . $context_hash

        if ($context_hash ne $context->param('_check_hash')) {
            # this means that the context changed, do not approve
            # and throw an exception
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_APPROVE_CONTEXT_HASH_CHECK_FAILED',
                params  => {
                    REQUESTED_HASH => $context->param('_check_hash'),
                    CURRENT_HASH   => $context_hash,
                },
            );
        }
    }


    ## get already present approvals
    my @approvals = ();

    my $approvals = $context->param ('approvals');
    if (defined $approvals) {
        ##! 16: 'approvals defined, deserialize them'
        @approvals = @{ $serializer->deserialize($approvals) };
        ##! 16: 'approvals: ' . Dumper \@approvals
    }

    # moved to condition, does no longer work this way as creator is not necessariyl in context
    if ($self->param('check_creator')) {
        configuration_error('The check_creator option is no longer supported - use conditions instead');
    }

    my $mode = $self->param('mode') || 'session';

    # read the approval info from the activity parameter
    if ($mode eq 'generated') {

        my $comment = $self->param('comment');

        configuration_error('The comment parameter is mandatory in generated mode') unless ($comment);
        push @approvals, {
            'mode'      => 'generated',
            'comment'   => $comment,
        };

    } elsif ($mode eq 'session') {
        # look for already present approval by this user with this role
        if ($self->param('multi_role_approval') &&
          (! grep {$_->{session_user} eq $user &&
                   $_->{session_role} eq $role} @approvals)) {
            ##! 64: 'multi role approval enabled and (user, role) pair not found in present approvals'
            push @approvals, {
                'mode'              => 'session',
                'session_user'      => $user,
                'session_role'      => $role,
            };
        }
        elsif (! $self->param('multi_role_approval') &&
               ! grep {$_->{session_user} eq $user} @approvals) {
            ##! 64: 'multi role approval disabled and user not found in present approvals'
            push @approvals, {
                'mode'              => 'session',
                'session_user'      => $user,
                'session_role'      => $role,
            };
        }
        CTX('log')->application()->info('Unsigned approval for workflow ' . $workflow->id() . " by user $user, role $role");

        CTX('log')->audit('approval')->info('operator approval given', {
            wfid => $workflow->id(),
            user => $user,
            role => $role
        });
    } else {
        configuration_error('Unsuported mode given');
    }

    ##! 64: 'approvals: ' . Dumper \@approvals
    $approvals = $serializer->serialize(\@approvals);
    ##! 64: 'approvals serialized: ' . Dumper $approvals

    CTX('log')->application()->debug('Total number of approvals ' . scalar @approvals);


    $context->param ('approvals' => $approvals);

    return 1;
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Approve

=head1 Description

This class implements simple possibility to store approvals as a
serialized array. This allows for easy evaluation of needed approvals
in the condition class Condition::Approved.

The activity has several operational modes, that are determined by the
I<mode> parameter.

=head2 Session Based Approval

This is the default mode, it adds the user and role from the current
session to the list of approvals. Only one approval by the same user is
allowed, if the action is called by the same user mutliple times, the
activity will not update the list of approvals.

If you set the I<mutli_role_approval> parameter to a true value, a user
can approve one time with each role he can impersonate.

=head2 Generated Approval

Adds the information passed via the I<comment> parameter as approval.
Note that there is no duplicate check like in the session approval, if
you call this multiple times you will end up with multiple valid
approvals.

The comment is mandatory, if not given the action will exit with a
workflow configuration error.

=head1 Configuration

=head2 Activity Parameters

=over

=item mode

Operation mode, possible values are I<session> or I<generated>

=item mutli_role_approval

Boolean, allow multiple approvals by same user with differen roles

=item comment

The approval comment to add for generated approvals, mandatory in
generated mode.

=back

=head2 Context Parameters

=over

=item approvals

The serialized array of given approvals, each item is a hash holding the
approval information.

=back

# OpenXPKI::Server::Workflow::Activity::Tools::Approve.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Approve;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Debug;

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
    my $user      = CTX('session')->get_user();
    my $role      = CTX('session')->get_role();
    my $pki_realm = CTX('session')->get_pki_realm();

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

    if ($self->param('check_creator')) {
        # if this config option is set, we check that the user is
        # not the creator
        if ($context->param('creator') eq $user) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_APPROVE_NOT_ALLOWED_TO_APPROVE_YOURSELF',
            );
        }
    }

    if (defined $context->param('_signature')) {
        # we have a signature
        ##! 16: 'signature present'
        my $sig      = $context->param('_signature');
        if ($sig !~ m{\A .* \n\z}xms) {
            ##! 64: 'sig does not end with \n, add it'
            $sig .= "\n";
        }
        my $sig_text = $context->param('_signature_text');
        ##! 64: 'sig: ' . $sig
        ##! 64: 'sig_text: ' . $sig_text

        my $pkcs7 = "-----BEGIN PKCS7-----\n"
                . $sig
                . "-----END PKCS7-----\n";

        ##! 32: 'pkcs7: ' . $pkcs7

        my $default_token = CTX('api')->get_default_token();
        my @signer_chain = @{ $default_token->command({
            COMMAND        => 'pkcs7_get_chain',
            PKCS7          => $pkcs7,
        }) };
        ##! 64: 'signer_chain: ' . Dumper \@signer_chain

        my $x509_signer = OpenXPKI::Crypto::X509->new(
            TOKEN => $default_token,
            DATA  => $signer_chain[0]
        );

        my $sig_identifier = $x509_signer->get_identifier();
        my $signer_subject = $x509_signer->get_subject();

        if (! defined $sig_identifier || $sig_identifier eq '') {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_APPROVE_COULD_NOT_DETERMINE_SIGNER_CERTIFICATE_IDENTIFIER',
                log     => {
                    logger   => CTX('log'),
                    priority => 'info',
                    facility => 'system',
                },
            );
        }

        CTX('log')->log(
            MESSAGE => 'Signed approval for workflow ' . $workflow->id() . " by user $user, role $role",
            PRIORITY => 'info',
            FACILITY => ['audit', 'application' ],
        );

        # look for already present approvals by someone with the same
        # certificate and role
        if ($self->param('multi_role_approval') &&
          (! grep {$_->{session_user} eq $user &&
                   $_->{session_role} eq $role} @approvals)) {
            ##! 64: 'multi role approval enabled and (user, role) pair not found in present approvals'
            push @approvals, {
                'session_user'      => $user,
                'session_role'      => $role,
                'signature'         => $sig,
                'plaintext'         => $sig_text,
                'signer_identifier' => $sig_identifier,
                'signer_subject'    => $signer_subject,
            },
        }
        elsif (! $self->param('multi_role_approval') &&
               ! grep {$_->{session_user} eq $user} @approvals) {
            ##! 64: 'multi role approval disabled and user not found in present approvals'
            push @approvals, {
                'session_user'      => $user,
                'session_role'      => $role,
                'signature'         => $sig,
                'plaintext'         => $sig_text,
                'signer_identifier' => $sig_identifier,
                'signer_subject'    => $signer_subject,
            },
        }
    }
    # Unsigned Approvals
    else {
        # look for already present approval by this user with this
        # role
        if ($self->param('multi_role_approval') &&
          (! grep {$_->{session_user} eq $user &&
                   $_->{session_role} eq $role} @approvals)) {
            ##! 64: 'multi role approval enabled and (user, role) pair not found in present approvals'
            push @approvals, {
                'session_user'      => $user,
                'session_role'      => $role,
            },
        }
        elsif (! $self->param('multi_role_approval') &&
               ! grep {$_->{session_user} eq $user} @approvals) {
            ##! 64: 'multi role approval disabled and user not found in present approvals'
            push @approvals, {
                'session_user'      => $user,
                'session_role'      => $role,
            },
        }
        CTX('log')->log(
		    MESSAGE => 'Unsigned approval for workflow ' . $workflow->id() . " by user $user, role $role",
		    PRIORITY => 'info',
		    FACILITY => ['audit', 'application' ],
        );
    }

    ##! 64: 'approvals: ' . Dumper \@approvals
    $approvals = $serializer->serialize(\@approvals);
    ##! 64: 'approvals serialized: ' . Dumper $approvals

    CTX('log')->log(
        MESSAGE => 'Total number of approvals ' . scalar @approvals,
        PRIORITY => 'debug',
        FACILITY => [ 'application' ],
    );

    $context->param ('approvals' => $approvals);

    return 1;
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Approve

=head1 Description

This class implements simple possibility to store approvals and
(if available) their signatures. The approvals are stored in the
workflow context in a serialized array. This allows for easy
evaluation of needed approvals in the condition class Condition::Approved.

The activity uses no parameters. All parameters will be taken from the
session and the context of the workflow directly. Please note that you
should never a user to directly modify the context parameter
approvals if you use this module and the referenced condition.

=head1 Configuration

The parameter check_creator can be defined in the workflow activity
definition to forbid that the creator of the workflow approves his
own workflow.
If the parameter multi_role is set, a user is allowed to approve the
workflow in different role. If the parameter is not set, the user
can only do one approval in total.
If used with signatures, the parameter pkcs7tool has to be set to
a valid pkcs7tool identifier from config.xml

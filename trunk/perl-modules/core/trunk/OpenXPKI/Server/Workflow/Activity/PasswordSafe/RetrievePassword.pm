# OpenXPKI::Server::Workflow::Activity::PasswordSafe::RetrievePassword
# Written by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::PasswordSafe::RetrievePassword;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $id         = $context->param('_id');
    my $safe_id    = $context->param('safe_id');
    my $realm      = CTX('session')->get_pki_realm();

    my $wf_factory = CTX('workflow_factory')->{$self->{CONFIG_ID}}->{$realm};
    my $unfiltered_wf = $wf_factory->fetch_unfiltered_workflow(
        'I18N_OPENXPKI_WF_TYPE_PASSWORD_SAFE',
        $workflow->id(),
    );
    ##! 16: 'password_safe: ' . Dumper CTX('pki_realm_by_cfg')->{$self->{CONFIG_ID}}->{$realm}
    my $safe_token = CTX('pki_realm_by_cfg')->{$self->{CONFIG_ID}}->{$realm}->{password_safe}->{id}->{$safe_id}->{crypto};
    if (! defined $safe_token) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_PASSWORD_SAFE_RETRIEVE_PASSWORD_TOKEN_NOT_AVAILABLE',
            params  => {
                'SAFE_ID'    => $safe_id,
                'CONFIG_ID' => $self->{CONFIG_ID},
            },
        );
    }
    if (ref $id ne '' && ref $id ne 'ARRAY') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_PASSWORD_SAFE_RETRIEVE_PASSWORD_ID_IS_NEITHER_ARRAY_NOR_SCALAR',
            params  => {
                TYPE => ref $id,
            },
        );
    }
    # turn id into @ids array
    my @ids = ();
    if (ref $id eq '') {
        $ids[0] = $id;
    }
    else {
        @ids = @{ $id };
    }
    ##! 64: 'ids: ' . Dumper \@ids
    my $passwords = {};
    # iterate over each id
    foreach my $current_id (@ids) {
        my $pkcs7 = $unfiltered_wf->context()->param('encrypted_' . $id);
        if (! defined $pkcs7) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_PASSWORD_SAFE_RETRIEVE_PASSWORD_NO_ENCRYPTED_PASSWORD_PRESENT_FOR_ID',
                params  => {
                    ID => $current_id,
                },
            );
        }
        my $decrypted_password = $safe_token->command({
            COMMAND => 'pkcs7_decrypt',
            PKCS7   => $pkcs7,
        });
        ##! 16: 'decrypted password: ' . $decrypted_password
        $passwords->{$current_id} = $decrypted_password;
    }
    my $user = CTX('session')->get_user();
    my $role = CTX('session')->get_role();
    CTX('log')->log(
        MESSAGE  => 'User ' . $user . ' with role ' . $role . ' retrieved passwords for IDs ' . join(q{, }, @ids),
        PRIORITY => 'info',
        FACILITY => 'audit',
    );

    $context->param('_passwords' => $passwords);

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::PasswordSafe::RetrievePassword;

=head1 Description

This activity takes the encrypted password for a given id, which is stored
in the context and decrypts it using the appropriate token.
Alternatively, the parameter id can be an array reference, too, in which
case all the requested passwords are decrypted.
The decrypted password(s) are then available as the temporary context
entry "_passwords" after the activity has finished. _passwords is a hash
reference with the IDs being the keys and the decrypted passwords being
the values.

# OpenXPKI::Server::Workflow::Activity::PasswordSafe::StorePassword
# Written by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::PasswordSafe::StorePassword;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;
use DateTime;
use List::Util qw(first);

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $realm      = CTX('session')->get_pki_realm();

    my $safe_id    = $self->__get_current_safe_id();

    my $context_safe_id = $context->param('safe_id');
    if (! defined $context_safe_id) {
        # safe_id is not yet defined in the context, store it
        $context->param('safe_id' => $safe_id);
    }
    elsif ($context_safe_id ne $safe_id) {
        # context safe id and current safe ID do not match, throw exception
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_PASSWORD_SAFE_STORE_PASSWORD_INVALID_SAFE_ID',
            params  => {
                'CURRENT_SAFE_ID'  => $safe_id,
                'WORKFLOW_SAFE_ID' => $context_safe_id,
            },
        );
    }
    ##! 16: 'password_safe: ' . Dumper CTX('pki_realm_by_cfg')->{$self->{CONFIG_ID}}->{$realm}
    my $default_token = CTX('pki_realm_by_cfg')->{$self->{CONFIG_ID}}->{$realm}->{crypto}->{default};
    if (! defined $default_token) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_PASSWORD_SAFE_STORE_PASSWORD_TOKEN_NOT_AVAILABLE',
            params  => {
                'SAFE_ID'    => $safe_id,
                'CONFIG_ID' => $self->{CONFIG_ID},
            },
        );
    }
    my $cert       = CTX('pki_realm_by_cfg')->{$self->{CONFIG_ID}}->{$realm}->{password_safe}->{id}->{$safe_id}->{certificate};
    ##! 16: 'cert: ' . $cert
    if (! defined $cert) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_PASSWORD_SAFE_STORE_PASSWORD_CERT_NOT_AVAILABLE',
            params  => {
                'SAFE_ID'    => $safe_id,
                'CONFIG_ID' => $self->{CONFIG_ID},
            },
        );
    }

    if (ref $context->param('_input_data') ne 'HASH') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_PASSWORD_SAFE_STOR_EPASSWORD_INPUT_DATA_IS_NOT_A_HASHREF',
            params  => {
                TYPE => ref $context->param('_input_data'),
            },
        );
    }
    # iterate over each key, value paris of _input_data
    while (my ($id, $password) = each %{ $context->param('_input_data') }) {
        ##! 16: 'password: ' . $password
        ##! 16: 'id: ' . $id
        if (! $password) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_PASSWORD_SAFE_STORE_PASSWORD_ID_OR_PASSWORD_UNAVAILABLE',
            );
        }

        my $encrypted_password = $default_token->command({
            COMMAND => 'pkcs7_encrypt',
            CERT    => $cert,
            CONTENT => $password,
        });
        ##! 16: 'encrypted password: ' . $encrypted_password

        $context->param('encrypted_' . $id => $encrypted_password);
    }
    my $user = CTX('session')->get_user();
    my $role = CTX('session')->get_role();
    CTX('log')->log(
        MESSAGE  => 'User ' . $user . ' with role ' . $role . ' stores passwords for IDs ' . join(q{, }, keys %{ $context->param('_input_data') }),
        PRIORITY => 'info',
        FACILITY => 'audit',
    );

    return 1;
}

sub __get_current_safe_id {
    ##! 1: 'start'
    my $self  = shift;
    my $realm = CTX('session')->get_pki_realm();

    my @possible_safes = ();
    my $pki_realm_cfg = CTX('pki_realm_by_cfg')->{$self->{CONFIG_ID}}->{$realm}->{'password_safe'}->{'id'};
    if (! defined $pki_realm_cfg || ref $pki_realm_cfg ne 'HASH') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_PASSWORD_SAFE_STORE_PASSWORD_MISSING_PKI_REALM_CONFIG',
            params  => {
                CONFIG_ID => $self->{CONFIG_ID},
                REALM     => $realm,
            },
        );
    }

    foreach my $key (keys %{ $pki_realm_cfg }) {
        ##! 64: 'key: ' . $key
        push @possible_safes, {
            'id'        => $key,
            'notbefore' => $pki_realm_cfg->{$key}->{notbefore},
            'notafter'  => $pki_realm_cfg->{$key}->{notafter},
        };
    }
    ##! 16: 'possible safes: ' . Dumper \@possible_safes
    # sort safes by notbefore date (latest earliest)
    my @sorted_safes = sort { DateTime->compare($b->{notbefore}, $a->{notbefore}) } @possible_safes;
    ##! 16: 'sorted safes: ' . Dumper \@sorted_safes

    # find the topmost one that is available /now/
    my $now = DateTime->now();
    my $current_safe = first
        {  DateTime->compare($now, $_->{notbefore}) >= 0
        && DateTime->compare($_->{notafter}, $now) > 0 } @sorted_safes;
    if (! defined $current_safe) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_PASSWORD_SAFE_STORE_PASSWORD_NO_SAFE_AVAILABLE',
        );
    }
    ##! 16: 'current safe: ' . Dumper $current_safe

    return $current_safe->{id};
}
1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::PasswordSafe::StorePassword;

=head1 Description

This activity takes passwords and IDs as argument (in the form of a
hash ref called _input_data, which lists ID => password pairs) and
encrypts the passwords using a certificate for which a token definition
is contained in the configuration (section <password_safe>).
The encrypted passwords are stored in the workflow together
with the identifier of the password safe (as taken from the configuration).
For a given ID, the context parameter encrypted_<ID> stores the encrypted
password in PKCS#7 format.

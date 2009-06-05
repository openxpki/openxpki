# OpenXPKI::Server::Workflow::Condition::SCEPClientCSRValidRole.pm
# Written by Alexander Klink for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::SCEPClientCSRValidRole;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

use Data::Dumper;

__PACKAGE__->mk_accessors( 'allowed_roles' );

sub _init {
    my ( $self, $params ) = @_;

    if (exists $params->{allowed_roles}) {
        $self->allowed_roles($params->{allowed_roles});
    }
}

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context   = $workflow->context();
    my $pki_realm = CTX('session')->get_pki_realm();
    my $cfg_id    = CTX('api')->get_config_id({ ID => $workflow->id() });
    my $pkcs10    = $context->param('pkcs10');

    # extract subject from CSR and add a context entry for it
    my $csr_obj = OpenXPKI::Crypto::CSR->new(
        DATA  => $pkcs10,
        TOKEN => CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm}->{crypto}->{default},
    );
    ##! 32: 'csr_obj: ' . Dumper $csr_obj
    my $role_from_extension = $csr_obj->get_parsed('BODY', 'OPENSSL_EXTENSIONS', '1.3.6.1.4.1.311.20.2');
    ##! 16: 'role from extension: ' . Dumper $role_from_extension
    if (! defined $role_from_extension || ref $role_from_extension ne 'ARRAY') {
        # no role is included in the request, we're fine with that, we
        # just use the default role and profile
        return 1;
    }
    my $role = $self->__parse_role($role_from_extension->[0]);
    ##! 16: 'parsed role: ' . $role
    if (defined $self->allowed_roles) {
        my @allowed = split q{,}, $self->allowed_roles;
        ##! 64: 'allowed roles: ' . Dumper \@allowed
        if (! grep { $_ eq $role } @allowed) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SCEPCLIENTCSRVALIDROLE_ROLE_NOT_ALLOWED',
                params  => {
                    ALLOWED_ROLES => $self->allowed_roles,
                },
            );
        }
    }
    else {
        my $roles = CTX('api')->get_roles();
        if (ref $roles ne 'ARRAY') {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SCEPCLIENTCSRVALIDROLE_GET_ROLE_FAILED_NO_ARRAYREF_RETURNED',
                params  => {
                    ROLES => Dumper $roles,
                },
            );
        }
        ##! 64: 'available roles: ' . Dumper $roles
        if (! grep { $_ eq $role } @{ $roles }) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SCEPCLIENTCSRVALIDROLE_ROLE_NOT_VALID',
                params => {
                    VALID_ROLES => join(q{,}, @{ $roles }),
                },
            );
        }
    }
    my $possible_profiles = CTX('api')->get_possible_profiles_for_role({
        ROLE      => $role,
        CONFIG_ID => $cfg_id,
    });
    ##! 64: 'possible profiles: ' . Dumper $possible_profiles
    if (ref $possible_profiles ne 'ARRAY') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SCEPCLIENTCSRVALIDROLE_GET_POSSIBLE_PROFILES_FAILED_NO_ARRAYREF',
            params  => {
                POSSIBLE_PROFILES => Dumper $possible_profiles,
            },
        );
    }

    if (scalar @{ $possible_profiles } == 0) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SCEPCLIENTCSRVALIDROLE_NO_PROFILES_FOR_ROLE',
            params => {
                ROLE => $role,
            }
        );
    }
    elsif (scalar @{ $possible_profiles } > 1) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SCEPCLIENTCSRVALIDROLE_MORE_THAN_ONE_PROFILE_FOR_ROLE',
            params => {
                ROLE     => $role,
                PROFILES => join(q{,}, @{ $possible_profiles }),
            },
        );
    }
    $context->param('cert_role'    => $role);
    $context->param('cert_profile' => $possible_profiles->[0]);

    return 1;
}

sub __parse_role {
    my $self = shift;
    my $role = shift;
    my $result = '';
    for (my $i = 3; $i < length($role); $i += 2) {
        $result = $result . substr($role, $i, 1);
    }
    return $result;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::SCEPClientCSRValidRole

=head1 SYNOPSIS

<action name="do_something">
  <condition name="scep_client_valid_role"
             class="OpenXPKI::Server::Workflow::Condition::SCEPClientCSRValidRole">
  </condition>
</action>

=head1 DESCRIPTION

This condition checks whether an the CSR raised with an SCEP client request 
has a role embedded in a private Microsoft extension and whether this
role is valid. Which roles are "valid" can be restricted using an optional
allowed_roles parameter. If this is not present, all available roles are
considered valid.

It also changes the cert_role and cert_profile context parameters (if
a unique profile is found for a given role) so that the certificate
is actually issued with the requested role/profile.

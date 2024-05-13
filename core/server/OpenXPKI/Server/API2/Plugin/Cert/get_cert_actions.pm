package OpenXPKI::Server::API2::Plugin::Cert::get_cert_actions;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_cert_actions

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;



=head1 COMMANDS

=head2 get_cert_actions

Requires a certificate identifier and optional role.
Returns a list of actions that the given role (defaults to current
session role) can do with the given certificate. The return value is a
nested hash with options available for lifecyle actions. The list of
workflows is read from the roles uicontrol. The key I<certaction>
must contain a list where each item is a hash giving label and workflow
and optional a set of conditions to be met.

Example:

  certaction:
   - label: I18N_OPENXPKI_UI_DOWNLOAD_PRIVATE_KEY
     workflow: certificate_privkey_export
     condition: keyexport

   - label: I18N_OPENXPKI_UI_CERT_ACTION_RENEW
     workflow: certificate_renewal_request
     condition: issued

   - label: I18N_OPENXPKI_UI_CERT_ACTION_AUTHORIZE
     workflow: certificate_authorize
     condition: issued profile
     profile: tls-client tls-client-server

The return value is a list with label and workflow set for each element
that meets the condition(s) given in the I<condition> keyword. Conditions
are optional, if multiple conditions are given (separated by a whitespace)
all conditions must be met.

Valid conditions are:

=over

=item keyexport

A private key must exist in the datapool

=item issued

The certificate is not revoked

=item valid

The certificate is not revoked and within the validity interval

=item owner

current user is the certificate owner (see is_certificate_owner)

=item profile

Certificate must be of a certain profile, the list of allowed profiles
must be given with the I<profile> key, multiple profiles can be given,
separated by whitespace.

=back

In addition to the conditional checks, the given workflow must be
accessible by the given role.

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "get_cert_actions" => {
    identifier => { isa => 'Base64', required => 1, },
    role       => { isa => 'Value', },
} => sub {
    my ($self, $params) = @_;

    my $role    = $params->has_role ? $params->role : CTX('session')->data->role;
    my $cert_id = $params->identifier;
    my $cert    = $self->api->get_cert( identifier => $cert_id, format => 'DBINFO' );
    ##! 2: "cert $cert_id, role $role"

    # check if this is a entity certificate from the current realm
    return {} unless $cert->{req_key} and $cert->{pki_realm} eq CTX('session')->data->pki_realm;

    my @actions;
    my @options;

    my $conn = CTX('config');

    # check if certaction list is defined for this role
    if ($conn->exists( ['uicontrol', $role, 'certaction' ])) {
        @options = $conn->get_list(['uicontrol', $role, 'certaction']);
        ##! 32: 'Got action list for role ' . Dumper \@options
    }
    # default uicontrol
    elsif ($conn->exists( ['uicontrol', '_default', 'certaction'] )) {
        @options = $conn->get_list(['uicontrol', '_default', 'certaction']) unless(@options);
        ##! 32: 'Got action list for ui default ' . Dumper \@options
    }
    # Legacy - fallback to the default set
    else {
        ##! 32: 'No action list, fall back to default'
        @options = (
            {
                label => 'I18N_OPENXPKI_UI_DOWNLOAD_PRIVATE_KEY',
                workflow => 'certificate_privkey_export',
                condition => 'keyexport'
            },
            {
                label => 'I18N_OPENXPKI_UI_CERT_ACTION_RENEW',
                workflow => 'certificate_renewal_request',
                condition => 'issued'
            },
            {
                label => 'I18N_OPENXPKI_UI_CERT_ACTION_REVOKE',
                workflow => 'certificate_revocation_request_v2',
                condition => 'issued'
            },
            {
                label => 'I18N_OPENXPKI_UI_CERT_ACTION_UPDATE_METADATA',
                workflow => 'change_metadata'
            }
        );
    }

    OPTION:
    for my $item (@options) {
        ##! 32: 'Checking Item ' . Dumper $item
        if ($item->{condition}) {
            my @cond = split /[\W]/, $item->{condition};
            ##! 32: 'Conditions ' . join " + ", @cond
            for my $rule (@cond) {
                if ($rule eq 'keyexport') {
                    next OPTION unless $self->api->private_key_exists_for_cert( identifier => $cert_id );
                }
                elsif ($rule eq 'issued') {
                    next OPTION  unless ($cert->{status} eq 'ISSUED' or $cert->{status} eq 'EXPIRED');
                }
                elsif ($rule eq 'valid') {
                    next OPTION  unless $cert->{status} eq 'ISSUED';
                }
                elsif ($rule eq 'owner') {
                    next OPTION  unless $self->api->is_certificate_owner(identifier => $cert_id);
                }
                elsif ($rule eq 'profile') {
                    my $profile = $self->api->get_profile_for_cert( identifier => $cert_id );
                    my @profiles = split /[\s]/, $item->{profile};
                    next OPTION unless ((grep { $_ eq $profile } @profiles) != 0);
                }
            }
        }

        # all conditions are met, check workflow permissions
        if ($conn->exists([ 'workflow', 'def', $item->{workflow}, 'acl', $role, 'creator' ] )) {
            ##! 32: 'Adding Item ' . $item->{label}
            push @actions, {
                label => $item->{label},
                workflow => $item->{workflow},
                autorun => ($item->{autorun} ? 1 : 0),
                ($item->{param} ? (param => $item->{param}) : ()),
            };
        }
    }

    return { workflow => \@actions };
};

__PACKAGE__->meta->make_immutable;

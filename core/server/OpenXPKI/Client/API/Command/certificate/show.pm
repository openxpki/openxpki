package OpenXPKI::Client::API::Command::certificate::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::certificate::show

=head1 DESCRIPTION

Show details for a given certificate identifier.

By default returns a hash with key certificate fields (subject, issuer,
validity, status, etc.). For revoked certificates the revocation details
are included automatically. If the certificate is a local entity the
associated profile name is added as well.

=cut

command "show" => {
    identifier => { isa => 'Str', label => 'Certificate identifier to look up' },
    attributes => { isa => 'Bool', label => 'Include meta and system attributes', default => 0 },
    certonly   => { isa => 'Bool', label => 'Return only the raw PEM block', default => 0 },
} => sub ($self, $param) {

    my $identifier = $param->identifier;

    if ($param->certonly) {
        my $res = $self->run_command('get_cert', {
            identifier => $identifier, format => 'PEM',
        });
        return $res->result;
    }

    my $res = $self->run_command('get_cert', {
        identifier => $identifier,
        format => 'DBINFO',
        ($param->attributes ? (attribute => ['meta_%','system_%']) : ()),
    });

    my $raw = $res->params();
    my $cert;

    map { $cert->{$_} = $raw->{$_} } (
        "authority_key_identifier", "cert_key", "cert_key_hex",
        "identifier", "issuer_dn", "issuer_identifier",
        "notafter", "notbefore", "pki_realm",
        "status", "subject", "subject_key_identifier",
    );

    map { $cert->{$_} = $raw->{$_} } ('invalidity_time','reason_code','revocation_time')
        unless ($cert->{status} eq 'ISSUED');

    $cert->{cert_attributes} = $raw->{cert_attributes} if ($param->attributes);

    if ($raw->{req_key}) {
        $res = $self->run_command('get_profile_for_cert', { identifier => $identifier });
        $cert->{'profile'} = $res->result();
    }

    return $cert;
};

__PACKAGE__->meta->make_immutable;

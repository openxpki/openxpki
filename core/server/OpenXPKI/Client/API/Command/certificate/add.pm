package OpenXPKI::Client::API::Command::certificate::add;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    protected => 1,
;

use OpenXPKI::Crypt::X509;

=head1 NAME

OpenXPKI::Client::API::Command::certificate::add

=head1 DESCRIPTION

Add a new (non-token) certificate.

=cut

command "add" => {
    cert => { isa => 'FileContents', label => 'Certificate file', required => 1 },
    force_nochain => { isa => 'Bool', default => 0, 'label' => 'Enforce import even if the chain can not be built', },
    force_noverify => { isa => 'Bool', default => 0, 'label' => 'Enforce import even if the chain can not be be validated', },

} => sub ($self, $param) {

    my $x509 = OpenXPKI::Crypt::X509->new($param->cert->$*); # type "FileContents" is a ScalarRef
    my $cert_identifier = $x509->get_cert_identifier();
    my $res = $self->run_protected_command('import_certificate', {
        data => $x509->pem,
        ignore_existing => 1,
        force_nochain  => $param->force_nochain,
        force_noverify => $param->force_noverify,
    });

    $self->log->debug("certificate $cert_identifier was imported");

    return $res;
};

__PACKAGE__->meta->make_immutable;

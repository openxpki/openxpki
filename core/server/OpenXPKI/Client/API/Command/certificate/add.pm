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

Import a PEM-encoded certificate into the database.

Reads the certificate from the given file and load it into the database.If the
certificate already exists in the database, the import is silently skipped.

The chain of the certificate must already exist, skip chain building with
C<force_nochain>. Set C<force_noverify> to skip chain validation, e.g. to
import expired certificates.

=cut

command "add" => {
    cert => { isa => 'FileContents', label => 'PEM-encoded certificate file to import', required => 1 },
    force_nochain => { isa => 'Bool', default => 0, 'label' => 'Import even if the issuer chain cannot be built' },
    force_noverify => { isa => 'Bool', default => 0, 'label' => 'Import even if the chain cannot be validated' },

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

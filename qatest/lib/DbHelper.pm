#
# IMPORTANT:
#
#   This is just a helper class for database access in various unit tests.
#   Please don't use this for production stuff!!!
#

=head1 NAME

DbHelper

=head1 SYNOPSIS

    use DbHelper;

    my $ch = CertHelper->new(
        commonName => 'my.commonname.org',
        basedir => 't/mycert.d',
    );

    $ch->createcert;

=cut

package DbHelper;
use Moose;

use OpenXPKI::Server::Init;
use OpenXPKI::i18n;
use OpenXPKI::Server::Context qw( CTX );

has dbi => (
    is => 'ro',
    isa => 'OpenXPKI::Server::Database',
    lazy => 1,
    default => sub {
        CTX('dbi') or die "Could not instantiate database backend\n";
    },
);

sub BUILD {
    my $self = shift;
    $ENV{OPENXPKI_CONF_PATH} = '/etc/openxpki/config.d';
    # TODO #legacydb Remove dbi_backend once we got rid of the old DB layer
    OpenXPKI::Server::Init::init({
        TASKS  => ['config_versioned','log','api','crypto_layer','dbi','dbi_backend'],
        SILENT => 1,
        CLI => 1,
    });
}

=head1 METHODS

=cut

=head2 delete_certificate

Delete the certificate(s) with the given subject_key_identifier(s) and return
the number of deleted table rows.

Expects either a string or an ArrayRef of strings.

Example:

    $db_helper->delete_certificate("39:D5:86:02:69:BC:E1:3D:7A:25:88:A9:B9:CD:F5:EB:DE:6F:91:7B");
    $db_helper->delete_certificate(
        [
            "39:D5:86:02:69:BC:E1:3D:7A:25:88:A9:B9:CD:F5:EB:DE:6F:91:7B",
            "DA:1B:CD:D2:00:A9:71:82:05:E7:79:FC:A3:AD:10:5D:8F:39:1B:AC",
        ]
    );

=cut
sub delete_certificate {
    my ($self, $cert_ids) = @_;
    $cert_ids = [ $cert_ids ] unless ref $cert_ids eq 'ARRAY';

    $self->dbi->start_txn;
    my $count = $self->dbi->delete(
        from => 'certificate',
        where => { subject_key_identifier => $cert_ids },
    );
    $self->dbi->commit;
    return $count;
}

1;

package OpenXPKI::Config::Loader;

use Storable qw(freeze thaw);
use Digest::SHA qw(sha256_hex);
use MIME::Base64;
use OpenXPKI::FileUtils;
use Proc::SafeExec;
use Moose;

extends 'Connector::Builtin::Memory';

has 'checksum' => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    init_arg => undef,
    default => '',
);

has 'signer' => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    init_arg => undef,
    default => '',
);

has ca_certificate_path => (
    is => 'rw',
    isa => 'Str',
);

has ca_certificate_file => (
    is => 'rw',
    isa => 'Str',
);

has 'tmpdir' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => '/tmp',
);

around BUILDARGS => sub {
    my ($orig, $class, %params) = @_;

    # Environment always wins
    $params{LOCATION} = $ENV{OPENXPKI_CONF_LOADER} if $ENV{OPENXPKI_CONF_LOADER};

    return $class->$orig(%params);
};

sub _build_config {

    my $self = shift;

    # Input file must hold the tree hash serialized with Storable, wrapped
    # with base64. It can optionally be wrapped into a signed PKCS7 structure
    # The files can be identified by a custom header
    # -----BEGIN OPENXPKI CONFIG V1-----
    # -----BEGIN OPENXPKI SIGNED CONFIG V1-----

    my $fu = OpenXPKI::FileUtils->new;
    my $infile = $fu->read_file($self->LOCATION);

    my ($head, $config) = ($infile =~ m{-----BEGIN\s([^-]+)-----(.*?)-----END}xms);

    if (!$head) {
        die "Unrecognized config file format";
    }

    # plain format
    if ($head eq "OPENXPKI CONFIG V1") {

        $config = decode_base64($config);
        $self->signer('');

    # PKCS7 (smime) wrapped and signed
    } elsif ($head eq "OPENXPKI SIGNED CONFIG V1") {

        my $signed = $fu->get_safe_tmpfile({ TMP => $self->tmpdir() });
        my $data = $fu->get_safe_tmpfile({ TMP => $self->tmpdir() });
        my $signer = $fu->get_safe_tmpfile({ TMP => $self->tmpdir() });

        $fu->write_file({
            FILENAME => $signed,
            CONTENT => "-----BEGIN PKCS7-----$config-----END PKCS7-----",
            FORCE => 1
        });

        my @command = ('openssl', 'smime', '-verify', '-in', $signed, '-signer', $signer, '-out', $data, '-inform', 'PEM');
        if (my $ca = $self->ca_certificate_path()) {
            push @command, '-CApath', $ca;
        } elsif ($ca = $self->ca_certificate_file()) {
            push @command, '-CAfile', $ca;
        } else {
            push @command, '-noverify';
        }

        my $command = Proc::SafeExec->new({
            exec   => \@command,
            stdin  => 'new',
            stdout => 'new',
            #stderr => 'new',
        });
        $command->wait();

        if (!($command->exit_status() == 0 && -e $data && -e $signer)) {
            die "Signature verification failed (OpenSSL returned ".$command->exit_status().")";
        }

        $config = $fu->read_file($data);
        $self->signer( $fu->read_file($signer) );

    } else {

        die "Unsupported config file format ($head)";
    }

    my $tree = thaw($config);
    $self->checksum( sha256_hex(freeze($tree)) );
    return $tree;
}

1;

__DATA__


=head1 NAME

OpenXPKI::Config::Loader - Backend connector to load system config from BLOB

=head1 SYNOPSIS

    use OpenXPKI::Config::Loader;

    my $cfg = OpenXPKI::Config::Backend->new(LOCATION => "/etc/openxpki/config.oxi");


=head1 DESCRIPTION

This connector loads a configuration that was stored / build before with
I<openxpkiadm buildconfig>. The configuration can be signed with a PKCS7
signature.

=head1 CONFIGURATION

The class requires at minimum the path to the loadable configuration. This
can be given as LOCATION parameter or via the environment variable
C<OPENXPKI_CONF_LOADER>.

After initialisation, the sha256 checksum is available in the I<checksum>
attribute.

If the file holds a signed configuration, the signer certificate is available
in the I<signer> variable.

If I<ca_certificate_path> or I<ca_certificate_file> is set, the signer
certificate is validated against those CAs, if none is set, the signature is
verified but B<no chain validation is done!>.

Note: Verification currently works only if the chain is included in the
signature or the signer is issued by the root (looks like a bug in openssl)

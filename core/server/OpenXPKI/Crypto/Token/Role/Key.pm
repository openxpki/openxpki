package OpenXPKI::Crypto::Token::Role::Key;
use OpenXPKI -role;

use OpenXPKI::Server::Context qw( CTX );

requires 'fileutil';
# does not work for whatever reason
#requires 'certificate';


has 'key_name' => (
    is => 'ro',
    isa => 'Str',
    default => sub { return shift->certificate->get_subject_key_id; }
);

has 'key_store' => (
    is => 'ro',
    isa => 'Str',
    default => 'DATAPOOL',
);

has 'export' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    reader => 'is_exportable',
);

has '_key' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => '__load_key',
    predicate => 'is_available',
);

has '_key_file' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $filename = sprintf("%s/%s.pem",
            $self->fileutil->get_tmp_dirhandle(),
            $self->certificate->get_subject_key_id);

        $self->fileutil->write_file({
            FILENAME => $filename,
            CONTENT => $self->_key,
        });
        return $filename;
    },
);

sub __load_key {
    my $self = shift;

    if ($self->key_store eq 'OPENXPKI') {
        return $self->fileutil->read_file($self->key_name);
    }

    OpenXPKI::Exception->throw (
        message => "Unsupported storage backend",
    ) unless ($self->key_store eq 'DATAPOOL');

    my $dp = CTX('api2')->get_data_pool_entry(
        namespace => 'sys.crypto.keys',
        key => $self->key_name,
    );

    OpenXPKI::Exception->throw (
        message => "Unable to load key from datapool",
        params => { key_name => $self->key_name }
    ) unless ($dp && $dp->{value});

    return $dp->{value};
}

sub get_key_file {

    my $self = shift;
    OpenXPKI::Exception->throw(
        message => 'Token is not exportable',
    ) unless ($self->is_exportable);

    return $self->_key_file;

}

1;

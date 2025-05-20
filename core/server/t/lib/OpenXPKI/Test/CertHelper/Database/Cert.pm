package OpenXPKI::Test::CertHelper::Database::Cert;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Test::CertHelper::Database::Cert - represents a test certificate (PEM + meta data)

=head1 SYNOPSIS

    my $cert = OpenXPKI::Test::CertHelper::Database::Cert->new(
        label => "ACME Root CA",
        db => {
            authority_key_identifier => 'C6:17:6E:AC:2E:7F:3C:9B:B0:AB:83:B6:5A:C2:F0:14:6C:A9:A4:4A',
            cert_key => '15209797771827521724',
            # ... all fields of table "certificate"
        },
    );

    diag $cert->label;

    # shortscuts to some DB fields:
    diag $cert->id;               # identifier
    diag $cert->subject_key_id;   # subject_key_identifier
    diag $cert->data;             # PEM encoded data

    # access to all DB fields:
    diag $cert->db->{authority_key_identifier};

=cut

has label => (
    is => "rw",
    isa => "Str",
    required => 1,
);

# internal name that corresponds to the name of the private key file
has name => (
    is => "rw",
    isa => "Str",
    required => 1,
);

# HashRef containing all fields from table "certificate"
has db => (
    is => "rw",
    isa => "HashRef",
    required => 1,
);

# HashRef containing these fields from table "aliases": alias, group_id, generation
has db_alias => (
    is => "rw",
    isa => "HashRef",
    required => 1,
);

# private key data
has private_key => (
    is => "rw",
    isa => "Str",
    required => 1,
);


sub id {
    my $self = shift;
    return $self->db->{identifier};
}

sub subject_key_id {
    my $self = shift;
    return $self->db->{subject_key_identifier};
}

sub data {
    my $self = shift;
    return $self->db->{data};
}

__PACKAGE__->meta->make_immutable;

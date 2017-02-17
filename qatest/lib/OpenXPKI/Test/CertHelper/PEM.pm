package OpenXPKI::Test::CertHelper::PEM;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::CertHelper::PEM - Represents a test certificate (PEM + meta data)

=head1 SYNOPSIS

    my $pem = OpenXPKI::Test::CertHelper::PEM->new(
        label => "ACME Root CA",
        database => {
            authority_key_identifier => 'C6:17:6E:AC:2E:7F:3C:9B:B0:AB:83:B6:5A:C2:F0:14:6C:A9:A4:4A',
            cert_key => '15209797771827521724',
            # ... all fields of table "certificate"
        },
    );

    print $pem->id, "\n";
    print $pem->data, "\n";

=cut

has database => (
    is => "rw",
    isa => "HashRef",
    required => 1,
);

has label => (
    is => "rw",
    isa => "Str",
    required => 1,
);

sub id {
    my $self = shift;
    return $self->database->{subject_key_identifier};
}

sub data {
    my $self = shift;
    return $self->database->{data};
}

__PACKAGE__->meta->make_immutable;

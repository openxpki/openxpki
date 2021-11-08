package OpenXPKI::Role::SubjectAltNameMaps;

use Socket qw(inet_aton);
use Moose::Role;

has subject_alt_name_map => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { return {
        otherName => 'otherName',
        rfc822Name => 'email',
        dNSName => 'DNS',
        x400Address => '', # not supported by openssl
        directoryName => 'dirName',
        ediPartyName => '', # not supported by openssl
        uniformResourceIdentifier => 'URI',
        iPAddress  => 'IP',
        registeredID => 'RID',
    }; }
);

sub map_san_openxpki_to_openssl {

    my $self = shift;
    my $list = shift;

    my %map = reverse %{$self->subject_alt_name_map};

    my @res;
    foreach my $item (@{$list}) {

        my $san_type = $map{$item->[0]} || die "Unknown SAN type " . $item->[0];
        my $san_val = $item->[1];
        if ($san_type eq 'iPAddress') {
            $san_val = inet_aton($san_val);
        }
        push @res, { $san_type => $san_val };

    }
    return \@res;
}

1;
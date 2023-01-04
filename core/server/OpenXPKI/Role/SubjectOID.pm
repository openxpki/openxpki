package OpenXPKI::Role::SubjectOID;

use Moose::Role;

has subject_oid_map => (
    is => 'rw',
    isa => 'HashRef',
    required => 0,
    lazy => 1,
    builder => '__build_subject_oid_map',
);

has subject_oid_reverse_map => (
    is => 'rw',
    isa => 'HashRef',
    required => 0,
    lazy => 1,
    builder => '__build_subject_oid_reverse_map'
);

sub __build_subject_oid_map {
    return {
        "2.5.4.3"                       => ['CN','commonName'],
        "2.5.4.6"                       => ['C','countryName'],
        "2.5.4.7"                       => ['L','localityName'],
        "2.5.4.8"                       => ['ST','stateOrProvinceName'],
        "2.5.4.10"                      => ['O','organizationName'],
        "2.5.4.11"                      => ['OU','organizationalUnitName'],
        "1.2.840.113549.1.9.1"          => ["emailAddress","E"],
        "0.9.2342.19200300.100.1.1"     => ['UID','userID'],
        "0.9.2342.19200300.100.1.25"    => ['DC','domainComponent'],
        '2.5.4.12'                      => [ 'title', 'Title' ],
        '2.5.4.13'                      => [ 'description', 'Description' ],
        '2.5.4.14'                      => 'searchGuide',
        '2.5.4.15'                      => 'businessCategory',
        '2.5.4.16'                      => 'postalAddress',
        '2.5.4.17'                      => 'postalCode',
        '2.5.4.18'                      => 'postOfficeBox',
        '2.5.4.19',                     => 'physicalDeliveryOfficeName',
        '2.5.4.20',                     => 'telephoneNumber',
        '2.5.4.23',                     => 'facsimileTelephoneNumber',
        '2.5.4.4'                       => [ 'surname', 'Surname', 'SN' ],
        '2.5.4.41'                      => [ 'name', 'Name' ],
        '2.5.4.42'                      => ['GN','givenName'],
        '2.5.4.43'                      => 'initials',
        '2.5.4.44'                      => 'generationQualifier',
        '2.5.4.45'                      => 'uniqueIdentifier',
        '2.5.4.46'                      => 'dnQualifier',
        '2.5.4.51'                      => 'houseIdentifier',
        '2.5.4.65'                      => 'pseudonym',
        '2.5.4.5'                       => ['serialNumber','SN'],
        '2.5.4.9'                       => 'streetAddress',
    };
}

sub __build_subject_oid_reverse_map {

    my $self = shift;
    my $map = $self->subject_oid_map();
    my $flip_map;
    foreach my $oid (keys %{$map}) {
        my $val = $map->{$oid};
        if (ref $val) {
            map { $flip_map->{$_} = $oid; } @{$val};
        } else {
            $flip_map->{$val} = $oid;
        }
    }
    return $flip_map;
}

sub render_rdn {

    my $self = shift;
    my $rdn = shift;

    my $name = $self->render_rdn_type($rdn);
    my $val = $self->render_rdn_value($rdn);
    return "$name=$val";
}

sub render_rdn_type {

    my $self = shift;
    my $rdn = shift;

    my $name = $rdn->{type};
    my $oids = $self->subject_oid_map();
    if (my $oid = $oids->{$name}) {
        return $oid unless (ref $oid);
        return $oid->[0];
    }
    return $name;
}

sub render_rdn_value {

    my $self = shift;
    my $rdn = shift;

    my ($val) = values %{$rdn->{value}};
    return $val;
}

sub get_oid_for_name {

    my $self = shift;
    my $name = shift;

    my $map = $self->subject_oid_reverse_map();
    return $map->{$name};

}

1;

__END__;
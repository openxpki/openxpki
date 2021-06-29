package OpenXPKI::Crypt::DN;

use Moose;

with 'OpenXPKI::Role::SubjectOID';

has sequence => (
    is => 'ro',
    isa => 'ArrayRef',
);

has subject => (
    is => 'ro',
    isa => 'Str',
    reader => 'get_subject',
    lazy => 1,
    builder => '__create_subject',
);

has openssl_subject => (
    is => 'ro',
    isa => 'Str',
    reader => 'get_openssl_subject',
    lazy => 1,
    builder => '__create_openssl_subject',
);


sub __create_subject {

    my $self = shift;
    my @subject;
    foreach my $rdn (reverse @{$self->sequence()}) {
        # avoid join to not mess up utf8 encoded strings
        my $comp;
        foreach my $seq (@$rdn) {
            $comp .= '+' if ($comp);
            $comp .= $self->render_rdn($seq);
        }
        push @subject, $comp;
    }
    return join(",", @subject);
}

sub __create_openssl_subject {

    my $self = shift;
    my $subject;
    foreach my $rdn (@{$self->sequence()}) {
        my $comp = '';
        # avoid join to not mess up utf8 encoded strings
        foreach my $seq (@$rdn) {
            $comp .= '+' if ($comp);
            $comp .= $self->render_rdn($seq);
        }
        $subject .= '/'.$comp;
    }
    return $subject;

}

1;

__END__;
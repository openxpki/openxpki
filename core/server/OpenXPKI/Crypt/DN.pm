package OpenXPKI::Crypt::DN;

use Moose;
use OpenXPKI::DN;

with 'OpenXPKI::Role::SubjectOID';

has sequence => (
    is => 'rw',
    isa => 'ArrayRef',
    writer => '_sequence',
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

sub from_string {

    my $self = OpenXPKI::Crypt::DN->new();
    my $string = shift;

    my $dn = OpenXPKI::DN->new( $string );

    my @rdnlist = $dn->get_parsed();
    my @result;
    foreach my $comp (@rdnlist) {
        my @temp = map {
            {
                type => $self->get_oid_for_name($_->[0]),
                value => { utf8String => $_->[1] }
            };
        } (@$comp);
        push @result, \@temp;
    }
    $self->_sequence(\@result);
    return $self;

}

1;

__END__;
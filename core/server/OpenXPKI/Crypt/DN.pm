package OpenXPKI::Crypt::DN;

use Moose;
with 'OpenXPKI::Role::SubjectOID';

use OpenXPKI::DN;

=head1 Name

OpenXPKI::Crypt::DN

=head1 Description

Helper class to read, build, convert DNs between array/hash and string
representations.

=head1 Attributes

=head2 sequence

The internal representation of the DN, must be set at the time of
constructionand can not be updated later.

The expected format is the DN structure as returned from Convert::ASN1
which is a list holding the DN components starting with the least
significant element (usual the country). Each element of the list must
be an array itself holding the RDNs as a hash:

  [
    [
      {
        'value' => { 'utf8String' => 'DE' },
        'type' => '2.5.4.6'
      }
    ],
    [
       {
         'value' => { 'utf8String' => 'OpenXPKI' },
         'type' => '2.5.4.10'
       },
    ],
    [
      {
          'type' => '2.5.4.3',
          'value' => { 'utf8String' => 'Foobar' }
      },
      {
          'type' => '0.9.2342.19200300.100.1.1',
          'value' => { 'utf8String' => 'foobar' }
      }
    ]
  ];

=cut

# must be a sequence as created by the ASN1 parser module
has sequence => (
    is => 'rw',
    isa => 'ArrayRef',
    required => 1,
    writer => '_sequence',
);

=head1 Methods

=head2 get_subject

Returns the subject as string according to RFC2253 (starting with CN)

=cut

has subject => (
    is => 'ro',
    isa => 'Str',
    reader => 'get_subject',
    lazy => 1,
    builder => '__create_subject',
);

=head2 get_openssl_subject

Returns the subject as string in OpenSSL format (starting with /C=XX)

=cut


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

=head2 as_hash

Returns a hashref with the RDN types as keys, known OIDs are translated
to their textual representation (see OpenXPKI::Role::SubjectOID). The
values are lists holding the textual representation of the RNS components.

To provide backwards compatibility with OpenXPKI::DN all keys are in
uppercase letters and the value elements are listed with the "most
significant" item first.

=cut

sub as_hash {

    my $self = shift;
    my $hash;
    # to stay compatible with the old DN parser we reverse the DN
    # and uppercase all type names
    foreach my $rdn (reverse @{$self->sequence()}) {
        foreach my $seq (@$rdn) {
            my $name = uc($self->render_rdn_type($seq));
            $hash->{$name} = [] unless(exists $hash->{$name});
            my $val = $self->render_rdn_value($seq);
            push @{$hash->{$name}}, $val;
        }
    }
    return $hash;

}
=head1 Builders

All builder methods are static methods to the class and return a fresh
instance of this class or undef in case the input can not be parsed.

=head2 from_string

Expecting the DN as string in RFC2253 or OpenSSL format.

Uses OpenXPKI::DN internally which has very limited support for special
chars and will likely choke on values using plus signs or commas.

=cut

sub from_string {

    my $self = OpenXPKI::Crypt::DN->new( sequence => [] );
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

__PACKAGE__->meta->make_immutable;

__END__;
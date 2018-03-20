package OpenXPKI::Crypt::CRL;

use strict;
use warnings;
use English;

# no idea why but use causes the class to init
require Crypt::X509::CRL;

use Moose;
use Data::Dumper;
use MIME::Base64 qw(decode_base64);

has data => (
    is => 'ro',
    required => 1,
    isa => 'Str',
);

has pem => (
    is => 'ro',
    required => 0,
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $pem = encode_base64($self->data());
        $pem =~ s{\s}{}g;
        $pem =~ s{ (.{64}) }{$1\n}xmsg;
        return "-----BEGIN X509 CRL-----\n$pem\n-----END X509 CRL-----";
    },
);

has itemcnt => (
    is => 'ro',
    isa => 'Int',
    required => 0,
    lazy => 1,
    default => sub { 0; } #my $self = shift; scalar keys %{$self->_crl()->revocation_list}; },
);

has _crl => (
    is => 'ro',
    required => 1,
    isa => 'Crypt::X509::CRL',
);

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;
    my $data = shift;

    if ($data =~ m{-----BEGIN[^-]*CRL-----(.+)-----END[^-]*CRL-----}xms ) {
        $data = decode_base64($1);
    }

    my $crl = Crypt::X509::CRL->new( crl => $data );
    if ($crl->error) {
        die $crl->error;
    }

    return $class->$orig({ data => $data, _crl => $crl });

};

1;

__END__;


package OpenXPKI::Template::Plugin::PKCS10;

=head1 OpenXPKI::Template::Plugin::PKCS10

Plugin for Template::Toolkit to retrieve properties of a certificate
request from the PKCS10 PEM formatted request. All methods require the
PEM encoded request as first argument.

=cut

=head2 How to use

You need to load the plugin into your template before using it. As we do not
export the methods, you need to address them with the plugin name, e.g.

    [% USE PKCS10 %]

    Your request with the key [% PKCS10.subject_key_identifier(context.pkcs10) %]...

Will result in

    Your request with the key AB:CD...:2A

=cut

use strict;
use warnings;
use utf8;

use base qw( Template::Plugin );
use Template::Plugin;

use Data::Dumper;
use Digest::SHA qw(sha1_hex sha1_base64);
use OpenXPKI::Crypt::PKCS10;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );


sub new {
    my $class = shift;
    my $context = shift;

    return bless {
    _CONTEXT => $context,
    }, $class;
}


=head2 _load(pkcs10)

Internal method used to parse the request. Does some caching based on the
SHA1 hash of the incoming data so multiple requests on the same data blob
do not cause multiple calls to the parser.

=cut

sub _load {

    my $self = shift;
    my $pkcs10 = shift;

    return unless ($pkcs10);

    # To prevent loading the same item again and again, we always cache
    # the last hash and reuse it
    if ($self->{_pkcs10} && ($self->{_hash} eq sha1($pkcs10))) {
        return $self->{_pkcs10};
    }

    $self->{_pkcs10} = undef;
    $self->{_hash} = undef;

    eval {
        if (my $csr = OpenXPKI::Crypt::PKCS10->new( $pkcs10 )) {
            $self->{_pkcs10} = $csr;
            # this is the hash on the "unnormalized" PEM block and must not
            # be used for anything else than cache control
            $self->{_hash} = sha1($pkcs10);
        }
    };
    return $self->{_pkcs10};

}


=head2 pem

Print the PEM encoded PKCS10 container

=cut

sub pem {

    my $self = shift;
    my $pkcs10 = shift;

    my $csr = $self->_load($pkcs10);
    if (!$csr) { return; }

    return $csr->pem();

}

=head2 binary

Print the raw binary data of the container

=cut

sub binary {

    my $self = shift;
    my $pkcs10 = shift;

    my $csr = $self->_load($pkcs10);
    if (!$csr) { return; }

    return $csr->data();

}


=head2 subject_key_identifier

Return the public key identifier as defined in RFC 5280 (hash of DER
encoded public key). Result is in hex notation, uppercased with colon.

=cut

sub subject_key_identifier {

    my $self = shift;
    my $pkcs10 = shift;

    my $csr = $self->_load($pkcs10);
    if (!$csr) { return; }

    return $csr->get_subject_key_id();

}

=head2 transaction_id

Return the transaction id which is the sha1 hash on the DER encoded request
given in hexadecimal format.

=cut

sub transaction_id {

    my $self = shift;
    my $pkcs10 = shift;

    my $csr = $self->_load($pkcs10);
    if (!$csr) { return; }
    return $csr->get_transaction_id();

}

=head2 digest

Return the digest of the raw request which is the sha1 hash on the DER encoded
"inner" request without the signature parts given in hexadecimal format.

=cut

sub digest {

    my $self = shift;
    my $pkcs10 = shift;

    my $csr = $self->_load($pkcs10);
    if (!$csr) { return; }
    return $csr->digest();

}

=head2 dn

Returns the DN of the request as parsed hash, if second parameter
is given returns the named part as string. Note: In case the named
property has more than one item, only the first one is returned!

=cut

sub dn {
    my $self = shift;
    my $pkcs10 = shift;
    my $component = shift;

    my $csr = $self->_load($pkcs10);
    if (!$csr) { return; }

    my $dn= OpenXPKI::DN->new($csr->get_subject())->get_hashed_content();

    if (!$component) {
        return $dn;
    }

    if (!$dn->{$component}) {
        return;
    }

    return $dn->{$component}->[0];

}

1;

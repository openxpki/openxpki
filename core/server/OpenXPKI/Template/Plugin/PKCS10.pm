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

    Your request with the key [% PKCS10.subject_key_identifier(pcsk10) %]...

Will result in

    Your request with the key AB:CD...:2A

=cut

use strict;
use warnings;
use utf8;

use base qw( Template::Plugin );
use Template::Plugin;

use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use Crypt::PKCS10 1.8;
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

    if ($self->{_pkcs10} && ($self->{_hash} eq sha1_hex($pkcs10))) {
        return $self->{_pkcs10};
    }

    $self->{_pkcs10} = undef;
    $self->{_hash} = undef;

    eval {
        Crypt::PKCS10->setAPIversion(1);
        my $decoded = Crypt::PKCS10->new($pkcs10, ignoreNonBase64 => 1, verifySignature => 0);
        if ($decoded) {
            $self->{_pkcs10} = $decoded;
            $self->{_hash} = sha1_hex($pkcs10);
        }
    };
    return $self->{_pkcs10};

}

=head2 subject_key_identifier

Return the public key identifier as defined in RFC 5280 (hash of DER
encoded public key). Result is in hex notation, uppercased with colon.

=cut

sub subject_key_identifier {

    my $self = shift;
    my $pkcs10 = shift;

    my $decoded = $self->_load($pkcs10);
    if (!$decoded) { return; }

    return uc(
        join ':', (
            unpack '(A2)*', sha1_hex(
                $decoded->{certificationRequestInfo}{subjectPKInfo}{subjectPublicKey}[0]
            )
        )
    );
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

    my $decoded = $self->_load($pkcs10);
    if (!$decoded) { return; }

    my $dn= OpenXPKI::DN->new($decoded->subject())->get_hashed_content();

    if (!$component) {
        return $dn;
    }

    if (!$dn->{$component}) {
        return;
    }

    return $dn->{$component}->[0];

}

1;
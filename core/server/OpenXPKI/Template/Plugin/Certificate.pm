package OpenXPKI::Template::Plugin::Certificate;

=head1 OpenXPKI::Template::Plugin::Certificate

Plugin for Template::Toolkit to retrieve properties of a certificate by the
certificate identifier. All methods require the cert_identifier as first
argument.

=cut

=head2 How to use

You need to load the plugin into your template before using it. As we do not
export the methods, you need to address them with the plugin name, e.g.

    [% USE Certificate %]

    Your certificate with the serial [% Certificate.serial(cert_identifier) %] was issued
    by [% Certificate.body(cert_identifier, 'issuer') %]

Will result in

    Your certificate with the serial 439228933522281479442943 was issued
    by CN=CA ONE,OU=Test CA,DC=OpenXPKI,DC=ORG


=cut

use strict;
use warnings;
use utf8;

use base qw( Template::Plugin );
use Template::Plugin;

use Data::Dumper;

use DateTime;
use OpenXPKI::DateTime;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );


sub new {
    my $class = shift;
    my $context = shift;

    return bless {
    _CONTEXT => $context,
    }, $class;
}


=head2 get_hash(cert_identifier)

Return the certificates database hash or undef if the identifier is
not found.

=cut

sub get_hash {

    my $self = shift;
    my $cert_id = shift;

    return unless ($cert_id);

    # To prevent loading the same item again and again, we always cache
    # the last hash and reuse it

    if ($self->{_hash} && ($self->{_hash}->{identifier} eq $cert_id)) {
        return $self->{_hash};
    }

    $self->{_hash} = undef;
    eval {
        $self->{_hash} = CTX('api2')->get_cert( identifier => $cert_id );
    };
    return $self->{_hash};

}

=head2 get_hash_legacy(cert_identifier)

Return the certificates database hash or undef if the identifier is
not found.

=cut

sub get_hash_legacy {

    my $self = shift;
    my $cert_id = shift;

    return unless ($cert_id);

    # To prevent loading the same item again and again, we always cache
    # the last hash and reuse it

    if ($self->{_hash_old} && ($self->{_hash_old}->{IDENTIFIER} eq $cert_id)) {
        return $self->{_hash_old};
    }

    $self->{_hash_old} = undef;
    eval {
        $self->{_hash_old} = CTX('api')->get_cert({ IDENTIFIER => $cert_id });
    };
    return $self->{_hash_old};

}

=head2 body(cert_identifier, property)

Return a selected property from the certificate body. All fields returned by
the get_cert API method are allowed, the property name is always uppercased.
Note that some properties might return a hash or an array ref!
If the key (or the certificate) is not found, undef is returned.

=cut
sub body {

    my $self = shift;
    my $cert_id = shift;
    my $property = shift;


    # items that can be constructed from the new format
    my $hash = $self->get_hash( $cert_id );
    return unless($hash);

    if (defined $hash->{lc($property)}) {
        return $hash->{lc($property)};
    }

    Log::Log4perl->get_logger('openxpki.deprecated')->error("Template Plugin Certificate.body reading legacy property ($property)!");

    my $hash = $self->get_hash_legacy( $cert_id );
    return $hash ? $hash->{BODY}->{uc($property)} : undef;

}

=head2 csr_serial

Returns the csr_serial.

=cut
sub csr_serial {
    my $self = shift;
    my $cert_id = shift;

    my $hash = $self->get_hash( $cert_id );
    return $hash ? $hash->{csr_serial} : '';
}

=head2 serial

Returns the certificate serial number in decimal notation.
This is a shortcut for body(cert_id, 'serial');

=cut
sub serial {
    my $self = shift;
    my $cert_id = shift;

    my $hash = $self->get_hash( $cert_id );
    return $hash ? $hash->{serial} : '';
}


=head2 serial_hex

Returns the certificate serial number in decimal notation.
This is a shortcut for body(cert_id, 'serial_hex');

=cut
sub serial_hex {
    my $self = shift;
    my $cert_id = shift;

    my $hash = $self->get_hash( $cert_id );
    return $hash ? $hash->{serial_hex} : '';
}

=head2 status

Returns the certificate status.

=cut
sub status {
    my $self = shift;
    my $cert_id = shift;

    my $hash = $self->get_hash( $cert_id );
    return $hash ? $hash->{status} : '';
}

=head2 issuer

Returns the identifier of the issuer certifcate.

=cut
sub issuer {
    my $self = shift;
    my $cert_id = shift;

    my $hash = $self->get_hash( $cert_id );
    return $hash ? $hash->{issuer_identifier} : '';
}


=head2 dn

Returns the DN of the certificate as parsed hash, if second parameter
is given returns the named part as string. Note: In case the named
property has more than one item, only the first one is returned!

=cut

sub dn {
    my $self = shift;
    my $cert_id = shift;
    my $component = shift;

    my $hash = $self->get_hash( $cert_id );
    if (!$hash) {
        return;
    }

    my $dn = $hash->{subject_hash};

    if (!$component) {
        return $dn;
    }

    if (!$dn->{$component}) {
        return;
    }

    return $dn->{$component}->[0];

}


=head2 notbefore(cert_identifier, format)

Return the notbefore date in given format. Format can be any string accepted
by OpenXPKI::DateTime, default is UTC format (iso8601).

=cut
sub notbefore {

    my $self = shift;
    my $cert_id = shift;
    my $format = shift || 'iso8601';

    my $hash = $self->get_hash( $cert_id );

    return '' unless ($hash);

    return OpenXPKI::DateTime::convert_date({
        DATE      => DateTime->from_epoch( epoch => $hash->{notbefore} ),
        OUTFORMAT => $format
    });

}

=head2 notafter(cert_identifier, format)

Return the notafter date in given format. Format can be any string accepted
by OpenXPKI::DateTime, default is UTC format (iso8601).

=cut

sub notafter {

    my $self = shift;
    my $cert_id = shift;
    my $format = shift || 'iso8601';

    my $hash = $self->get_hash( $cert_id );

    return '' unless ($hash);

    return OpenXPKI::DateTime::convert_date({
        DATE      => DateTime->from_epoch( epoch => $hash->{notafter} ),
        OUTFORMAT => $format
    });

}

=head2 pki_realm

Return the verbose label of the workflow realm

=cut

sub realm {

    my $self = shift;
    my $cert_id = shift;

    my $hash = $self->get_hash( $cert_id );
    return '' unless ($hash);

    return CTX('config')->get(['system','realms',$hash->{'pki_realm'},'label']);

}

=head2 chain(cert_identifier)

Return the chain of the certificate as array.
The first element is the certificate issuer, the root ca is the last.

=cut

sub chain {

    my $self = shift;
    my $cert_id = shift;

    my $chain = CTX('api2')->get_chain( start_with => $cert_id, format => 'PEM' );
    my @certs = @{$chain->{certificates}};

    # strip the end entity
    shift @certs;

    return \@certs;

}

=head2 attr(cert_identifier, attribute_name)

Return the value(s) of the requested attribute.
Note that the return value is always an array ref.

=cut

sub attr {

    my $self = shift;
    my $cert_id = shift;
    my $attr = shift;

    my $hash = CTX('api2')->get_cert_attributes(
        identifier => $cert_id, attribute => $attr
    );

    if ($hash->{$attr}) {
        return $hash->{$attr};
    }
    return [];

}

=head2 pem(cert_identifier)

Return the PEM encoded certificate

=cut

sub pem {

    my $self = shift;
    my $cert_id = shift;

    my $pem;
    eval {
        $pem = CTX('api2')->get_cert( identifier => $cert_id, 'format' => 'PEM' );
    };
    return $pem;

}

=head2 profile(cert_identifier)

Return the internal name of the profile

=cut

sub profile {

    my $self = shift;
    my $cert_id = shift;

    my $profile = CTX('api2')->get_profile_for_cert( identifier => $cert_id );
    return $profile || '';

}

1;

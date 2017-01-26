package OpenXPKI::Server::Database::Legacy;
use strict;
use warnings;
use utf8;

use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

=head1 Name

OpenXPKI::Server::Database::Legacy - Compatibility functions for the old database layer

=cut

my $certificate_map = {
    authority_key_identifier  => 'AUTHORITY_KEY_IDENTIFIER',
    cert_key                  => 'CERTIFICATE_SERIAL',
    data                      => 'DATA',
    identifier                => 'IDENTIFIER',
    issuer_dn                 => 'ISSUER_DN',
    issuer_identifier         => 'ISSUER_IDENTIFIER',
    loa                       => 'LOA',
    notafter                  => 'NOTAFTER',
    notbefore                 => 'NOTBEFORE',
    pki_realm                 => 'PKI_REALM',
    public_key                => 'PUBKEY',
    req_key                   => 'CSR_SERIAL',
    status                    => 'STATUS',
    subject                   => 'SUBJECT',
    subject_key_identifier    => 'SUBJECT_KEY_IDENTIFIER',
};

# Convert database result hash
# * $db_hash: HashRef to convert
# * $new_to_old: Conversion direction, 0 = to legacy, 1 = from legacy
# * $attr_map: HashRef which maps new attribute names to legacy names
sub _convert {
    my ($self, $data, $new_to_old, $attr_map) = @_;


    # to legacy
    if ($new_to_old) {
        return {
            map {
                my $key = $attr_map->{$_} or OpenXPKI::Exception->throw(
                    message => 'Unknown field name while trying to convert to legacy database attributes',
                    params  => { fieldname => $_ },
                    log => { logger => CTX('log'), priority => 'fatal', facility => [ 'system', ] },
                );
                ( $key => $data->{$_} )
            }
            keys %$data
        };
    }
    # from legacy
    else {
        my $from_legacy = { map { ($attr_map->{$_} => $_ ) } keys %$attr_map };
        return {
            map {
                my $key = $from_legacy->{$_} or OpenXPKI::Exception->throw(
                    message => 'Unknown field name while trying to convert from legacy database attributes',
                    params  => { legacy_fieldname => $_ },
                    log => { logger => CTX('log'), priority => 'fatal', facility => [ 'system', ] },
                );
                ( $key => $data->{$_} )
            }
            keys %$data
        };
    }
}

=head2 certificate_to_legacy

Converts the keys of the given data hash from SQL attribute names to legacy
attribute names.

Parameters:

=over

=item * B<$db_hash> database hash whose keys are to be converted

=back

=cut
sub certificate_to_legacy {
    my ($self, $db_hash) = @_;
    return $self->_convert($db_hash, 1, $certificate_map);
}

=head2 certificate_from_legacy

Converts the keys of the given data hash from legacy attributes names to SQL
attributes.

Parameters:

=over

=item * B<$db_hash> database hash whose keys are to be converted

=back

=cut
sub certificate_from_legacy {
    my ($self, $db_hash) = @_;
    return $self->_convert($db_hash, 0, $certificate_map);
}

1;


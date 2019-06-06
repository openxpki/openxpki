package OpenXPKI::Server::API2::Plugin::Cert::get_chain;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_chain

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Crypt::X509;

=head1 COMMANDS

=head2 get_chain

Returns the certificate chain starting at a specified certificate.
Expects a hash ref with the named parameter start_with (the
identifier from which to compute the chain) and optionally a parameter
format, which can be either 'PEM', 'DER' or 'DBINFO' (full db result).
Returns a hash ref with the following entries:

    identifiers   the chain of certificate identifiers as an array
    subject       list of subjects for the returned certificates
    certificates  the certificates as an array of data in outformat
                  (if requested)
    complete      1 if the complete chain was found in the database
                  0 otherwise

    revoked       1 if a certificate in the chain is revoked

By setting "bundle => 1" you will not get a hash but a PKCS7 encoded bundle
holding the requested certificate and all intermediates (if found). If the
certificate is not found, the result is empty. Add "keeproot => 1" to also
have the root in PKCS7 container.

B<Parameters>

=over

=item * C<start_with> - certificate identifier to get the chain for

=item * C<format> - one of PEM, DER, DBINFO

=item * C<bundle> - I<Bool>

=item * C<keeproot> - I<Bool>

=back

B<Changes compared to API v1:>

Parameter C<START_IDENTIFIER> was renamed to C<start_with>.

Parameter C<OUTFORMAT> was renamed to C<format>.

C<format> option I<HASH> was renamed to I<DBINFO> to be consistent with
L<get_cert|OpenXPKI::Server::API2::Plugin::Cert::get_cert>.

When called with C<format =E<gt> "DBINFO"> the returned I<HashRef> contains
lowercase keys. Additionally the following keys changed:

    CERTIFICATE_SERIAL      --> cert_key
    CERTIFICATE_SERIAL_HEX  --> cert_key_hex
    PUBKEY                  --> removed in v2.5
    CSR_SERIAL              --> req_key

=cut
command "get_chain" => {
    start_with => { isa => 'Base64', required => 1, },
    format     => { isa => 'Str', matching => qr{ \A ( PEM | DER | TXT | PKCS7 | DBINFO ) \Z }x, },
    bundle     => { isa => 'Bool', default=> 0, },
    keeproot   => { isa => 'Bool', default=> 0, },
} => sub {
    my ($self, $params) = @_;

    my $dbi = CTX('dbi');

    my $default_token;

    my $cert_list = [];
    my $id_list = [];
    my $subject_list = [];
    my $complete = 0;
    my $has_revoked = 0;
    my %already_seen; # hash of identifiers that have already been seen

    my $start = $params->start_with;
    my $current_identifier = $start;

    my $temp_format = $params->bundle ? 'PEM' : $params->format;

    while (1) {
        ##! 128: '@identifiers: ' . Dumper(\@identifiers)
        ##! 128: '@certs: ' . Dumper(\@certs)
        push @$id_list, $current_identifier;
        my $cert = $dbi->select_one(
            from => 'certificate',
            columns => [ '*' ],
            where => {
                identifier => $current_identifier,
            },
        );
        # stop if certificate was not found
        last unless $cert;

        push @$subject_list, $cert->{subject};

        if ($cert->{status} ne 'ISSUED') {
            $has_revoked = 1;
        }

        if ($temp_format) {
            if ('PEM' eq $temp_format) {
                push @$cert_list, $cert->{data};
            }
            elsif ('DER' eq $temp_format) {
                push @$cert_list, OpenXPKI::Crypt::X509->new( $cert->{data} )->data;
            }
            elsif ('DBINFO' eq $temp_format) {
                # remove data to save some bytes
                delete $cert->{data};
                push @$cert_list, $cert;
            }
        }
        if ($cert->{issuer_identifier} eq $current_identifier) {
            # self-signed, this is the end of the chain
            $complete = 1;
            last;
        }
        else { # go to parent
            $current_identifier = $cert->{issuer_identifier};
            ##! 64: 'issuer: ' . $current_identifier
            last if $already_seen{$current_identifier}; # we've run into a loop!
            $already_seen{$current_identifier} = 1;
        }
    }

    # Return a pkcs7 structure instead of the hash
    if ($params->bundle) {

        if (!scalar @$cert_list) {
            return '';
        }

        # we do NOT include the root in p7 bundles
        pop @$cert_list if ($complete and !$params->keeproot);

        $default_token = CTX('api')->get_default_token unless($default_token);
        my $result = $default_token->command({
            COMMAND          => 'convert_cert',
            DATA             => $cert_list,
            OUT              => (($params->has_format and $params->format eq 'DER') ? 'DER' : 'PEM'),
            CONTAINER_FORMAT => 'PKCS7',
        });
        return $result;
    }

    return {
        subject     => $subject_list,
        identifiers => $id_list,
        complete    => $complete,
        revoked     => $has_revoked,
        $params->format ? (certificates => $cert_list) : (),
    };
};

__PACKAGE__->meta->make_immutable;

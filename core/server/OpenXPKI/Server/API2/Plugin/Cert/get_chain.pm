package OpenXPKI::Server::API2::Plugin::Cert::get_chain;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_chain

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_chain

Returns the certificate chain starting at a specified certificate.
Expects a hash ref with the named parameter START_IDENTIFIER (the
identifier from which to compute the chain) and optionally a parameter
OUTFORMAT, which can be either 'PEM', 'DER' or 'HASH' (full db result).
Returns a hash ref with the following entries:

    IDENTIFIERS   the chain of certificate identifiers as an array
    SUBJECT       list of subjects for the returned certificates
    CERTIFICATES  the certificates as an array of data in outformat
                  (if requested)
    COMPLETE      1 if the complete chain was found in the database
                  0 otherwise

By setting "BUNDLE => 1" you will not get a hash but a PKCS7 encoded bundle
holding the requested certificate and all intermediates (if found). Add
"KEEPROOT => 1" to also have the root in PKCS7 container.

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

B<Changes compared to API v1:>

C<format> option I<HASH> was renamed to I<DBINFO> to be consistent with
L<get_cert|OpenXPKI::Server::API2::Plugin::Cert::get_cert>.

When called with C<format =E<gt> "DBINFO"> the returned I<HashRef> contains
lowercase keys. Additionally the following keys changed:

    CERTIFICATE_SERIAL      --> cert_key
    CERTIFICATE_SERIAL_HEX  --> cert_key_hex
    PUBKEY                  --> public_key
    CSR_SERIAL              --> req_key

=cut
command "get_chain" => {
    start_identifier => { isa => 'Base64', required => 1, },
    outformat        => { isa => 'Str', matching => qr{ \A ( PEM | DER | TXT | PKCS7 | DBINFO ) \Z }x, },
    bundle           => { isa => 'Bool', default=> 0, },
    keeproot         => { isa => 'Bool', default=> 0, },
} => sub {
    my ($self, $params) = @_;

    my $dbi = CTX('dbi');

    my $default_token;

    my $cert_list = [];
    my $id_list = [];
    my $subject_list = [];
    my $complete = 0;
    my %already_seen; # hash of identifiers that have already been seen

    my $start = $params->start_identifier;
    my $current_identifier = $start;

    my $temp_format = $params->bundle ? 'PEM' : $params->outformat;

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

        if ($temp_format) {
            if ('PEM' eq $temp_format) {
                push @$cert_list, $cert->{data};
            }
            elsif ('DER' eq $temp_format) {
                $default_token = CTX('api')->get_default_token() unless($default_token);
                my $utf8fix = $default_token->command({
                    COMMAND => 'convert_cert',
                    DATA    => $cert->{data},
                    IN      => 'PEM',
                    OUT     => 'DER',
                });
                push @$cert_list, $utf8fix;
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

        # we do NOT include the root in p7 bundles
        pop @$cert_list if ($complete and !$params->keeproot);

        $default_token = CTX('api')->get_default_token unless($default_token);
        my $result = $default_token->command({
            COMMAND          => 'convert_cert',
            DATA             => $cert_list,
            OUT              => (($params->has_outformat and $params->outformat eq 'DER') ? 'DER' : 'PEM'),
            CONTAINER_FORMAT => 'PKCS7',
        });
        return $result;
    }

    return {
        subject     => $subject_list,
        identifiers => $id_list,
        complete    => $complete,
        $params->outformat ? (certificates => $cert_list) : (),
    };
};

__PACKAGE__->meta->make_immutable;

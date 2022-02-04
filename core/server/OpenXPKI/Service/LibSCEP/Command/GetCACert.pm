## OpenXPKI::Service::LibSCEP::Command::GetCACert
##
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
##
package OpenXPKI::Service::LibSCEP::Command::GetCACert;

use English;

use Class::Std;

use base qw( OpenXPKI::Service::LibSCEP::Command );

use MIME::Base64;
use Log::Log4perl;
use OpenXPKI::Debug;

use OpenXPKI::Server::Context qw( CTX );


sub execute {
    my $self    = shift;
    my $arg_ref = shift;
    my $ident   = ident $self;

    ##! 8: "execute GetCACert"

    my $server = CTX('session')->data->server;

    my $ra_token_alias = $self->__get_token_alias();
    my $ca_issuer_alias = CTX('api2')->get_token_alias_by_type( type => 'certsign' );

    # Cache record is identifier by server name, ra-cert and issuer alias
    my $cache_id = join(':',($server, $ra_token_alias, $ca_issuer_alias));

    my $chain;
    eval {
        my $cached_chain = CTX('api2')->get_data_pool_entry(
            namespace => 'scep.cache.getca',
            key => $cache_id,
        );
        if ($cached_chain && $cached_chain->{value}) {
            ##! 16: "Cache id $cache_id found"
            $chain = $cached_chain->{value};
        }
    };

    if ($EVAL_ERROR) {
        CTX('log')->system()->warn('Error reading SCEP chain ($cache_id) from datapool');
    }

    if (!$chain) {
        $chain = $self->__build_chain( $server, $ra_token_alias, $ca_issuer_alias );
        eval{
            CTX('api2')->set_data_pool_entry(
                namespace => 'scep.cache.getca',
                key => $cache_id,
                value => $chain,
                # expire after seven days to get rid of decomissioned chains
                expiration_date => time + 3600 * 24 * 7,
            );
            ##! 16: "Added cache using id $cache_id"
            CTX('log')->system()->info('Added SCEP chain ($cache_id) to datapool');
        };
        if ($EVAL_ERROR) {
            CTX('log')->system()->error('Error adding SCEP chain ($cache_id) to datapool');
        }
    }

    ##! 64: "Sending chain " . $chain
    my $result = "Content-Type: application/x-x509-ca-ra-cert\n\n";
    $result .= decode_base64($chain);

    return $self->command_response($result);
}

sub __build_chain : PRIVATE {

    my $self = shift;
    my $server = shift;
    my $ra_token_alias = shift;
    my $ca_issuer_alias = shift;

    my $ra_chain = 'fullchain';
    my $issuer_chain = 'fullchain';

    # legacy setting
    my $strip_root = CTX('config')->get(['scep', $server, 'response', 'getcacert_strip_root']);
    if (defined $strip_root) {
        CTX('log')->deprecated->info('getcacert_strip_root found in SCEP settings - please upgrade your config');
        if ($strip_root) {
            $ra_chain = 'chain';
            $issuer_chain = 'chain';
        }
    }

    my $resp = CTX('config')->get(['scep', $server, 'response', 'getca', 'ra']);
    if ($resp && $resp =~/(endentity|chain)/) {
         $ra_chain = $resp;
    }

    my $scep_ra_cert = CTX('api2')->get_certificate_for_alias( alias => $ra_token_alias );

    ##! 32: 'SCEP RA Cert: ' . Dumper($scep_ra_cert)
    if (! defined $scep_ra_cert || !$scep_ra_cert->{identifier}) {
        OpenXPKI::Exception->throw(
            message => 'Unable to find SCEP certificate',
            param => { alias => $ra_token_alias }
        );
    }

    my @chain_result;

    if ($ra_chain eq 'endentity') {

        push @chain_result, $scep_ra_cert->{data};

    } else {

        my $scep_chain = CTX('api2')->get_chain(
            'start_with' => $scep_ra_cert->{identifier},
            'format'        => 'PEM',
        );
        ##! 32: 'chain: ' . Dumper($scep_chain)

        push @chain_result, @{ $scep_chain->{certificates} };

        # if the chain has the complete flag, the root is included
        # but we dont want it in the response, so pop it off the list
        # take care about scep server with a out-of-ca self signed cert
        if ($scep_chain->{complete} && $ra_chain ne 'fullchain' && scalar @chain_result > 1 ) {
            ##! 16: 'Strip of scep root'
            pop @chain_result;
        }
    }

    ##! 32: 'chain_result: ' . Dumper \@chain_result;

    # chain_result now has requested chain parts for the SCEP RA Certificate
    # Now we will include the requesed issuer certificates
    $resp = CTX('config')->get(['scep', $server, 'response', 'getca', 'issuer']) || '';
    if ($resp =~/(endentity|chain|fullchain)/) {
        $issuer_chain = $resp;
    }

    my $ca_issuer = CTX('api2')->get_certificate_for_alias( alias => $ca_issuer_alias );

    ##! 16: 'Issuer chain ' . $issuer_chain
    if ($issuer_chain eq 'endentity') {
        if (! grep { $_ eq $ca_issuer->{data} } @chain_result) {
            push @chain_result, $ca_issuer->{data};
        }
    } else {
        my $issuer_chain_cert = CTX('api2')->get_chain(
            'start_with' => $ca_issuer->{identifier},
            'format'  => 'PEM',
        );
        ##! 32: 'chain: ' . Dumper($issuer_chain_cert)
        my @tmp_chain = @{ $issuer_chain_cert->{certificates} };
        if ($issuer_chain_cert->{complete} && $issuer_chain ne 'fullchain') {
            ##! 16: 'Strip of issuer root'
            pop @tmp_chain;
        }
        foreach my $cert (@tmp_chain) {
            if (! grep { $_ eq $cert } @chain_result) {
                push @chain_result, $cert;
            }
        }
    }

    ##! 32: 'chain_result: ' . Dumper \@chain_result

    $result = CTX('api2')->get_default_token()->command({
        COMMAND          => 'convert_cert',
        DATA             => \@chain_result,
        OUT              => 'DER',
        CONTAINER_FORMAT => 'PKCS7',
    });

    return encode_base64($result, '');

}


1;
__END__

=head1 Name

OpenXPKI::Service::LibSCEP::Command::GetCACert

=head1 Description

Returns the certifcate of the RA and CA issuer including its chain.

The chain is cached/read from the datapool, namespace scep.cache.getca, the
key is created by joining servername, scep-alias and issuer-alias with a
colon, e.g. 'vpnservice:ca-scep-5:ca-signer-2'.

In case you want a special response, e.g. including extra chain certificates
you can set the datapool item manually

If no value is found in the datapool, __build_chain is called to create it
and the result is cached using the datapool for seven days.

Return information on the certificates used by the scep server.
With default settings, the following certs are returned in order:

=over 8

=item scep server certificate

entity certificate used by the scep server

=item scep server chain

the full chain including without the root certificate for the scep entity certificate

=item current issuer certificate

the certificate currently used for certificate issuance.

=item issuer chain

the chain of the issuing ca, starting with the first intermediate certificate.

=back

Certificates used in both scep and issuer chain are only included once.

The responses are cached using the datapool, you can strip chain/root by
config settings, see below, or inject arbitrary chains into the datapool.

=head1 Functions

=head2 execute

Returns the CA certificate chain including the HTTP header needed
for the scep CGI script.

=head2 __build_chain

Config layout (at scep.<server>) is:

  response
      getca:
          ra:     fullchain
          issuer: fullchain

Options are I<endentity> (cert only), I<chain> (no root) and I<fullchain>
(includes root certificate).

The old config option response.getcacert_strip_root is still recognized
but deprecated.



# OpenXPKI::Server::Workflow::Activity::Reports::CertExport::GenerateExportFile
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Reports::CertExport::GenerateExportFile;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use OpenXPKI::Serialization::Simple;
use MIME::Base64;
use XML::Simple;
use OpenXPKI::FileUtils;
use File::Temp;

use Data::Dumper;

sub execute {

    ##! 1: 'execute'

    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();

    my $ser = OpenXPKI::Serialization::Simple->new();

    my $key_namespace = $context->param ( 'key_namespace' );

    # Clear the target params (just in case we missed it)
    $context->param( 'exported_cert_ids' , '');
    $context->param( 'xml_filename' ,  '' );
    $context->param( 'xml_targetname' , '' );


    # Step 1 - find exportable certificates
    # We load the list of certificates from the datapool

    my $dp_cert_to_export = CTX('api')->list_data_pool_entries({
        'NAMESPACE' => $context->param ( 'queue_namespace' ) ,
        'LIMIT' => $context->param ( 'max_records' )
    });


    # Nothing to do
    if (! scalar @{$dp_cert_to_export}) {
        CTX('log')->application()->info('Certificate export - nothing to do');

        return 1;
    }

    ##! 16: 'cert to export  ' .  Dumper $dp_cert_to_export

    # Step 2 - load encrpytion certs and prepare token
    my $enc_cert_ids =  $context->param ( 'enc_cert_ids' );
    if ($enc_cert_ids) {
         $enc_cert_ids = $ser->deserialize( $enc_cert_ids ); # Array of identifiers
    }
    ##! 16: 'enc_cert_ids ' . Dumper $enc_cert_ids

    my $token = CTX('api')->get_default_token();
    my @enc_certs;

    if ($enc_cert_ids) {
        foreach my $ident (@{$enc_cert_ids}) {
            my $cert = CTX('api')->get_cert  ({ IDENTIFIER => $ident, FORMAT => 'PEM'});
            push @enc_certs, $cert;
        }
    } else {
        CTX('log')->application()->info('No encryption targets given, wont search for private keys');

    }

    my @xmlout;
    my @exported;

    # Step 3 - iterate over export list
    foreach my $cert (@{$dp_cert_to_export}) {

        my $cert_identifier = $cert->{KEY};

        ##! 16: ' Exporting cert ' . $cert_identifier

        # Step 3a - fetch PEM
        my $cert_pem = CTX('api')->get_cert  ({ IDENTIFIER => $cert_identifier, FORMAT => 'PEM'});

        my $cert_xml = { id => $cert_identifier };
        # Attributes for the certificate tag are taken from the datapool
        my $attributes = CTX('api')->get_data_pool_entry( $cert );
        if ($attributes && $attributes->{VALUE}) {
            $attributes = $ser->deserialize( $attributes->{VALUE} );
            if (ref $attributes eq "HASH") {
                 $cert_xml = $attributes;
            }
            # Someting like { certType => "sig",  EmployeeID => "sb2130", email => "user\@company.com" };
        }

        ##! 32: 'Basic attributes  ' . Dumper $cert_xml

        # if no export targets are avail we do not export the p12
        if (@enc_certs) {
            # Step 3b - look for key
            my $msg = CTX('api')->get_data_pool_entry({
                NAMESPACE => $key_namespace,
                KEY       => $cert_identifier
            });

            # Block for escrow certs
            if ($msg && $msg->{VALUE}) {
                ##! 8: 'Escrow key found'

                # Step 3c - create p12 using random challenge
                my $p12_key = $token->command({
                    COMMAND       => 'create_random',
                    RANDOM_LENGTH => 32,
                });

                my $escrow_key = $msg->{VALUE};
                my $p12 = $token->command({
                    COMMAND => 'create_pkcs12',
                    PASSWD  => 'OpenXPKI',
                    KEY     => $escrow_key,
                    CERT    => $cert_pem,
                    PKCS12_PASSWD => $p12_key
                });

                ##! 32: 'Created P12 ' . encode_base64( $p12 )

                # Step 3d - encrypt random challenge with target certificates
                ##! 16: 'Encrypting challenge using cert ' . $enc_certs[0]
                my $p7_secrets = $token->command({
                        COMMAND => 'pkcs7_encrypt',
                        CONTENT => $p12_key,
                        CERT    => \@enc_certs,
                        OUTFORM => 'DER'
                });

                ##! 32: 'Created P7 Keyfile ' . encode_base64( $p7_secrets )
                $cert_xml->{'pkcs12-container'} = { "enc-password" => encode_base64( $p7_secrets, ''), content => encode_base64( $p12, '') };

                CTX('log')->application()->info("added private key to export for $cert_identifier");
                CTX('log')->audit('key')->info("private key export", {
                    certid => $cert_identifier
                });
            }
        }

        # Strip envelope and line feeds from PEM encoding
        $cert_pem =~ s/\r\n//g;
        $cert_pem =~ s/-----\w+ CERTIFICATE-----//g;

        $cert_xml->{'x509-certificate'} = { format => "PEM", content => $cert_pem };
        push @xmlout, $cert_xml;
        push @exported, $cert_identifier;
    }

    my $fh = File::Temp->new( UNLINK => 0, DIR => $context->param( 'tmpfile_tmpdir' ) );
    my $xs = XML::Simple->new(RootName => 'certificates', ContentKey => '-content', OutputFile => $fh);
    my $xml = $xs->XMLout( { certificate  => \@xmlout } );

    # Change mode of the file if requested
    my $umask = $context->param( 'tmpfile_umask' );
    if ($umask) {
        ##! 32: 'Change umask ' . $umask
        chmod oct($umask), $fh->filename ;
    }

    # Put list of exported id in context to tag them later
    $context->param( 'exported_cert_ids' , $ser->serialize( \@exported ) );

    # Name of the xml file
    $context->param( 'xml_filename' ,  $fh->filename );

    # Target name - according to user spec
    my $date = DateTime->now( time_zone => 'UTC' );
       $context->param( 'xml_targetname' ,  $date->strftime("export_%Y%m%d_%H%M%S.xml") );


    CTX('log')->application()->info('Certificate export file has been generated: ' . $fh->filename);


    return 1;

}

1;

=head1 Name

OpenXPKI::Server::Workflow::Activity::Reports::CertExport::GenerateExportFile

=head1 Description

Use the config from the context to load the next batch of certs to be exported.
All certificates are written to one large XML file for transfer, for certificates
having an escrow key, a PKCS12 container with key and cert is created and protected
with a random passphrase. The passphrase is exported as PKCS7 container, encrypted
with the given target identifiers.

=head1 Configuration

The activity pulls its configuration from the workflow context:

=over

=item * max_records

max. number of certificates to put into one file

=item * key_namespace

The namespace in the datapool to search for a matching escrowed key

=item * queue_namespace

The namespace in the datapool to get the identifiers to be exported

=item * enc_cert_ids

Array of certificate identifiers to enrypt the p12 passwords to

=back

=head1 Return values

The following parameters are written to the context

=over

=item * exported_cert_ids

Array of certificate identifiers contained in the xml

=item * xml_filename

Name of the xml file on the local system (tempfile)

=item * xml_targetname

Expected name of the file on the target system after transfer

=back


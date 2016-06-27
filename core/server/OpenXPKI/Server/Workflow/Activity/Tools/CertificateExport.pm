package OpenXPKI::Server::Workflow::Activity::Tools::CertificateExport;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Template;
use OpenXPKI::Debug;
use Data::Dumper;
use File::Temp;

sub execute {
    
    ##! 1: 'start'
    
    my $self = shift;
    my $workflow = shift;
  
    my $context = $workflow->context();
    
    my $cert_identifier = $self->param('cert_identifier');
    my $key_format = $self->param('key_format') || 'OPENSSL_PRIVKEY';
    my $key_password = $self->param('key_password');
    my $alias = $self->param('alias') || '';
    my $template = $self->param('template');
    
    my $chain = CTX('api')->get_chain({ START_IDENTIFIER => $cert_identifier, OUTFORMAT => 'PEM'});
    my @certs = @{$chain->{CERTIFICATES}};
        
    my $key;    
    if ($key_password) {
        my $privkey;
        eval {
            $privkey = CTX('api')->get_private_key_for_cert({ 
                IDENTIFIER =>  $cert_identifier, 
                FORMAT => $key_format, 
                PASSWORD => $key_password,
                ALIAS => $alias, 
            });
        };
        if (!$privkey) {
            CTX('log')->log(
                MESSAGE => "Export of private key failed for $cert_identifier",
                PRIORITY => 'error',
                FACILITY => [ 'application', 'audit' ],
            );          
            OpenXPKI::Exception->throw( 
                message => 'I18N_OPENXPKI_UI_EXPORT_CERTIFICATE_FAILED_TO_LOAD_PRIVATE_KEY'
            );
        }
        $key = $privkey->{PRIVATE_KEY};
        CTX('log')->log(
            MESSAGE => "Export of private key to context for $cert_identifier",
            PRIORITY => 'info',
            FACILITY => [ 'application', 'audit' ],
        );          
    }
    
    ##! 64: 'chain ' . Dumper $chain
    ##! 64: 'key' . $key
            
    my $tt = OpenXPKI::Template->new();
    
    my $ca = pop @certs if ($chain->{COMPLETE});
    
    my $ttargs = {
        subject => ($chain->{SUBJECT}->[0]),
        certificate => shift @certs, 
        ca => $ca, 
        chain => \@certs, 
        key =>  $key,
    };
    ##! 32: 'values ' . Dumper $ttargs          
    
    # shift/pop of the entity and ca from the ends of the list
    my $config = $tt->render( $template, $ttargs );
         
         
    my $target_key = $self->param('target_key') || 'certificate_export';    
         
    $context->param( $target_key , $config);  
               
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CertificateExport

=head1 Description

Create a text export for a certificate using a template. The export file
can contain the chain and private key.

=head1 Configuration

=head2 Activity parameters

=over 

=item cert_identifier

The cert to be exported.

=item template

A template toolkit string to be used to render the output. The parser is 
called with five parameters. Certificates are PEM encoded, keys might be
in binary format, depending on the key_format parameter! 

=over

=item certificate

The PEM encoded certificate.

=item subject

The subject of the certificate

=item ca

The PEM encoded ca certificate, might be empty if the chain can not
be completed.

=item key

The private key, requires the key_password to be set to the correct 
value. Obviously, keys are only available if created or imported. 

=item chain

An ARRAY of PEM encoded intermediates, might be empty.
    
=back

=item key_password

The password which was used to persist the key, also used for encrypting
the exported key.

=item key_format, optional

 @see OpenXPKI::Server::API::Object::get_private_key_for_cert

=item alias, optional

For PKCS12 sets the so called "friendly name" for the certificate.
For Java Keystore sets the keystore alias.
Parameter is ignored for any other key types.

=item target_key, optional

The context key to write the result to, default is I<certificate_export>.
Note: If you export a key and use a persisted workflow, this will leave the
(password protected) key readable in the context forever.  

=back
 

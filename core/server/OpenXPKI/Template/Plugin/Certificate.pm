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
    
    my $hash = CTX('api')->get_cert({ IDENTIFIER => $cert_id });    
    return $hash ? $hash->{BODY}->{uc($property)} : undef;

}

=head2 csr_serial

Returns the csr_serial.

=cut
sub csr_serial {    
    my $self = shift;
    my $cert_id = shift; 
        
    my $hash = CTX('api')->get_cert({ IDENTIFIER => $cert_id });    
    return $hash ? $hash->{CSR_SERIAL} : '';
}

=head2 serial

Returns the certificate serial number in decimal notation.
This is a shortcut for body(cert_id, 'serial');

=cut
sub serial {    
    my $self = shift;
    my $cert_id = shift; 
        
    my $hash = CTX('api')->get_cert({ IDENTIFIER => $cert_id });    
    return $hash ? $hash->{BODY}->{SERIAL} : '';
}


=head2 serial_hex

Returns the certificate serial number in decimal notation.
This is a shortcut for body(cert_id, 'serial_hex');

=cut
sub serial_hex {    
    my $self = shift;
    my $cert_id = shift; 
        
    my $hash = CTX('api')->get_cert({ IDENTIFIER => $cert_id });    
    return $hash ? $hash->{BODY}->{SERIAL_HEX} : '';
}

=head2 status

Returns the certificate status.

=cut
sub status {    
    my $self = shift;
    my $cert_id = shift; 
        
    my $hash = CTX('api')->get_cert({ IDENTIFIER => $cert_id });    
    return $hash ? $hash->{STATUS} : '';
}

=head2 issuer

Returns the identifier of the issuer certifcate.

=cut
sub issuer {    
    my $self = shift;
    my $cert_id = shift; 
        
    my $hash = CTX('api')->get_cert({ IDENTIFIER => $cert_id });    
    return $hash ? $hash->{ISSUER_IDENTIFIER} : '';
}


=head2 notbefore(cert_identifier)

Return the notbefore date in UTC format. 
 
=cut
sub notbefore {
    
    my $self = shift;
    my $cert_id = shift;
    
    my $hash = CTX('api')->get_cert({ IDENTIFIER => $cert_id });
    
    return OpenXPKI::DateTime::convert_date({
        DATE      => DateTime->from_epoch( epoch => $hash->{BODY}->{NOTBEFORE} ),
        OUTFORMAT => 'iso8601'
    });    

}

=head2 notafter(cert_identifier)

Return the notafter date in UTC format. 
 
=cut
sub notafter {
    
    my $self = shift;
    my $cert_id = shift;
    
    my $hash = CTX('api')->get_cert({ IDENTIFIER => $cert_id });
    
    return OpenXPKI::DateTime::convert_date({
        DATE      => DateTime->from_epoch( epoch => $hash->{BODY}->{NOTAFTER} ),
        OUTFORMAT => 'iso8601'
    });    

}

1;
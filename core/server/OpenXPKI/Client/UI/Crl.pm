# OpenXPKI::Client::UI::Crl
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Crl;

use Moose; 
use Data::Dumper;
use OpenXPKI::i18n qw( i18nGettext );

extends 'OpenXPKI::Client::UI::Result';

sub init_detail {

    
    my $self = shift;
    my $args = shift;
    
    my $crl_serial = $self->param('serial');
        
    my $crl_hash = $self->send_command( 'get_crl', {  SERIAL => $crl_serial, FORMAT => 'HASH' });    
    $self->logger()->debug("result: " . Dumper $crl_hash);
    
    $self->_page({
        label => 'Certificate Revocation List #' . $crl_hash->{SERIAL},   
        shortlabel => 'CRL #' . $crl_hash->{BODY}->{SERIAL},     
    });
            
    my @fields = (
        { label => 'Serial', value => $crl_hash->{BODY}->{'SERIAL'} },
        { label => 'Issuer',  value => $crl_hash->{BODY}->{'ISSUER'} } ,
        { label => 'created', value => $crl_hash->{BODY}->{'LAST_UPDATE'}, format => 'timestamp'  },
        { label => 'expires', value => $crl_hash->{BODY}->{'NEXT_UPDATE'},format => 'timestamp' },        
    );
 
    $self->_result()->{main} = [{
        type => 'keyvalue',
        content => {
            label => '',
            description => '',
            data => \@fields,
#            buttons => \@buttons,
        }},           
    ]; 
    
}


sub init_download {

    my $self = shift;
    my $args = shift;
    
    my $cert_identifier = $self->param('identifier');    
    my $format = $self->param('format');
    my $crl_serial = $self->param('serial');
    
     # No format, draw a list 
    if ($format) {
                
        my $data = $self->send_command( 'get_crl', {  SERIAL => $crl_serial, FORMAT => uc($format) });    
                
        my $content_type = 'application/pkcs7-crl';
        
        my $filename = 'crl.'.$format;
    
        print $self->cgi()->header( -type => $content_type, -expires => "1m", -attachment => $filename );
        print $data; 
        exit;
    }
        
    my $pattern = "<li><a href=\"/cgi-bin/connect.cgi?page=crl!download!serial!$crl_serial!format!%s\">%s</a></li>";
    
    $self->add_section({
        type => 'text',
        content => {
            label => '',
            description => '<ul>'.
            sprintf ($pattern, 'pem', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_PEM')).
            sprintf ($pattern, 'txt', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_TXT')).
            sprintf ($pattern, 'der', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_DER')).
            '</ul>',                
    }});           

    return $self;
        
}


1;
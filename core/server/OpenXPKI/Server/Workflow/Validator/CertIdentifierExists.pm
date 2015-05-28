package OpenXPKI::Server::Workflow::Validator::CertIdentifierExists;

use strict;
use warnings;
use Moose;
use Workflow::Exception qw( validation_error );
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Server::Context qw( CTX );

extends 'OpenXPKI::Server::Workflow::Validator';

sub _validate {
    my ( $self, $wf, $cert_identifier ) = @_;

    ##! 1: 'start'
    ##! 16: 'check identifier' . $cert_identifier
    CTX('dbi_backend')->commit();
    my $hash = CTX('dbi_backend')->first(
        TABLE   => 'CERTIFICATE',
        DYNAMIC => { IDENTIFIER => { VALUE => $cert_identifier }, },
    );

    if (!$hash) {    
        ##! 16: 'unknown identifier ' . $cert_identifier
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_CERT_IDENTIFIER_EXISTS_NO_SUCH_ID");    
    }
    
    my $pki_realm = $self->param('pki_realm') || CTX('session')->get_pki_realm();
    
    if (($hash->{'PKI_REALM'} ne $pki_realm) && ($pki_realm ne '_any')) {
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_CERT_IDENTIFIER_EXISTS_NOT_IN_REALM");        
    }
    
    if ($self->param('entity_only') && !$hash->{CSR_SERIAL}) {
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_CERT_IDENTIFIER_EXISTS_NOT_AN_ENTITY");
    }
    
    CTX('log')->log(
        MESSAGE  => "Found certificate, hash is " . Dumper $hash,
        PRIORITY => 'debug',
        FACILITY => 'application',
    );
    
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::CertIdentifierExists

=head1 SYNOPSIS

    class: OpenXPKI::Server::Workflow::Validator::CertIdentifierExists
    param: 
        entity_only: 1
        pki_realm: _any
    arg: 
      - $cert_identifier
      
=head1 DESCRIPTION

This validator checks whether a given certificate identifier exists. Based
on the parameters it can check weather the certificate is in a given realm
and if it is an entity certificate. Both parameters are optional. Note that
there is no check on the validity of the certificate.

=head2 Argument

=over 

=item $cert_identifier

The certificate identifier

=back 
 
=head2 Parameter

=over 

=item pki_realm

Can be the name of a realm or the special word I<_any>. If not given, default
ist to check in the session realm only!

=item entity_only

If set, the certificate must be an entity certificate. 

=back
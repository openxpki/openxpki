## OpenXPKI::Service::SCEP::Command::GetNextCACert
##
package OpenXPKI::Service::SCEP::Command::GetNextCACert;

use English;

use Class::Std;

use base qw( OpenXPKI::Service::SCEP::Command );

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Context qw( CTX );

use Data::Dumper;

sub execute {
    my $self    = shift;
    my $arg_ref = shift;
    my $ident   = ident $self;
    
    ##! 1: "start"
    
    my $pki_realm = CTX('session')->get_pki_realm();

    # The list of all issuing ca certs in this realm
    my $all_ca = CTX('api')->get_ca_list();
    
    ##! 32: 'Found ca list ' . Dumper $all_ca  
    # Newest are on top, check if the status is upcoming
    my $next_ca;    
    foreach my $cert (@{$all_ca}) {        
    	##! 32: 'Next item ' . Dumper $cert
        if ($cert->{STATUS} eq 'I18N_OPENXPKI_TOKEN_STATUS_UPCOMING') {
           ##! 8: 'Upcoming issuer found ' . Dumper $cert
           $next_ca = $cert;    
        }
        # There might be more than one upcoming, so we continue to loop
    }

    if (!$next_ca) {    
        return;
    }
 
    # try to load the chain     
    my $chain = CTX('api')->get_chain({
        'START_IDENTIFIER' => $next_ca->{IDENTIFIER},
        'OUTFORMAT'        => 'PEM',
    });
    ##! 32: 'chain: ' . Dumper($chain)
     
    ##! 16: 'ca_chains: ' . Dumper $chain->{CERTIFICATES};
     
    # $chain->{CERTIFICATES} is an arrayref of PEM blocks - we just merge it
    #my $nextca_chain = join "\n", @{$chain->{CERTIFICATES}};     
    
    ## FIXME - needs discussion, SCEP draft allows inclusion of RA which seems to be unsupported
    # by openca-scep and is somewhat useless anyway. So we send only the root for now.
    my $nextca_chain = pop @{$chain->{CERTIFICATES}};      

    # We need to create a signed reply, load scep token
    my $scep_token_alias = CTX('api')->get_token_alias_by_type( { TYPE => 'scep' } );
    my $scep_token = CTX('crypto_layer')->get_token( { TYPE => 'scep', NAME => $scep_token_alias } );
   
   ##! 32: 'nextca chain ' . $nextca_chain 
   
    my $result = $scep_token->command({   
    	COMMAND => 'create_nextca_reply',
        CHAIN   => $nextca_chain,        
    });

    $result = "Content-Type: application/x-x509-next-ca-cert\n\n" . $result;

    ##! 16: "result: $result"
    return $self->command_response($result);
}
 
1;
__END__

=head1 Name

OpenXPKI::Service::SCEP::Command::GetNextCACert

=head1 Description
 
Return the certificate of an upcoming but still inactive issuing CA.
If the chain is known, it is also included.

=head1 Functions

=head2 execute

Run the activity

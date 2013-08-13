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

    my $next_ca = CTX('dbi_backend')->first(
        TABLE   => [ 'CERTIFICATE', 'ALIASES' ],
        COLUMNS => [             
            'ALIASES.NOTBEFORE',            
            'ALIASES.NOTAFTER',
            'CERTIFICATE.DATA',
            'CERTIFICATE.SUBJECT',
            'ALIASES.ALIAS',              
            'ALIASES.IDENTIFIER',
        ],
        JOIN => [
            [ 'IDENTIFIER', 'IDENTIFIER' ],
        ],
        DYNAMIC => {
            'ALIASES.PKI_REALM' => { VALUE => $pki_realm },
            'ALIASES.GROUP_ID' => { VALUE => 'root' },
            'ALIASES.NOTBEFORE' => { VALUE => time(), OPERATOR => 'GREATER_THAN' },                                           
        },
        'ORDER' => [ 'ALIASES.NOTBEFORE' ],
        'REVERSE' => 1,
    );

    if (!$next_ca) {            
        ##! 16: 'No cert found'
        CTX('log')->log(
            MESSAGE => "SCEP GetNextCACert nothing found (realm $pki_realm).",
            PRIORITY => 'debug',
            FACILITY => 'system',
        );        
        return;
    }
     
    # We need to create a signed reply, load scep token
    my $scep_token_alias = CTX('api')->get_token_alias_by_type( { TYPE => 'scep' } );
    my $scep_token = CTX('crypto_layer')->get_token( { TYPE => 'scep', NAME => $scep_token_alias } );
   
    ##! 16: 'Found nextca cert ' .  $next_ca->{'ALIASES.ALIAS'}
    ##! 32: 'nextca  ' . Dumper $next_ca      
   
    my $result = $scep_token->command({   
    	COMMAND => 'create_nextca_reply',
        CHAIN   => $next_ca->{'CERTIFICATE.DATA'},        
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
 
Return the certificate of an upcoming but still inactive root certificate.
To be returned the root certificate must be in the alias table, group root
with a notbefore date in the future.

=head1 Functions

=head2 execute

Run the activity

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
    );

    if (!$next_ca) {
        ##! 16: 'No cert found'
        CTX('log')->log(
            MESSAGE => "SCEP GetNextCACert nothing found (realm $pki_realm).",
            PRIORITY => 'debug',
            FACILITY => 'application',
        );

        # Send a 404 header with a verbose explanation
        return $self->command_response(
            "Status: 404 NextCA not set\n".
            "Content-Type: text/plain\n\n".
            "NextCA not set");

    }

    my $scep_token =  $self->__get_token();

    ##! 16: 'Found nextca cert ' .  $next_ca->{'ALIASES.ALIAS'}
    ##! 32: 'nextca  ' . Dumper $next_ca

    my $result = $scep_token->command({
        COMMAND => 'create_nextca_reply',
        CHAIN   => $next_ca->{'CERTIFICATE.DATA'},
        HASH_ALG => CTX('session')->get_hash_alg(),
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

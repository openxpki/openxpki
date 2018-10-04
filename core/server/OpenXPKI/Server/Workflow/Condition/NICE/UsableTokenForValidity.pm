package OpenXPKI::Server::Workflow::Condition::NICE::UsableTokenForValidity;

use strict;
use warnings;
use OpenXPKI::Server::Context qw( CTX );
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );

sub _evaluate {

    my ( $self, $workflow ) = @_;

    my $notbefore  = $self->param('notbefore');
    my $notafter   = $self->param('notafter');
    my $profile    = $self->param('cert_profile') || 'default';
    my $token      = $self->param('token') || 'certsign';
    my $target_key = $self->param('target_key');


    my $validity_path = [ 'profile', $profile, 'validity' ];
    if (!CTX('config')->exists($validity_path)) {
        $validity_path = [ 'profile', 'default', 'validity' ];
    }

    if (not $notbefore) {
        $notbefore = CTX('config')->get( [ @{$validity_path}, "notbefore" ] );
    }

    if ($notbefore) {
        $notbefore = OpenXPKI::DateTime::get_validity({
            VALIDITYFORMAT => 'detect',
            VALIDITY        => $notbefore,
        });
    } else {
        # assign default (current timestamp) if notbefore is not specified
        $notbefore = DateTime->now( time_zone => 'UTC' );
    }

    if (not $notafter) {
        $notafter = CTX('config')->get( [ @{$validity_path}, "notafter" ] );
    }

    if (not $notafter) {
        configuration_error('I18N_OPENXPKI_UI_CONDITION_NICE_UNABLE_TO_DETERMINE_NOTAFTER_DATE');
    }

    $notafter = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE => $notbefore,
        VALIDITY => $notafter,
        VALIDITYFORMAT => 'detect',
    });


    # Load token, will throw an exception if none is found!
    my $issuing_ca;
    eval {
        $issuing_ca = CTX('api')->get_token_alias_by_type( {
            TYPE => $token,
            VALIDITY => {
                NOTBEFORE => $notbefore,
                NOTAFTER => $notafter,
            },
        });
    };

    if (!$issuing_ca) {
        condition_error('I18N_OPENXPKI_UI_CONDITION_NICE_NO_USEABLE_CA_TOKEN_FOUND');
    }

}

1;

__END__;


=head1 NAME

OpenXPKI::Server::Workflow::Condition::NICE::UsableTokenForValidity

=head1 Description

This condition checks if a CA token is available for a given validity
interval. If you do not specify both sides of the interval, you need to
pass the profile name so the condition will look up the profile
for any notbefore/notafter specification.

The check is usally done with the tokens of the certsign group but you
can pass any other registered type name using the I<token> parameter.

=head1 Configuration

    class: OpenXPKI::Server::Workflow::Condition::NICE::UsableTokenForValidity
    param:
        _map_cert_profile: $cert_profile
        _map_notbefore: $notbefore
        _map_notafter: $notafter

=head2 Parameters

=over

=item notbefore

The notbefore date, must be any format supported by detect mode of
OpenXPKI::DateTime::get_validity. If not given, the profile is checked
for any usable value, last resort is always "now".

=item notafter

The notafterdate, must be any format supported by detect mode of
OpenXPKI::DateTime::get_validity. If not given the profile specification
is used.

=item cert_profile

Name of the certificate profile, mandatory only if you do not provide both
validity values.

=item token

The group name of the token, default is I<certsign>.

=back

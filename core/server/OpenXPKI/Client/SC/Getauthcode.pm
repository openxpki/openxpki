=head1 NAME

OpenXPKI::Client::SC::Utilities

=cut

package OpenXPKI::Client::SC::Getauthcode;

use Moose;
use English;
use Data::Dumper;

extends 'OpenXPKI::Client::SC::Result';


# Developer Note: As Moose calls BUILD from parent to child, this overrides the
# auth setting from the parent result class.

sub BUILD {
    my $self = shift;

    my $user = $ENV{'REMOTE_USER'};
    # force invalidity of any exisiting frontend sessions to trigger auth
    # with overridden information, might be a problem otherwise if
    # personalization was done while AuthPerson was logged in
    $self->_client()->session(undef);
    if ($user) {
        $self->_client()->auth()->{user} = $user;
        $self->logger()->debug('Set session user for getauthcode to ' . $user);
    } else {
        $self->_client()->auth({ stack => 'Anonymous', user => undef });
        $self->logger()->warn('No user in env for getauthcode!');
    }


}

=head2 handle_getauthcode

Create and output the auth codes for the signed in user. The user is read
from $ENV{'REMOTE_USER'}, therefore this requires some external
authentication to be in place.

=head3 parameters

=over

=item id

id of the related pin unblock workflow

=back

=head3 response

=over

=item foruser

mail address of the card owner

=item code

the users part of the activation code

=back

=cut

sub handle_getauthcode {

    my $self = shift;

    my $wf_id = $self->param('id');

    my $wf_info;

    eval {
        $wf_info = $self->_client()->handle_workflow({
            ID => $wf_id,
            ACTIVITY => 'scunblock_generate_activation_code'
        });
    };
    if ($EVAL_ERROR) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_GETAUTHCODE_ERROR_EXECUTING_SCPU_GENERATE_ACTIVATION_CODE");
        return 1;
    }


    if (!$wf_info->{CONTEXT}->{_password}) {

        if ($wf_info->{CONTEXT}->{error_code} &&
            $wf_info->{CONTEXT}->{error_code} eq 'I18N_OPENXPKI_UI_CLIENT_GETAUTHCODE_USER_NOT_AUTH_PERS') {
                $self->_add_error("I18N_OPENXPKI_CLIENT_GETAUTHCODE_ERROR_EXECUTING_SCPU_GENERATE_ACTIVATION_CODE");
        }

        $self->_add_error("I18N_OPENXPKI_CLIENT_GETAUTHCODE_ERROR_FETCHING_ACTIVATION_CODE");
        return 1;
    }

    $self->_result({
        foruser => $wf_info->{CONTEXT}->{owner_cn},
        code =>  $wf_info->{CONTEXT}->{_password},
    });

    return 1;

}

1;

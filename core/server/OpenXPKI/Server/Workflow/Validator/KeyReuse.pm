package OpenXPKI::Server::Workflow::Validator::KeyReuse;

use Moose;
extends 'OpenXPKI::Server::Workflow::Validator';

use English;

use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

use OpenXPKI::Crypt::PKCS10;

sub _validate {
    my ( $self, $wf, $pkcs10 ) = @_;
    ##! 1: 'start'

    ## prepare the environment
    my $context   = $wf->context();

    my $default_token = CTX('api2')->get_default_token();

    # if nothing is there to validate yet, we can return
    return if (! defined $pkcs10 );

    my $csr = OpenXPKI::Crypt::PKCS10->new( $pkcs10 );

    my $pubkey = $csr->get_subject_key_id();

    my $cert_with_same_pubkey = CTX('dbi')->select_one(
        from => 'certificate',
        columns => ['identifier'],
        where => {
            subject_key_identifier => $pubkey,
            $self->param('realm_only')
                ? ( pki_realm => CTX('session')->data->pki_realm )
                : (),
        },
    );

    if (defined $cert_with_same_pubkey) {
        # someone is trying to reuse the same public key ...
        $context->param ("__validation_error" => [{
            error => 'I18N_OPENXPKI_UI_VALIDATOR_KEYREUSE_KEY_ALREADY_EXISTS',
            subject => $cert_with_same_pubkey->{subject},
            identifier => $cert_with_same_pubkey->{identifier},
        }]);

        CTX('log')->application()->error("Trying to reuse private key of certificate " . $cert_with_same_pubkey->{identifier});

        validation_error ( 'I18N_OPENXPKI_UI_VALIDATOR_KEYREUSE_KEY_ALREADY_EXISTS' );
    }

    ##! 1: 'end'
    return 1;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::KeyReuse

=head1 SYNOPSIS

  vaidate_key_reuse:
    class: OpenXPKI::Server::Workflow::Validator::KeyReuse
    param:
      realm_only: 0|1
    arg:
      - $pkcs10

=head1 DESCRIPTION

This validator checks whether a CSR is trying to reuse a key by checking
the subject_key_identifier from the PKCS10 against the certificate database.

=head2 Argument

=over

=item pkcs10

The PKCS10 encoded csr.

=back

=head2 Parameter

=over

=item realm_only

Check key only against certificates in the same realm.

=back

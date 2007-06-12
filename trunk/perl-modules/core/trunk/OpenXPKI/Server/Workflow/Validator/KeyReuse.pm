package OpenXPKI::Server::Workflow::Validator::KeyReuse;

use base qw( Workflow::Validator );

use strict;
use warnings;
use English;

use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

use OpenXPKI::Crypto::CSR;

use Data::Dumper;

sub validate {
    my ( $self, $wf, $csr_type, $pkcs10, $spkac ) = @_;
    ##! 1: 'start'

    ## prepare the environment
    my $context   = $wf->context();
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);

    my $api       = CTX('api');
    my $pki_realm = CTX('session')->get_pki_realm();
    my $cfg_id = $api->get_config_id({ ID => $wf->id() });
    ##! 16: 'cfg_id: ' . $cfg_id
    if (! defined $cfg_id) {
        # as this is called during creation, the cfg id is not defined
        # yet, so we use the current one
        $cfg_id = $api->get_current_config_id();
    }
    my $default_token = CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm}->{crypto}->{default};

    # if nothing is there to validate yet, we can return
    return if (! defined $pkcs10 && ! defined $spkac);

    my $csr;
    if ($csr_type eq 'pkcs10') {
        $csr = OpenXPKI::Crypto::CSR->new(
            DATA   => $pkcs10,
            TOKEN  => $default_token,
            FORMAT => 'PKCS10',
        );
    }
    elsif ($csr_type eq 'spkac') {
        $csr = OpenXPKI::Crypto::CSR->new(
            DATA   => $spkac,
            TOKEN  => $default_token,
            FORMAT => 'SPKAC',
        );
    }
    my $csr_info = $csr->get_info_hash();
    ##! 64: 'csr_info: ' . Dumper $csr_info
    my $pubkey   = $csr_info->{BODY}->{PUBKEY};

    my $cert_with_same_pubkey = CTX('dbi_backend')->first(
        TABLE   => 'CERTIFICATE',
        DYNAMIC => {
            'PUBKEY' => $pubkey,
            # TODO - decide whether we want this to be globally unique
            # or only unique to the PKI realm?
        },
    );
    if (defined $cert_with_same_pubkey) {
        # someone is trying to reuse the same public key ...
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_KEYREUSE_CERTIFICATE_WITH_KEY_ALREADY_EXISTS',
                 {
                   SUBJECT    => $cert_with_same_pubkey->{SUBJECT},
                   IDENTIFIER => $cert_with_same_pubkey->{IDENTIFIER},
                 } ];
        $context->param ("__error" => $errors);
	CTX('log')->log(
	    MESSAGE => "Trying to reuse private key of certificate " . $cert_with_same_pubkey->{IDENTIFIER},
	    PRIORITY => 'warn',
	    FACILITY => 'system',
	    );
        validation_error ($errors->[scalar @{$errors} -1]);
    }
    
    ##! 1: 'end'
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::KeyReuse

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="KeyReuse"
           class="OpenXPKI::Server::Workflow::Validator::KeyReuse">
    <arg value="$csr_type"/>
    <arg value="$pkcs10"/>
    <arg value="$spkac"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks whether a CSR is trying to reuse a key by
checking the public key against those that are in the certificate
database.

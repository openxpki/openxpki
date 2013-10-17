package OpenXPKI::Server::Workflow::Validator::CertIdentifierExists;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );

use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

sub validate {
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
        validation_error("I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_IDENTIFIER_EXISTS_NO_SUCH_ID");    
    }
    
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::Creator

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="Creator"
           class="OpenXPKI::Server::Workflow::Validator::Creator">
  </validator>
</action>

=head1 DESCRIPTION

The validator simply sets the creator and the creator_role hard in
the workflow. It overwrites any user settings. This validator was
designed for use with CRRs.

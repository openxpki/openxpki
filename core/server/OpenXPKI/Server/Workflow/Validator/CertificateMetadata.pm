package OpenXPKI::Server::Workflow::Validator::CertificateMetadata;

use strict;
use warnings;
use base qw( Workflow::Validator );
use OpenXPKI::Server::Context qw( CTX );

sub validate {
    my ( $self, $wf, $role ) = @_;

    ## prepare the environment
    my $context = $wf->context();

    # TODO - Implement me!
    
    return 1;
}

1;
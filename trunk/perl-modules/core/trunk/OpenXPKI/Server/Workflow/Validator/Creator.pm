package OpenXPKI::Server::Workflow::Validator::Creator;

use strict;
use warnings;
use base qw( Workflow::Validator );
use OpenXPKI::Server::Context qw( CTX );

sub validate {
    my ( $self, $wf, $role ) = @_;

    ## prepare the environment
    my $context = $wf->context();

    $context->param ('creator'      => CTX('session')->get_user());
    $context->param ('creator_role' => CTX('session')->get_role());
    
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

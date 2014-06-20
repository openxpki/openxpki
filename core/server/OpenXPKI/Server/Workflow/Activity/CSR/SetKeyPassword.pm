# OpenXPKI::Server::Workflow::Activity::CSR::SetKeyPassword

# Get the volatile/hidden password from the context and store it
# in encrypted form in the workflow
# TODO - encrypt!!

package OpenXPKI::Server::Workflow::Activity::CSR::SetKeyPassword;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    $context->param( 'keypass' => $context->param('_password') );

    return 1;

}

1;

__END__
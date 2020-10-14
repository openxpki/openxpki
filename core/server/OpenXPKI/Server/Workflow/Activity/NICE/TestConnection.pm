package OpenXPKI::Server::Workflow::Activity::NICE::TestConnection;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use English;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Server::NICE::Factory;

sub execute {

    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    CTX('log')->application()->debug("Testing NICE remote connection");

    my $nice_backend = OpenXPKI::Server::NICE::Factory->getHandler( $self );

    my $set_context;
    eval{
        $set_context = $nice_backend->testConnection();
    };

    my $error;
    if ($EVAL_ERROR) {
        $error = 'I18N_OPENXPKI_UI_NICE_BACKEND_ERROR';
    } elsif(!$set_context) {
        $error = $nice_backend->get_last_error() || 'I18N_OPENXPKI_UI_NICE_BACKEND_ERROR';
    }

    $context->param( 'error_code' => $error );

    ##! 64: 'Setting Context ' . Dumper $set_context
    for my $key (keys %{$set_context} ) {
        my $value = $set_context->{$key};
        ##! 64: "Set key: $key to value $value";
        $context->param( { $key => $value } );
    }
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::TestConnection

=head1 Description

Used on RA/CA split systems to test the connection to the remote backend.

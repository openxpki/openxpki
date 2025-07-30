package OpenXPKI::Server::Workflow::Activity::NICE::TestConnection;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::NICE::Factory;

sub execute {

    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    CTX('log')->application()->debug("Testing NICE remote connection");

    my $nice_backend = OpenXPKI::Server::NICE::Factory->getHandler( $self );

    my $set_context;

    my $error;
    try {
        $set_context = $nice_backend->testConnection();
        if (!$set_context) {
            $error = $nice_backend->get_last_error() || 'I18N_OPENXPKI_UI_NICE_BACKEND_ERROR';
        }
    } catch ($err) {
        $error = 'I18N_OPENXPKI_UI_NICE_BACKEND_ERROR';
        CTX('log')->application()->error("Got error on NICE connection test: $err");
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

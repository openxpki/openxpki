package OpenXPKI::Server::Workflow::Activity::NICE::TestConnection;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

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

    my $response = $nice_backend->testConnection();

    foreach my $key (keys %{$response}) {
        my $val = $response->{$key};
        ##! 64: 'Set key ' . $key . ' to ' . $val
        $context->param( $key => $val  );
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::TestConnection

=head1 Description

Used on RA/CA split systems to test the connection to the remote backend.

package OpenXPKI::Server::Workflow::Activity::NICE::CallMethod;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

use OpenXPKI::Server::NICE::Factory;


sub execute {
    my $self     = shift;
    my $workflow = shift;
    my $context = $workflow->context();

    ##! 32: 'context: ' . Dumper( $context )

    my $nice_backend = OpenXPKI::Server::NICE::Factory->getHandler( $self );

    my $param = $self->param();
    my $api_function = $param->{api_method} || configuration_error('The parameter api_method is mandatory');
    if ($api_function !~ m{\A[a-z]\w+\z}) {
        ##! 32: "Invalid api method name $api_function"
        configuration_error('Given api_method is not accepted');
    }
    if (!$nice_backend->can($api_function)) {
        ##! 32: "api method name $api_function not implemented by this backend"
        configuration_error('Given api_method is not implemented by this backend');
    }
    delete $param->{target_key};
    delete $param->{api_method};

    my $set_context = $nice_backend->fetchDomainList($param);
    return unless(defined $set_context);

    # if a target key is given, we pass the full result to it
    if (my $target_key = $self->param('target_key')) {
        ##! 32: 'Set to target key ' .$target_key
        ##! 64: $set_context
        $context->param( $target_key, $set_context );
    # otherwise we assume it is a hash and just map the keys to the context
    } elsif (ref $set_context ne 'HASH') {
        workflow_error('I18N_OPENXPKI_UI_NICE_GENERIC_RESULT_NOT_A_HASH');
    } else {
        ##! 32: 'Map keys to context'
        ##! 64: $set_context
        foreach my $key (keys %{$set_context} ) {
            my $value = $set_context->{$key};
            $context->param( $key, $value );
        }
    }

    return 1;

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::CallMethod;

=head1 Description

Generic wrapper to call a method on the configured NICE backend.

If no cert_identifer is found in the response and retry_count is set,
the activity will go into pause.

See OpenXPKI::Server::NICE::fetchCertificate for details

=head1 Parameters

=head2 Input

=over

=item transaction_id

Transaction id of the request, not required for the Local backend but
might be required by some remote backends to handle polling/retry.

=back

=head2 Output

=over

=item cert_identifier - the identifier of the issued certificate

=back

package OpenXPKI::Server::Workflow::Activity::Tools::SetContext;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;


sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    ##! 1: 'start'

    my $params = $self->param();
    ##! 16: ' parameters: ' . Dumper $params



  KEY:
    foreach my $key (keys %{$params}) {

        ##! 16: 'Key ' . $key
        my $value = $self->param($key);

        ##! 16: 'Value ' . Dumper $value

        if (!defined $value || $value eq '~') {
            $context->param({ $key => undef });
            CTX('log')->application()->debug("Removing $key from context");
        } else {
            $context->param({ $key => $value });
            CTX('log')->application()->debug("Setting context $key to $value");
        }

    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::SetContext

=head1 Description

Set context parameters from the activity definition.

As the empty string is a valid value and passing "undef" via the config is
not possible the special string C<~> (tilde symbol) will delete the key from
the context.

=head2 Configuration

    class: OpenXPKI::Server::Workflow::Activity::Tools::SetContext
    param:
       token: certsign,datasafe

This will create a new context item with key "token" and value
"certsign,datasafe".



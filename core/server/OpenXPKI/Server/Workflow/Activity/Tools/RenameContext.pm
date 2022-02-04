package OpenXPKI::Server::Workflow::Activity::Tools::RenameContext;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use English;


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
        if (defined $value) {
            $context->param({ $key =>  $context->param($value) });
            $context->param({ $value => undef });
        }

        CTX('log')->application()->debug("Rename context from $key to $value");

    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::RenameContext

=head1 Description

Rename context values. Each param is handled as a replacement rule
where the key is the new name and the value is the old name of the
context item.

=head2 Configuration

    class: OpenXPKI::Server::Workflow::Activity::Tools::SetContext
    param:
       renewal_cert_identifier: cert_identifier

This will rename the context item I<cert_identifier> to
I<renewal_cert_identifier>.



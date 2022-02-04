package OpenXPKI::Server::Workflow::Activity::Tools::MergeContextHash;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use English;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use Workflow::Exception qw( configuration_error );

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    ##! 1: 'start'

    my $params = $self->param();
    ##! 16: ' parameters: ' . Dumper $params


    my $key = $self->param('target_key');
    if (!$key) {
        configuration_error('You must define a target_key');
    }
    delete $params->{target_key};

    my $hash = $context->param($key) || {};

    if (!ref $hash) {
        $hash = OpenXPKI::Serialization::Simple->new()->deserialize( $hash );
    }

  KEY:
    foreach my $key (keys %{$params}) {

        ##! 16: 'Key ' . $key
        my $value = $self->param($key);

        ##! 16: 'Value ' . $value

        if (!defined $value) {
            delete $hash->{$key} if ($hash->{$key});
            next;
        }

        $hash->{$key} = $value;

        CTX('log')->application()->debug("Setting $key to $value in context hash ");

    }

    ##! 32: 'hash ' . Dumper $hash
    $context->param({ $key => $hash });

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::MergeContextHash

=head1 Description

Similar to SetContextHash but merges the current value from the context
found at target_key with the result. If a key is set but has an undef
value it is removed from the hash.

=head2 Configuration

    class: OpenXPKI::Server::Workflow::Activity::Tools::MergeContextHash
    param:
       target_key: name_of_the_hash
       key2: ~
       key3: value3

This will remove key2 and add "key3 => value3" to the hash found at
I<name_of_the_hash>.

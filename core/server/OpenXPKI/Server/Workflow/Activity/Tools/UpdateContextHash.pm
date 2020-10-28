package OpenXPKI::Server::Workflow::Activity::Tools::UpdateContextHash;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use English;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    ##! 1: 'start'

    my $params = $self->param();
    ##! 16: ' parameters: ' . Dumper $params

    my $hash;
    my $key = $self->param('target_key');
    if (!$key) {
        configuration_error('You must define a target_key');
    }

    if (my $data = $context->param( $key )) {
        $hash = ref $data ? $data :
            OpenXPKI::Serialization::Simple->new()->deserialize( $data );
    }

    delete $params->{target_key};

  KEY:
    foreach my $key (keys %{$params}) {

        ##! 16: 'Key ' . $key
        my $value = $self->param($key);

        ##! 16: 'Value ' . $value

        if (!defined $value) {
            delete $hash->{$key};
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

OpenXPKI::Server::Workflow::Activity::Tools::UpdateContextHash

=head1 Description

Similar to SetContextHash, if the target_key already contains a hash its
values are merged with the new ones.

=head2 Configuration

    class: OpenXPKI::Server::Workflow::Activity::Tools::UpdateContextHash
    param:
       target_key: name_of_the_hash
       key1: value1
       key2: value2

This will create a single context item with key "name_of_the_hash" with
a hash as value. The hash has the keys key1 and key2 with the appropiate
value. You can use the _map syntax for each key/value pair, values are
added if there are defined (but can be empty).

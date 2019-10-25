package OpenXPKI::Server::Workflow::Activity::Tools::SetAttribute;

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
    my $serializer = OpenXPKI::Serialization::Simple->new();


    my $params = $self->param();
    my $attrib = {};

    ##! 32: 'SetAttrbute action parameters ' . Dumper $params
    foreach my $key (keys %{$params}) {
        my $val = $params->{$key};
        if ($val) {
            ##! 16: 'Set attrib ' . $key
            $workflow->attrib({ $key => $val });
            CTX('log')->workflow()->debug("Writing workflow attribute $key => $val");
        } else {
            ##! 16: 'Unset attrib ' . $key
            # translation from empty to undef is required as the
            # attribute backend will write empty values
            $workflow->attrib({ $key => undef });
            CTX('log')->workflow()->debug("Deleting workflow attribute $key");
        }


    }

    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::SetAttribute

=head1 Description

Set values in the workflow attribute table. Uses the actions parameter list
to determine the key/value pairs to be written. Values that result in an
empty string are removed from the attribute table!

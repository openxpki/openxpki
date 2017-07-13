# OpenXPKI::Server::Workflow::Activity::Tools::SetContext
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::SetContext;

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



  KEY:
    foreach my $key (keys %{$params}) {

        ##! 16: 'Key ' . $key
        my $value = $self->param($key);

        ##! 16: 'Value ' . Dumper $value

        if (defined $value) {
            $context->param($key => $value);
        }

        CTX('log')->application()->debug("Setting context $key to $value");

    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::SetContext

=head1 Description

Set context parameters from the activity definition.

=head2 Configuration

    class: OpenXPKI::Server::Workflow::Activity::Tools::SetContext
    param:
       token: certsign,datasafe

This will create a new context item with key "token" and value
"certsign,datasafe".



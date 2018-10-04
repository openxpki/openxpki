# OpenXPKI::Server::Workflow::Activity::Tools::InjectExtraParam
# Copyright (c) 2015 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::InjectExtraParam;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use English;
use Workflow::Exception qw( configuration_error );

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();

    my $prefix = $self->param('prefix');

    if (!$prefix) {
        configuration_error('I18N_OPENXPKI_ACTIVITY_TOOLS_INJECTEXTRAPARAM_PREFIX_MISSING');
    }

    my $data = $self->param('data');

    if (!$data) {
        return 1;
    }

    if (!ref $data) {
        $data = OpenXPKI::Serialization::Simple->new()->deserialize( $data );
    }

    if (ref $data ne 'HASH') {
        workflow_error('I18N_OPENXPKI_ACTIVITY_TOOLS_INJECTEXTRAPARAM_NOT_A_HASH');
    }

    foreach my $param (keys %{$data}) {
        my $val = $data->{$param};
        if (ref $val ne "") { next; } # Scalars only
        $param =~ s/[\W]//g; # Strip any non word chars
        ##! 32: "Add extra parameter $param with value $val"
        $context->param("$prefix$param" => $val);
    }
}


1;

__END__;


=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::InjectExtraParam

=head1 Description

Create scalar context items from a given hash. The keys are used to
create the context keys, all non-word characters are stripped and the
prefix is prepended. Non-scalar values are skipped.

=head1 Configuration

=head2 Parameters

=over

=item data

The hash with the key/values to map.

=item prefix

The prefix for the keys.

=back

=head2 Example

This is used in the enrollment workflow to map the extra url parameters::

    class: OpenXPKI::Server::Workflow::Activity::Tools::InjectExtraParam;
    param:
        data: $_url_params
        prefix: url_

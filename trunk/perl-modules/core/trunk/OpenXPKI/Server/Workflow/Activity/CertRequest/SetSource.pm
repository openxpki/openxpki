# OpenXPKI::Server::Workflow::Activity::CertRequest:SetSource:
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::CertRequest::SetSource;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::CertRequest::SetSource';
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $source     = $self->param('source');
    my $name       = $self->name;
    ##! 16: 'name: ' . $name
    ##! 16: 'source: ' . $source

    my $source_ref;
    if (defined $context->param('sources')) { # deserialize if present
        ##! 32: 'sources defined'
        $source_ref = $serializer->deserialize(
            $context->param('sources')
        );
    }
    foreach my $field ($workflow->get_action_fields($name)) {
        ##! 64: 'field: ' . $field->name
        if (defined $context->param($field->name)) {
            ##! 64: 'field is in context, setting it in sources'
            $source_ref->{$field->name} = $source;
        }
    }
    $context->param(
        'sources' => $serializer->serialize($source_ref),
    );
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CertRequest::SetSource

=head1 Description

Sets the source (USER | OPERATOR | EXTERNAL) of the certificate
request fields specified in the activity which are present in the
context. This data is saved in the serialized 'sources' hash reference
in the context and (partly) written to the database in PersistRequest.

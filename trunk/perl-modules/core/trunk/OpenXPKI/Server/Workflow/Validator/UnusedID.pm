# OpenXPKI::Server::Workflow::Validator::UnusedID
# Written by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Validator::UnusedID;

use strict;
use warnings;
use base qw( Workflow::Validator );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;

use DateTime;
use Data::Dumper;

sub validate {
    my ( $self, $wf ) = @_;
    my $context    = $wf->context();
    my $input_data = $context->param('_input_data');
    ##! 64: 'input_data: ' . Dumper $input_data

    foreach my $id (keys %{ $input_data }) {
        ##! 16: 'id: ' . $id
        my $workflows = CTX('api')->search_workflow_instances({
            CONTEXT => [
                {
                    KEY   => 'encrypted_' . $id,
                    VALUE => '%',
                },
            ],
            TYPE    => 'I18N_OPENXPKI_WF_TYPE_PASSWORD_SAFE',
        });
        ##! 64: 'workflows: ' . Dumper $workflows
        if (ref $workflows eq 'ARRAY' && scalar @{ $workflows } > 0) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_UNUSED_ID_IS_HAS_BEEN_USED_ALREADY',
                params  => {
                    'ID' => $id,
                },
            );
        }
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::UnusedID

=head1 SYNOPSIS

<action name="store_password">
  <validator name="UnusedID"
           class="OpenXPKI::Server::Workflow::Validator::UnusedID">
  </validator>
</action>

=head1 DESCRIPTION

This validator checks whether a given ID for a password to be saved
in a password safe has already been used in another workflow.

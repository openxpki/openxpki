# OpenXPKI::Server::Workflow::Condition::CRLSigningCAsLeft
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision$
package OpenXPKI::Server::Workflow::Condition::CRLSigningCAsLeft;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use English;

sub _init
{
    my ( $self, $params ) = @_;

    return 1;
}

sub evaluate
{
    my ( $self, $workflow ) = @_;
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $negate = 0;
    if ($self->name() eq 'no_crl_signing_cas_left') {
        $negate = 1;
    }
    my $context   = $workflow->context();

    my $context_ca_ids = $context->param('ca_ids');

    if (! defined $context_ca_ids) {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CRLSIGNINGCASLEFT_CA_IDS_NOT_DEFINED' ]];
        $context->param('__error' => $errors);
        condition_error($errors->[0]);
    }
    
    my $ca_ids_ref = $serializer->deserialize($context_ca_ids);
    my @ca_ids = @{$ca_ids_ref};
    if (scalar @ca_ids == 1) { # we have arrived at the last CA
        if ($negate == 0) {
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CRLSIGNINGCASLEFT_NO_CA_LEFT');
        }
        else {
            return 1; # 'no CAs left?' is true
        }
    }
    else { # there is more then one entry left
        if ($negate == 0) {
            return 1; # 'CAs left?' is true
        }
        else {
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CRLSIGNINGCASLEFT_STILL_CAS_LEFT');
        } 
    }
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CRLSigningCAsLeft

=head1 SYNOPSIS

<action name="do_something">
  <condition name="crl_signing_cas_left"
             class="OpenXPKI::Server::Workflow::Condition::CRLSigningCAsLeft">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if the there are CRL signing CAs left in
the workflow context. If the magic condition name
'no_crl_signing_cas_left' is used, it returns the opposite


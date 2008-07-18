# OpenXPKI::Server::Workflow::Condition::IsCertificateIssuancePossible.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::IsCertificateIssuancePossible;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

use Data::Dumper;

__PACKAGE__->mk_accessors( 'required' );

sub _init
{
    my ( $self, $params ) = @_;
    unless ( $params->{required} )
    {
        configuration_error
             "You must define one value for 'required' in ",
             "declaration of condition ", $self->name;
    }
    $self->required($params->{required});
}

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context  = $workflow->context();
    ##! 16: 'context: ' . Dumper($context)
    my @required_context_params = split(/,/, $self->required());

    my $all_params_present = 1;
    foreach my $param (@required_context_params) {
        if (! defined $context->param("ldap_" . $param)) {
            ##! 16: 'ldap_' . $param . ' is missing'
            $all_params_present = 0;
        }
    }
    
    ##! 16: 'all_params_present: ' . $all_params_present
    if ($all_params_present == 0) {
        condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_ISCERTIFICATEISSUANCEPOSSIBLE_NOT_ALL_REQUIRED_PARAMS_PRESENT');
    }
   return 1; 
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::IsCertificateIssuancePossible

=head1 SYNOPSIS

<action name="do_something">
  <condition name="certificate_issuance_possible"
             class="OpenXPKI::Server::Workflow::Condition::IsCertificateIssuancePossible">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if enough LDAP parameters are present to start
the certificate issuance.
The required parameters are listed in the parameter required in the
condition definition. If all these exist (prefixed with ldap_) in
the workflow context, it returns true, otherwise it fails.

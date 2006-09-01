package OpenXPKI::Server::Workflow::Condition::ContextParameterExistence;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

sub _init
{
    my ( $self, $params ) = @_;

    return 1;
}

sub evaluate
{
    my ( $self, $wf ) = @_;


    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::ContextParameterExistence

=head1 SYNOPSIS

  <condition name="CONTEXT::no_csr_serial_present" class="OpenXPKI::Server::Workflow::Condition::ContextParameterExistence">
    <param name="parameter" value="csr_serial"/>
  </condition>

=head1 DESCRIPTION

The condition checks if the specified key (token id) is usable
(status == 'usable') or unusable (status == 'unusable').


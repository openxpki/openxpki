package OpenXPKI::Server::Workflow::Condition::Key;

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

OpenXPKI::Server::Workflow::Condition::Key

=head1 SYNOPSIS

<action name="do_something">
  <condition name="Condition::Key"
             class="OpenXPKI::Server::Workflow::Condition::Key">
    <param name="key" value="ca"/>
    <param name="status" value="usable"/>
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if the specified key (token id) is usable
(status == 'usable') or unusable (status == 'unusable').


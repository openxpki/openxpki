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

    # FIXME: do some real work here to determine usability ...
    if ($self->name() eq 'CA::key_is_not_usable') {
        condition_error("I18N_OPENXPKI_TESTING_ASSUMES_KEY_USABLE");
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Key

=head1 SYNOPSIS

<action name="do_something">
  <condition name="CA::key_is_usable"
             class="OpenXPKI::Server::Workflow::Condition::Key">
    <param name="key" value="ca"/>
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if the specified key (token id) is unusable
(with the condition name CA::key_is_not_usable) or usable (with
any other condition name).
FIXME:
Currently, it just assumes that the key is always available ...

package OpenXPKI::Server::Workflow::Condition::Key;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use English;

sub evaluate
{
    ##! 1: 'start'
    my ( $self, $wf ) = @_;

    my $context = $wf->context();
    my $ca      = $context->param('ca');

    $context->param('todo_kludge_wf_cond_key', 'workflow condition Key.pm is forced to return true');
    return 1;

=begin temporarily_disabled

    my $realm   = CTX('session')->data->pki_realm;

    ##! 16: 'realm: ' . $realm
    ##! 16: 'ca: ' . $ca
    my $certificate = CTX('pki_realm_by_cfg')->{$cfg_id}->{$realm}->{ca}->{id}->{$ca}->{certificate};
    my $ca_token = CTX('pki_realm_by_cfg')->{$cfg_id}->{$realm}->{ca}->{id}->{$ca}->{crypto};
    ##! 16: 'CA token retrieved'
    if (!defined $ca_token || ! $ca_token->key_usable()) {
        if (!defined $ca_token) {
            ##! 32: 'ca token undefined!'
        }
        ##! 16: 'key unusable condition error'
        condition_error("I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_KEY_UNUSABLE");
    }
    ##! 1: 'end'
    return 1;

=end temporarily_disabled

=cut

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

The condition checks if the specified key (token id) is usable.

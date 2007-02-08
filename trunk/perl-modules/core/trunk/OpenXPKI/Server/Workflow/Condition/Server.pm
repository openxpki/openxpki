package OpenXPKI::Server::Workflow::Condition::Server;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

__PACKAGE__->mk_accessors( 'grant' );

sub _init
{
    my ( $self, $params ) = @_;

    ## check for the required config param
    unless ( exists $params->{server_id} )
    {
        configuration_error
             "You must define one value for 'server_id' in ",
             "declaration of condition ", $self->name;
    }

    ## server_id can be a scalar
    if (not ref $params->{server_id})
    {
        ## only one role -> simplest case
        $params->{server_id} = [ $params->{server_id} ];
    }

    ## get local server_id
    my $server_id = CTX('xml_config')->get_xpath (
                        XPATH    => [ 'common/database/server_id' ],
                        COUNTER  => [ 0 ]);

    ## search for a matching server_id
    $self->grant(0);
    foreach my $id (@{$params->{server_id}})
    {
        ## use string compare to avoid problems with wrong configs
        $self->grant(1) if ($id eq $server_id);
    }
}

sub evaluate
{
    my ( $self, $wf ) = @_;

    if (not $self->grant())
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SERVER_WRONG_SERVER' ]];
        $wf->context()->param ("__error" => $errors);
        condition_error ($errors->[0]);
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Server

=head1 SYNOPSIS

<action name="do_something">
  <condition name="Condition::Server"
             class="OpenXPKI::Server::Workflow::Condition::Server">
    <param name="server_id" value="0"/>
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if the workflow will be executed on the correct
server. Usually such a check must be performed during the workflow
creation. This condition makes only sense in environments where you
have several servers with different security levels (e.g. an offline CA).


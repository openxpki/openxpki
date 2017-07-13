package OpenXPKI::Server::Workflow::Condition::HasRole;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

__PACKAGE__->mk_accessors( 'expected_roles' );

sub _init
{
    my ( $self, $params ) = @_;
    unless ( $params->{roles} )
    {
        configuration_error
             "You must define one value for 'role' in ",
             "declaration of condition ", $self->name;
    }
    $self->expected_roles($params->{roles});
}

sub evaluate
{
    ##! 64: 'start'
    my ( $self, $wf ) = @_;
    my $context = $wf->context();

    my $expected_roles = $self->expected_roles();
    ##! 64: 'expected role: ' . $expected_roles
    if (not $expected_roles)
    {
        ## this is a critical event because we don't know what to verify
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_HASROLE_NO_ROLE' ]];
        $context->param ("__error" => $errors);
        configuration_error ($errors->[0]);
    }

    my $session_role = CTX('session')->data->role || '';

    my %roles = map { $_ => 1 } (split /,\s*/, $expected_roles);

    ##! 64: 'session role: ' . $session_role

    condition_error ("$session_role mismatches $expected_roles") unless ($roles{$session_role});

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::HasRole

=head1 SYNOPSIS

    class: OpenXPKI::Server::Workflow::Condition::HasRole
    param:
        roles: CA Operator,RA Operator

=head1 DESCRIPTION

The condition checks if the current session users role is in the list
of expected roles given as parameter in the configuration.
Multiple roles can be given as comma seperated list.

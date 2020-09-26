package OpenXPKI::Server::Workflow::Condition::UserExists;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( condition_error );
use OpenXPKI::Debug;
use Data::Dumper;
use English;

sub _evaluate
{
    my ( $self, $workflow ) = @_;
    my $param = {};
    $param->{mail}=$self->param("mail") if($self->param("mail"));
    $param->{username}=$self->param("username") if($self->param("username"));
    my $res=CTX('api2')->search_users_count(%$param);

    if($res==0){
        condition_error("I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_NO_USER_FOUND");
    }
    return 0;
}

1;

__END__


=head1 NAME

OpenXPKI::Server::Workflow::Condition::UserExists

=head1 DESCRIPTION

This condition checks whether a user with the username or mail (provided as parameter) exists
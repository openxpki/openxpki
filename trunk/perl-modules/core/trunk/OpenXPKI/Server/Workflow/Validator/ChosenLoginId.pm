# OpenXPKI::Server::Workflow::Validator::ChosenLoginId
# Written by Alexander Klink
# Copyright (c) 2007 Cynops GmbH
# $Revision: 1.1 $

package OpenXPKI::Server::Workflow::Validator::ChosenLoginId;

use strict;
use warnings;
use base qw( Workflow::Validator );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Validator::ReasonCode';
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;

use DateTime;
use Data::Dumper;

sub validate {
    my ( $self, $wf, $role ) = @_;

    my $ser = OpenXPKI::Serialization::Simple->new();

    ## prepare the environment
    my $context = $wf->context();
    my $login_id = $context->param('chosen_loginid');
    ##! 16: 'chosen login id: ' . $login_id
    my @possible_login_ids;
    my $dbntloginid = $context->param('ldap_dbntloginid');
    ##! 16: 'dbntloginid: ' . $dbntloginid
    if ($dbntloginid =~ m{ \A ARRAY }xms) {
        @possible_login_ids = @{ $ser->deserialize($dbntloginid) };
    }
    else {
        $possible_login_ids[0] = $dbntloginid;
    }
    ##! 16: 'possible login ids: ' . Dumper \@possible_login_ids

    if (! grep { $_ eq $login_id } @possible_login_ids) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_LOGIN_ID_INVALID',
        );
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::ChosenLoginID

=head1 SYNOPSIS

<action name="create_server_csr">
  <validator name="ChosenLoginID"
           class="OpenXPKI::Server::Workflow::Validator::ChosenLoginID">
  </validator>
</action>

=head1 DESCRIPTION

This validator checks whether a given login ID is valid by checking
it against the serialized dbntloginid parameter.

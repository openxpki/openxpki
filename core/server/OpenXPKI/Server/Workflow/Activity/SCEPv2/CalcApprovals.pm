# OpenXPKI::Server::Workflow::Activity::SCEPv2::CalcApprovals
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::CalcApprovals;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;

    $workflow->context()->param('have_all_approvals' => '1');
    $workflow->context()->param('todo_kludge_num_approvals' => 'fix in OpenXPKI::Server::Workflow::Activity::SCEPv2::CalcApprovals');

    return 1;

}

1;

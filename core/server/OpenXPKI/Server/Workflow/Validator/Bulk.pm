# OpenXPKI::Server::Workflow::Validator::Bulk
# Written by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Validator::Bulk;

use strict;
use warnings;
use base qw( Workflow::Validator );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;

use DateTime;

sub validate {
    my ( $self, $wf, $bulk ) = @_;

    if (! defined $bulk) {
        return 1;
    }
    if ($bulk != 1) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_BULK_NOT_UNDEF_OR_ONE',
        );
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::Bulk

=head1 SYNOPSIS

<action name="create_csr">
  <validator name="Bulk"
           class="OpenXPKI::Server::Workflow::Validator::Bulk">
  </validator>
</action>

=head1 DESCRIPTION

This validator checks whether the bulk parameter is either not present
or 1.

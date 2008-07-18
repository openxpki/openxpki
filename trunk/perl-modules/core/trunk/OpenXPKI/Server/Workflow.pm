# OpenXPKI Workflow Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project

package OpenXPKI::Server::Workflow;

use strict;
use warnings;
use utf8;
use English;


1;
__END__


=head1 Name

OpenXPKI::Workflow::Activity - only documentation, no code

=head1 Description

OpenXPKI uses a flexible Workflow engine that controls all stateful
operations within the whole system.

For detailed documentation about the implementation please
see the original documentation of the Workflow module.

=head1 Usage documentation and guidelines


=head2 Workflow Instances


=head3 Creation


=head3 Persistence


=head3 Workflow context

See documentation for 
OpenXPKI::Server::Workflow::Persister::DBI::update_workflow()
for limitations that exist for data stored in Workflow Contexts.

=head2 Activities


=head3 Creating new activities

For creating a new Workflow activity it is advisable to start with the
activity template available in OpenXPKI::Server::Workflow::Activity::Skeleton.

=head3 Authorization and access control






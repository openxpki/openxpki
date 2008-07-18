# OpenXPKI::Server::Workflow::Condition::AlwaysTrue.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::AlwaysTrue;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );

sub evaluate {
    return 1;
}
    
1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::AlwaysTrue

=head1 SYNOPSIS

<action name="do_something">
  <condition name="something"
             class="OpenXPKI::Server::Workflow::Condition::AlwaysTrue">
  </condition>
</action>

=head1 DESCRIPTION

This condition always returns true. This is mainly useful as a dummy
condition that does not really check anything.

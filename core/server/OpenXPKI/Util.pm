package OpenXPKI::Util;

use strict;
use warnings;

use English;

=head1 NAME

OpenXPKI::Util - common utility functions to avoid duplicate code.

=head1 FUNCTIONS

=head2 resolve_user_group

Resolves the given user/group specification (either IDs or names) into a list
of IDs B<and> names.

    my ($u,$uid,$g,$gid) = OpenXPKI::Util->resolve_user_group("0", "daemon");
    # ("root", 0, "daemon", 1)

Throws an error in case of unknown IDs or names.

B<Parameters>

=over

=item * B<$user> I<Str> - user ID or name

=item * B<$group> I<Str> - group ID or name

=item * B<$label> I<Str> - label to use in error messages, e.g. C<"server process">. Optional

=item * B<$allow_empty> I<Bool> - allow empty C<$user> or C<$group>. Optional, default: 0

=over

=item * 0 - throw error if user/group is C<undef> or C<"">

=item * 1 - set the related result variables to C<undef> if user/group is C<undef> or C<"">

=back

=back

=cut
sub resolve_user_group {
    my $class = shift if ($_[0] // '') eq __PACKAGE__; # support call via -> and ::
    my ($user, $group, $label, $allow_empty) = @_;

    my ($u, $uid, $g, $gid);

    # convert user name to ID if neccessary
    if (not $allow_empty or (defined $user and $user ne '')) {
        $uid = $user =~ /^\d+$/ ? $user : (getpwnam($user))[2];
        $uid // die "Unknown user '$user'" . ($label ? " specified for $label" : '') . "\n";
        $u = (getpwuid($uid))[0];
    }

    # convert group name to ID if neccessary
    if (not $allow_empty or (defined $group and $group ne '')) {
        $gid = $group =~ /^\d+$/ ? $group : (getgrnam($group))[2];
        $gid // die "Unknown group '$group'" . ($label ? " specified for $label" : '') . "\n";
        $g = (getgrgid($gid))[0];
    }

    return ($u, $uid, $g, $gid);
};

1;

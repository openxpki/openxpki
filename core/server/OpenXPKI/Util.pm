package OpenXPKI::Util;

use strict;
use warnings;

use English;

sub resolve_user_group {
    my $class = shift if ($_[0] // '') eq __PACKAGE__;
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

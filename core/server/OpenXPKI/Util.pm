package OpenXPKI::Util;

use strict;
use warnings;
use utf8;
use English;

sub resolve_user_group {
    my $class = shift if ($_[0] // '') eq __PACKAGE__;
    my ($user, $group, $label) = @_;

    # convert user name to ID if neccessary
    my $uid = $user =~ /^\d+$/ ? $user : (getpwnam($user))[2];
    $uid // die "Unknown user '$user'" . ($label ? " specified for $label" : '');
    my $u = (getpwuid($uid))[0];

    # convert group name to ID if neccessary
    my $gid = $group =~ /^\d+$/ ? $group : (getgrnam($group))[2];
    $gid // die "Unknown group '$group'" . ($label ? " specified for $label" : '');
    my $g = (getgrgid($gid))[0];

    return ($u, $uid, $g, $gid);
};

1;

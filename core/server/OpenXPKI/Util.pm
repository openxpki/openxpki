package OpenXPKI::Util;

use strict;
use warnings;

use English;
use MIME::Base64;

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

=head2 asterisk_to_sql_wildcard

Convert user query string into SQL pattern, i.e. convert (multiple) asterisks
C<*> into percent sign C<%>.

    my $sql_str = OpenXPKI::Util->asterisk_to_sql_wildcard("**test*");
    # "%test%"

B<Parameters>

=over

=item * B<$query> I<Str> - user query string that may include asterisks

=back

=cut
sub asterisk_to_sql_wildcard {
    my $class = shift if ($_[0] // '') eq __PACKAGE__; # support call via -> and ::
    my $query = shift;

    $query =~ s/\*/%/g;
    $query =~ s/%%+/%/g;

    return $query;
}

=head2 filter_hash

Filters the given I<HashRef> so that at maximum the resulting hash only the given
keys.

B<Parameters>

=over

=item * B<$hash> I<HashRef> - source hash to be filtered (may be C<undef> -
this will return an empty I<HashRef>)

=item * B<@keys> I<list> - list of keys that shall be extracted from the source hash

=back

B<Returns>

A I<HashRef> containing the given keys (or less, depending on the source hash).

=cut
sub filter_hash {
    my $class = shift if ($_[0] // '') eq __PACKAGE__; # support call via -> and ::
    my $hash = shift // {};
    my @keys = @_;

    my %filter_hash = map { exists $hash->{$_} ? ($_ => $hash->{$_}) : () } @keys;
    return \%filter_hash;
}

=head2 pem_to_list

Expects a string with one or many PEM encoded items and splits them
into clean PEM blocks in a list.

B<Returns>

A I<ArrayRef> containing the noramlized PEM blocks

=cut

sub pem_to_list {

    my $class = shift if ($_[0] // '') eq __PACKAGE__; # support call via -> and ::

    my $input = shift;

    my @blocks = $input =~ m{(-----BEGIN\ ([^-]+)-----)\s*([\w\/\+\=\s]+)\s*(-----END\ \2-----)}gxms;
    my @output;
    do {
        shift @blocks; # the BEGIN block
        my $separator = shift @blocks; # the separator word without the BEGIN word
        my $payload = MIME::Base64::decode_base64(shift @blocks) || die "Unable to decode PEM payload";
        shift @blocks; # END block

        my $pem = MIME::Base64::encode_base64($payload, '');
        $pem =~ s{ (.{64}) }{$1\n}xmsg;
        chomp $pem;
        push @output, "-----BEGIN $separator-----\n$pem\n-----END $separator-----";
    } while (@blocks);

    return \@output;
}

1;

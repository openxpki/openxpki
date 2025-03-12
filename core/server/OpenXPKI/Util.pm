package OpenXPKI::Util;
use strict;
use warnings;
use English;
use feature 'state';

# Core modules
use MIME::Base64;
use File::Spec;
use IO::Dir 1.03;
use Exporter qw( import );
use Digest::SHA qw( sha1_base64 );

# Symbols to export by default
our @EXPORT = qw( AUTO_ID );

=head1 NAME

OpenXPKI::Util - common utility functions to avoid duplicate code.

=head1 SYNOPSIS

    use OpenXPKI::Util;

The subroutine L</AUTO_ID> is automatically exported, e.g.:

    use OpenXPKI::Util;
    use OpenXPKI::Server::Context qw( CTX );

    CTX('dbi')->insert(
        into => 'certificate_attributes',
        values => {
            attribute_key => AUTO_ID,
            identifier => $cert_identifier,
        }
    );

=cut

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
    shift if ($_[0] // '') eq __PACKAGE__; # support call via -> and ::
    my ($user, $group, $label, $allow_empty) = @_;

    my ($u, $uid, $g, $gid);

    # convert user name to ID if neccessary
    if (not $allow_empty or (defined $user and $user ne '')) {
        $user //= '';
        $uid = $user =~ /^\d+$/ ? $user : (getpwnam($user))[2];
        $uid // die "Unknown user '$user'" . ($label ? " specified for $label" : '') . "\n";
        $u = (getpwuid($uid))[0];
    }

    # convert group name to ID if neccessary
    if (not $allow_empty or (defined $group and $group ne '')) {
        $group //= '';
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
    shift if ($_[0] // '') eq __PACKAGE__; # support call via -> and ::
    my $query = shift;

    $query =~ s/\*/%/g;
    $query =~ s/%%+/%/g;

    return $query;
}

=head2 filter_hash

Filters the given I<HashRef> so that at maximum the resulting hash only contains
the given keys.

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
    shift if ($_[0] // '') eq __PACKAGE__; # support call via -> and ::
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
    shift if ($_[0] // '') eq __PACKAGE__; # support call via -> and ::

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

=head2 is_regular_workflow

Checks if the given workflow ID indicates a regular workflow, i.e. the ID
consists of digits only and is not zero.

    if (OpenXPKI::Util->is_regular_workflow($id)) { ... };

B<Parameters>

=over

=item * B<$wf_id> I<Str> - workflow ID to check

=back

B<Returns>

C<1> if the ID indicates a regular workflow, C<0> another type

=cut

sub is_regular_workflow {
    shift if ($_[0] // '') eq __PACKAGE__; # support call via -> and ::
    my $wf_id = shift;

    return 0 unless defined $wf_id;
    return 0 unless $wf_id =~ m{\A\d+\z};
    return 0 if $wf_id == 0;
    return 1;
}

=head2 AUTO_ID

Used in database C<INSERT>s to automatically set a primary key to the next
serial number (i.e. sequence associated with the table).

See L<OpenXPKI::Server::Database/insert> for details.


=cut

sub AUTO_ID :prototype() {
    state $obj = bless {}, "OpenXPKI::Server::Database::AUTOINCREMENT";
    return $obj;
}

=head2 list_modules

Lists all modules below the given namespace.

Returns a I<HashRef> that maps the found module names to the file paths.

B<Parameters>

=over

=item * C<$namespace> I<Str> - Perl namespace (e.g. C<OpenXPKI::Base::API::Plugin>)

=item * C<$with_subdirs> I<Bool> - whether to dive into subdirectories

=back

=cut
# Taken from Module::List

sub list_modules {
    shift if ($_[0] // '') eq __PACKAGE__; # support call via -> and ::
    my ($prefix, $with_subdirs) = @_;

    my $root_rx = qr/[a-zA-Z_][0-9a-zA-Z_]*/;
    my $notroot_rx = qr/[0-9a-zA-Z_]+/;

    die "Bad module name '$prefix' given to list_modules()"
        unless (
            $prefix =~ /\A(?:${root_rx}::(?:${notroot_rx}::)*)?\z/x
            and $prefix !~ /(?:\A|[^:]::)\.\.?::/
        );

    my @prefixes = ($prefix);
    my %seen_prefixes;
    my %results;

    while(@prefixes) {
        my $prefix = pop(@prefixes);
        my @dir_suffix = split(/::/, $prefix);
        my $module_rx = $prefix eq "" ? $root_rx : $notroot_rx;
        my $pmc_rx = qr/\A($module_rx)\.pmc\z/;
        my $pm_rx = qr/\A($module_rx)\.pm\z/;
        my $dir_rx = $prefix eq "" ? $root_rx : $notroot_rx;
        $dir_rx = qr/\A$dir_rx\z/;
        # Reverse @INC so that modules paths listed earlier win (by overwriting
        # previously found modules in $results{...}.
        # This is similar to Perl's behaviour when including modules.
        for my $incdir (reverse @INC) {
            my $dir = File::Spec->catdir($incdir, @dir_suffix);
            my $dh = IO::Dir->new($dir) or next;
            my @entries = $dh->read;
            $dh->close;
            # list modules
            for my $pmish_rx ($pmc_rx, $pm_rx) {
                for my $entry (@entries) {
                    if($entry =~ $pmish_rx) {
                        my $name = $prefix.$1;
                        $results{$name} = File::Spec->catdir($dir, $entry);
                    }
                }
            }

            next unless $with_subdirs;
            # recurse
            for my $entry (@entries) {
                my $dir = File::Spec->catdir($dir, $entry);
                next unless (
                    File::Spec->no_upwards($entry)
                    and $entry =~ $dir_rx
                    and -d $dir
                );
                my $newpfx = $prefix.$entry."::";
                if (!exists($seen_prefixes{$newpfx})) {
                    push @prefixes, $newpfx;
                    $seen_prefixes{$newpfx} = undef;
                }
            }
        }
    }
    return \%results;
}

=head2 generate_uid

Generate a random uid (RFC 3548 URL and filename safe base64)

=cut
sub generate_uid {
    shift if ($_[0] // '') eq __PACKAGE__; # support call via -> and ::

    my $uid = sha1_base64(time.rand.$$);
    ## RFC 3548 URL and filename safe base64
    $uid =~ tr/+\//-_/;
    return $uid;
}

=head2 is_systemd

Checks if we are running under systemd and returns a I<TRUE> value in that case,
I<FALSE> otherwise.

=cut
sub is_systemd {
    shift if ($_[0] // '') eq __PACKAGE__; # support call via -> and ::

    # check 1: INVOCATION_ID
    return 1 if defined $ENV{INVOCATION_ID};

    # check 2: cgroup
    return 1 if eval {
        my $content = do {
            local $INPUT_RECORD_SEPARATOR;
            my $fh;
            open $fh, '<', "/proc/$$/cgroup" or return;
            <$fh>;
        };
        chomp $content;
        return 1 if $content =~ /system\.slice/;
    };

    return 0;
}

1;

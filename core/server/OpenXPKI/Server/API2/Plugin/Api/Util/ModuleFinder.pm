package OpenXPKI::Server::API2::Plugin::Api::Util::ModuleFinder;
use strict;
use warnings;
use English;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Api::Util::ModuleFinder - Find modules by package name

=head1 METHODS

=cut

# Core modules
use Config '%Config';
use Fcntl;    # for sysopen
use File::Spec::Functions qw(catfile catdir splitdir);


#
# This code is a shortened and modified version of Pod::PerlDoc
#

#..........................................................................

sub TRUE  () {1}
sub FALSE () {return}

BEGIN {
    *is_vms = $^O eq 'VMS' ? \&TRUE : \&FALSE unless defined &is_vms;
    *is_mswin32 = $^O eq 'MSWin32' ? \&TRUE : \&FALSE unless defined &is_mswin32;
}

# % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
###########################################################################

sub new {
    my $class = shift;
    my $self = bless {@_}, (ref($class) || $class);

    $self->{found} ||= [];
    $self->{target} = undef;
    $self->{bindir} = $Config{scriptdirexp} unless exists $self->{bindir};
    $self->{search_path} = [ ] unless exists $self->{search_path};

    # Extend search path if this looks like a module or extension directory
    if (-f "Makefile.PL" || -f "Build.PL") {
        push @{$self->{search_path} }, '.','lib';

        # don't add if superuser
        if ($UID && $EUID && -d "blib") {   # don't be looking too hard now!
            push @{ $self->{search_path} }, 'blib';
        }
    }

    return $self;
}

=head2 find

Searches for the module that contains the given package.

Returns the module path on success, C<undef> otherwise.

=cut
sub find {
    my ($self, $package) = @_;

    die "No package given\n" unless $package;

    my @searchdirs;

    # We must look both in @INC for library modules and in $bindir
    # for executables, like h2xs or perldoc itself.
    push @searchdirs, ($self->{bindir}, @{$self->{search_path}}, @INC);
    if ($self->is_vms) {
        my ($i,$trn);
        for ($i = 0; $trn = $ENV{'DCL$PATH;'.$i}; $i++) {
            push(@searchdirs,$trn);
        }
    }
    else {
        push(@searchdirs, grep(-d, split($Config{path_sep}, $ENV{'PATH'})));
    }

    my $found = $self->searchfor(0, $package, @searchdirs);
    if ($found) {
        $found =~ s,/,\\,g if $self->is_mswin32;
        $found =~ s,',\\',g;
    }

    return $found;
}

sub check_file {
    my($self, $dir, $file) = @_;

    if (length $dir and not -d $dir) {
        return "";
    }

    my $path = catfile($dir, $file);
    if (-f $path and -r _) {
        return $path;
    }

    return "";
}

sub searchfor {
    my($self, $recurse, $s, @dirs) = @_;
    $s =~ s!::!/!g;
    $s = VMS::Filespec::unixify($s) if $self->is_vms;
    return $s if -f $s;

    # Look for $s in @dirs
    my $ret;
    my $dir;

    while ($dir = shift @dirs) {
        next unless -d $dir;
        ($dir = VMS::Filespec::unixpath($dir)) =~ s!/\z!! if $self->is_vms;

        if ($ret = $self->check_file($dir,"$s.pm")) {
            return $ret;
        }

        if ($recurse) {
            opendir(D,$dir) or die "Can't opendir $dir: $!\n";
            my @newdirs = map catfile($dir, $_), grep {
                not /^\.\.?\z/s and
                not /^auto\z/s  and   # save time! don't search auto dirs
                -d  catfile($dir, $_)
            } readdir D;
            closedir(D)     or die "Can't closedir $dir: $!\n";
            next unless @newdirs;
            # what a wicked map!
            @newdirs = map((s/\.dir\z//,$_)[1],@newdirs) if $self->is_vms;
            push(@dirs,@newdirs);
        }
    }
    return ();
}

1;

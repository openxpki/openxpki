# TestCfg.pm - A kludge for consolidating a few test routines
#

package TestCfg;
use Config::Std;
use Data::Dumper;
use Class::Std;
{
    # Class attributes
    my %cfg_of; # stores the configuration

    # which NAME, DIR ...
    # returns the full path in which the file NAME was found
    sub which {
        my $self = shift;
        my $name = shift;
        my @dirs = @_;

        foreach (@dirs) {
            my $path = $_ . '/' . $name;
            if ( -f $path ) {
                return $path;
            }
        }
        return;
    }

    sub read_config_path {
        my $self    = shift;
        my $cfgname = shift;
        my $cfgref  = shift;

#        warn "cfgname=", Dumper($cfgname), ", cfgref=", Dumper($cfgref),
#          ", path=", Dumper( \@_ );
        my $cfgfile = $self->which(
            $cfgname, @_);
        if ( not $cfgfile ) {
            die "ERROR: couldn't fine $cfgname in ", join( ', ', @_ );
        }

        read_config( $cfgfile => %{$cfgref} );
        $cfg_of{ident $self} = $cfgref;
    }

 # load_ldap - (re)load LDIF into LDAP, deleting previous records, if necessary.
 # NOTE: this requires $ENV{DESTRUCTIVE_TESTS} to be a true value
 # usage: load_ldap( CFGNAME, PATH... );

    sub load_ldap {
        my $self    = shift;
        my $ldifname = shift;

        if ( not $ENV{DESTRUCTIVE_TESTS} ) {
            print "# skipping destructive tests...\n";
            return;
        }

        my $cfg = $cfg_of{ident $self};
        if ( not ref($cfg) ) {
            die "ERROR: must load config before ldap (", Dumper($cfg), ")";
        }

        my $ldiffile = $self->which( $ldifname, @_ );
        if ( not $ldiffile ) {
            die "ERROR: couldn't fine $ldifname in ", join( ', ', @_ );
        }

        # Purge previous LDAP data (this means: grab all
        # lines from the ldif file that begin with "dn:"
        # and use "ldapdelete" to remove them from LDAP.

        my $fh;
        my @dn = ();
        if ( not open( $fh, "<" . $ldiffile ) ) {
            die "Error reading $ldiffile: $!";
        }
        while ( my $line = <$fh> ) {
            chomp $line;
            if ( $line =~ s{ \A dn:\s* }{}xm ) {
                push @dn, $line;
            }
        }
        close $fh;

#        warn "# DNs found: ", join( "\n#\t", '', @dn ), "\n";
#        warn "# Using LDAP config ",
          join( '/',
            $cfg->{'ldapadmin'}{'user'},
            $cfg->{'ldapadmin'}{'pass'},
            $cfg->{'ldapadmin'}{'url'} ),
          "\n";
        my @cmd = (
            $cfg->{instance}{ldapdelete}, '-x',
            '-c',                       '-D',
            $cfg->{'ldapadmin'}{'user'},  '-w',
            $cfg->{'ldapadmin'}{'pass'},  '-H',
            $cfg->{'ldapadmin'}{'url'},   @dn
        );
#        warn "# cmd: ", join( ', ', @cmd ), "\n";
        my $rcLdapDel = system(@cmd);
        if ( not( $rcLdapDel == 0 or $rcLdapDel == 8192 ) ) {
            die "Error running ldapdelete: $rcLdapDel";
        }

        #
        # Pump LDAP with correct data
        @cmd = (
            $cfg->{instance}{ldapadd}, '-a',
            '-c',                    '-x',
            '-D',                    $cfg->{'ldapadmin'}{'user'},
            '-w',                    $cfg->{'ldapadmin'}{'pass'},
            '-H',                    $cfg->{'ldapadmin'}{'url'},
            '-f', $ldiffile
        );
#        warn "# cmd: ", join( ', ', @cmd ), "\n";
        my $rcLdapAdd = system(@cmd);
        if ( $rcLdapAdd != 0 ) {
            die "Error running ldapadd: $rcLdapAdd";
        }

    }

}

1;

__END__

=head1 NAME

TestCfg

=head1 DESCRIPTION

This is a helper module for the test scripts.

=head1 SYNOPSIS

    use TestCfg;
    use File::Basename;
    my $dirname = dirname($@);
    my $cfgfile = 'filename_without_path.cfg';
    my %cfg = ();
    read_config(
        $cfgfile => %cfg,
        path => [ $dirname . '/../../../config/tests/testset', $dirname ],
    );



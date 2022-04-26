package OpenXPKI::Dumper;

use Data::Dumper;
use Exporter 'import';
our @EXPORT = qw(SDumper);

sub SDumper {
    return Dumper CensorHash(shift);
}

sub CensorHash {
    my $data = shift;
    return $data unless(ref $data eq 'HASH');
    my @wordlist = ('_password','_private_key');
    my %out = map {
        my $vv = $data->{$_};
        my $kk = $_;
        if (grep { $_ eq $kk } @wordlist) {
            ($kk => 'sensitive content');
        } elsif (ref $vv eq 'HASH') {
            my %int = map {
                my $ki = $_;
                if (grep { $_ eq $ki } @wordlist) {
                    ($ki => 'sensitive content')
                } else {
                    ($ki => $vv->{$ki});
                }
            } keys %$vv;
            ($kk => \%int );
        } else {
            ($kk => $vv);
        }
    } keys %$data;
    return \%out;
}

1;

__END__;


=head1 Name

OpenXPKI::Dumper

=head1 Description

Implement Data::Dumper like methods to output hash refs.

=head1 Methods

=head2 CensorHash

Filter the first two levels of a hash for potentially sensitive
keys and remove their content. Returns a (shallow) copy of the
given hashref.

If the given argument is not a hashref, it is returned as is.

=head2 SDumper

Dumps the value of the given hash using Data::Dumper after
calling CensorHash.


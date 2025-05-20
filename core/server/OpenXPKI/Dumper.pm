package OpenXPKI::Dumper;
use OpenXPKI;

use Exporter 'import';
our @EXPORT = qw(SDumper);

sub SDumper {
    return Dumper CensorHash(shift);
}

sub CensorHash {
    my $data = shift;
    return $data unless(ref $data eq 'HASH');
    my @wordlist = ('password','_password','_private_key','client_secret');
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


=head1 NAME

OpenXPKI::Dumper

=head1 DESCRIPTION

Implement Data::Dumper like methods to output hash refs.

=head1 METHODS

=head2 CensorHash

Filter the first two levels of a hash for potentially sensitive
keys and remove their content. Returns a (shallow) copy of the
given hashref.

If the given argument is not a hashref, it is returned as is.

=head2 SDumper

Dumps the value of the given hash using L<Data::Dumper> after
calling L</CensorHash>.


package OpenXPKI::Config::Loader::YAML;
use OpenXPKI;

# CPAN modules
use YAML::PP;

=head1 NAME

OpenXPKI::Config::Loader::YAML - Loader module for L<Config::Merge> that uses L<YAML::PP>

=head1 DESCRIPTION

This is a replacement for L<Config::Any::YAML> which provides only the two methods
that L<Config::Merge> uses: L</extensions> and L</load>.

=head1 METHODS

=head2 extensions( )

return an array of valid extensions (C<yml>, C<yaml>).

=cut

sub extensions {
    return qw( yml yaml );
}

=head2 load( $file )

Attempts to load C<$file> as a YAML file.

=cut

sub load ($class, $file) {
    return YAML::PP->new->load_file($file);
}

1;

package OpenXPKI::Template::Plugin::Alias;
use OpenXPKI;

use parent qw( Template::Plugin );

=head1 OpenXPKI::Template::Plugin::Alias

Plugin for Template::Toolkit to retrieve properties of an alias.

=cut

=head2 How to use

You need to load the plugin into your template before using it. As we do not
export the methods, you need to address them with the plugin name, e.g.

    [% USE Alias %]

    The alias [% alias %] corresponds to the certificate identifier [% Alias.cert_identifier(alias) %]

Will result in

     The alias ca-signer-1 corresponds to the certificate identifier fwe21344t53TODO

=cut

use DateTime;
use OpenXPKI::DateTime;
use OpenXPKI::Server::Context qw( CTX );


=head2 cert_identifier

Returns the certificate identifier for the given alias

=cut
sub cert_identifier {
    my $self=shift;
    my $alias=shift;
    my $info = CTX('api2')->get_certificate_for_alias( alias => $alias );

    if (exists $info->{identifier}){
        return $info->{identifier}
    }
    OpenXPKI::Exception->throw (
        message => "Could not fetch certificate identifier for alias",
        params  => {
            alias => $alias
        },
    );
}

1;

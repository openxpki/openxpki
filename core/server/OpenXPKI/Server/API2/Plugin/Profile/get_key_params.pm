package OpenXPKI::Server::API2::Plugin::Profile::get_key_params;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::get_key_params

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

=head2 get_key_params

Returns all input parameters accepted by the selected algorithm as defined for
the given profile (or the default).

If no algorithm is given, only returns a list of all possible parameters in all
algorithms (used for prerendering the UI forms).

Note: This does not check if the algorithm is in the supported list for the
given profile, use API command C<get_key_alg> to accomplish this.

B<Parameters>

=over

=item * C<profile> I<Str> - certificate profile, required

=item * C<alg> I<Str> - algorithm, default: all algorithms

=item * C<showall> I<Bool> - also show hidden algorithms (beginning with an underscore)

=back

B<Changes compared to API v1:> Parameter C<NOHIDE> was renamed to C<showall>

=cut
command "get_key_params" => {
    profile => { isa => 'AlphaPunct', required => 1, },
    alg     => { isa => 'AlphaPunct', },
    showall => { isa => 'Bool', default => 0, },
} => sub {
    my ($self, $params) = @_;

    if (not $params->has_alg) {
        # TODO - grab that from the config
        return [ 'key_length', 'curve_name' ];
    }

    my $profile = $params->profile;
    my $algorithm = $params->alg;

    my $path;

    my $config = CTX('config');
    $profile = 'default' unless $config->exists([ 'profile', $profile, 'key', $algorithm ]);

    my @keys = $config->get_keys([ 'profile', $profile, 'key', $algorithm ]);
    my $result;
    for my $key (@keys) {
        my @param = $config->get_list( [ 'profile', $profile, 'key', $algorithm, $key ] );
        if ($params->showall) {
            map { $_ =~ s/\A_// } @param; # strip leading underscore
        }
        else {
            @param = grep { $_ !~ /^_/ } @param; # filter argument starting with underscore
        }
        $result->{$key} = \@param if @param;
    }

    return $result;
};

__PACKAGE__->meta->make_immutable;

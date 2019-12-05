package OpenXPKI::Template::Plugin::Metadata;

=head1 OpenXPKI::Template::Plugin::Metadata

Plugin for Template::Toolkit to retrieve metadata via the config layer.
The plugin can access any value below the metadata node in the realm.

=cut

=head2 How to use

You need to load the plugin into your template before using it. As we do not
export the methods, you need to address them with the plugin name, e.g.

    [% USE Metadata %]
    [% Metadata.get(prefix, value, suffix) %]

=cut

use strict;
use warnings;
use utf8;

use base qw( Template::Plugin );
use Template::Plugin;

use OpenXPKI::Server::Context qw( CTX );

=head2 get(prefix, value, suffix)

Read a scalar value from the config layer at "metadata.prefix.value.suffix".

If prefix contain dots it is considered to be a connector path. Value is
taken as single path item which can contain dots and can also be empty.

Suffix is optional, if set the call to prefix.value is done using get_hash
and suffix must be the name of a key returned by this call.

=cut

sub get {

    my $self = shift;
    my $prefix = shift;
    my $value = shift;
    my $suffix = shift || '';

    my @path = split /\./, $prefix;
    push @path, $value if (defined $value);
    unshift @path, 'metadata';

    if (defined $suffix) {
        my $data = CTX('config')->get_hash(\@path);
        return unless ($data && defined $data->{$suffix});
        return $data->{$suffix};
    } else {
        return CTX('config')->get(\@path);
    }

}


=head2 get(prefix, value)

Calls get_hash from the config layer at "metadata.prefix.value".

If prefix contain dots it is considered to be a connector path. Value is
taken as single path item which can contain dots and can also be empty.

=cut

sub get_hash {

    my $self = shift;
    my $prefix = shift;
    my $value = shift;
    my $suffix = shift || '';

    my @path = split /\./, $prefix;
    push @path, $value if (defined $value);
    unshift @path, 'metadata';

    my $data = CTX('config')->get_hash(\@path);
    return unless ($data && ref $data eq 'HASH');
    return $data;

}

1;

__END__;

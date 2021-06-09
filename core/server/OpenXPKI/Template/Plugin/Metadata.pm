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
    my $suffix = shift || undef;

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


=head2 creator(userid)

Split the given userid into namespace and user and call
auth.creator.I<namespace>.I<userid> which will display the
verbose name of the userid in the namespace.

If the userid does not contain a namespace or no username can be
resolved, the method will return undef.

For items in the reserved namespaces the plugin method returns default
values in case the node auth.creator.namespace does not exist.
The namespace I<certid> returns the full subject of the certificate, in
I<system> the literal name is returned.

=cut

sub creator {

    my $self = shift;
    my $creator = shift;

    # if namespacing is not set up at all and the creator does not have
    # one of the internally handled namespaces we just return the creator
    # name. This allows us to use the internal namespaces without the need
    # to use it on the customer level and even allows the colon in usernames
    if (!CTX('config')->exists(['auth', 'creator']) && $creator !~ m{\A(certid|system)}) {
        return $creator;
    }

    my ($namespace, $userid) = ($creator =~ m{ \A (\w {3,8}):(.+) }x);

    if (!defined $namespace) {
        # if somebody switched to namespaces prevent messing up the UI
        return 'I18N_OPENXPKI_UI_WORKFLOW_CREATOR_ANONYMOUS' if ($creator eq 'Anonymous');

        # return undef if the userid has no namespace
        return;
    }

    my $username = CTX('config')->get(['auth', 'creator', $namespace, $userid]);

    return $username if ($username);

    return $userid if ($namespace eq 'system');

    return unless ($namespace eq 'certid');

    my $cert;
    eval {
        $cert = CTX('api2')->get_cert( identifier => $userid, format => 'DBINFO' );
    };

    return $cert->{subject};

}

1;

__END__;

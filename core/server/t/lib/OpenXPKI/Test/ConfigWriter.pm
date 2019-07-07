package OpenXPKI::Test::ConfigWriter;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::ConfigWriter - Create test configuration files (YAML)

=cut

# Core modules
use File::Path qw(make_path);
use File::Spec;

# CPAN modules
use Moose::Util::TypeConstraints;
use YAML::Tiny 1.69;
use Test::More;
use Test::Exception;
use Test::Deep::NoTest qw( eq_deeply bag ); # use eq_deeply() without beeing in a test

=head1 DESCRIPTION

Methods to create a configuration consisting of several YAML files for tests.

=cut

# TRUE if the initial configuration has been written
has is_written => (
    is => 'rw',
    isa => 'Bool',
    init_arg => undef,
    default => 0,
);

has basedir => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has _config => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
    init_arg => undef, # disable assignment via construction
);

# Following attributes must be lazy => 1 because their builders access other attributes

has path_config_dir     => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->basedir."/etc/openxpki/config.d" } );
has path_log_file       => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->basedir."/var/log/openxpki/catchall.log" } );

has path_openssl        => ( is => 'rw', isa => 'Str', default => "/usr/bin/openssl" );
has path_javaks_keytool => ( is => 'rw', isa => 'Str', default => "/usr/bin/keytool" );
has path_openca_scep    => ( is => 'rw', isa => 'Str', default => "/usr/bin/openca-scep" );


sub _make_dir {
    my ($self, $dir) = @_;
    return if -d $dir;
    make_path($dir) or die "Could not create temporary directory $dir: $@"
}

sub _make_parent_dir {
    my ($self, $filepath) = @_;
    # Strip off filename portion to create parent dir
    $self->_make_dir( File::Spec->catpath((File::Spec->splitpath( $filepath ))[0,1]) );
}

sub write_str {
    my ($self, $filepath, $content) = @_;

    die "Empty content for $filepath" unless $content;
    $self->_make_parent_dir($filepath);
    open my $fh, ">:encoding(UTF-8)", $filepath or die "Could not open $filepath for UTF-8 encoded writing: $@";
    print $fh $content, "\n" or die "Could not write to $filepath: $@";
    close $fh or die "Could not close $filepath: $@";
}

sub write_private_key {
    my ($self, $realm, $alias, $pem_str) = @_;

    my $filepath = $self->get_private_key_path($realm, $alias);
    $self->_make_parent_dir($filepath);
    $self->write_str($filepath, $pem_str);
}

sub remove_private_key {
    my ($self, $realm, $alias) = @_;

    my $filepath = $self->get_private_key_path($realm, $alias);
    unlink $filepath or die "Could not remove file $filepath: $@";
}

sub write_yaml {
    my ($self, $filepath, $data) = @_;

    $self->_make_parent_dir($filepath);
    note "Writing $filepath";
    $self->write_str($filepath, YAML::Tiny->new($data)->write_string);
}

sub add_config {
    my ($self, %entries) = @_;

    # notify user about added custom config
    my $pkg = __PACKAGE__; my $line; my $i = 0;
    while ($pkg and ($pkg eq __PACKAGE__ or $pkg =~ /^(Eval::Closure::|Class::MOP::)/)) {
        ($pkg, $line) = (caller(++$i))[0,2];
    }

    # user specified config data might overwrite default configs
    for (keys %entries) {
        $self->_add_config_entry($_, $entries{$_}, "$pkg:$line");
    }
}

# Add a configuration node (I<HashRef>) below the given configuration key
# (dot separated path in the config hierarchy)
#
#     $config_writer->add_config('realm.alpha.workflow', $workflow);
sub _add_config_entry {
    my ($self, $key, $data, $source) = @_;

    die "add_config() must be called before create()" if $self->is_written;
    my @parts = split /\./, $key;
    my $node = $self->_config; # root node

    my $overwrite_hint ="";
    # given data is a structure (i.e.: "node")
    if (ref $data eq 'HASH') {
        for my $i (0..$#parts) {
            $node->{$parts[$i]} //= {};
            $node = $node->{$parts[$i]};
        }
        $overwrite_hint = " # replaces existing node (may be prevented by more precise config path)" if scalar keys %$node;
        %{$node} = %$data; # intentionally replace any probably existing data
    }
    # given data is a config value (i.e. "leaf": scalar or e.g. array ref)
    else {
        my $last_key = $parts[-1];
        for my $i (0..$#parts-1) {
            $node->{$parts[$i]} //= {};
            $node = $node->{$parts[$i]};
        }
        $overwrite_hint = " # replaces existing value" if $node->{$last_key};
        $node->{$last_key} = $data;
    }

    note sprintf("- %s%s%s",
        $key,
        $source ? " ($source)" : "",
        $overwrite_hint,
    );
}

=head2 get_config_node

Returns a all config data that was defined below the given dot separated config
path. This might be a HashRef (config node) or a Scalar (config leaf).

B<Parameters>

=over

=item * I<$config_key> - dot separated configuration key/path

=item * I<$allow_undef> - set to 1 to return C<undef> instead of dying if the
config key is not found

=back

=cut
sub get_config_node {
    my ($self, $config_key, $allow_undef) = @_;

    # Part 1: exact matches and superkeys
    my @parts = split /\./, $config_key;
    my $node = $self->_config; # root node

    for my $i (0..$#parts) {
        $node = $node->{$parts[$i]}
            or ($allow_undef ? return : die "Configuration key $config_key not found");
    }
    return $node;
}

sub create {
    my ($self) = @_;

    $self->_make_dir($self->path_config_dir);
    $self->_make_parent_dir($self->path_log_file);

    # write all config files
    for my $level1 (sort keys %{$self->_config}) {
        for my $level2 (sort keys %{$self->_config->{$level1}}) {
            my $filepath = sprintf "%s/%s/%s.yaml", $self->path_config_dir, $level1, $level2;
            $self->write_yaml($filepath, $self->_config->{$level1}->{$level2});
        }
    }

    $self->is_written(1);
}

=head2 get_private_key_path

Returns the private key path for the certificate specified by realm and alias.

B<Parameters>

=over

=item * C<$realm> (I<Str>) - PKI realm

=item * C<$alias> (I<Str>) - Token alias incl. generation (i.e. "ca-signer-1")

=back

=cut
sub get_private_key_path {
    my ($self, $realm, $alias) = @_;
    return sprintf "%s/etc/openxpki/ssl/%s/%s.pem", $self->basedir, $realm, $alias;
}

=head2 get_realms

Returns an ArrayRef with all realm names defined by default, by roles or user.

=cut
sub get_realms {
    my ($self) = @_;
    return [ keys %{ $self->_config->{system}->{realms} } ];
}

=head2 default_realm

Returns the first defined test realm. The result may be different if other roles
are applied to C<OpenXPKI::Test>.

=cut
sub default_realm {
    my ($self) = @_;
    return $self->get_realms->[0];
}

__PACKAGE__->meta->make_immutable;

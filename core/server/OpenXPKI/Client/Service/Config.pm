package OpenXPKI::Client::Service::Config;
use OpenXPKI qw( -class -typeconstraints );

# Core modules
use File::Spec;

# CPAN modules
use List::Util qw(any);

# Project modules
use OpenXPKI::i18n qw( set_language set_locale_prefix);
use OpenXPKI::Config::Backend;

extends 'Connector::Multi';

has 'config_dir' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => '/etc/openxpki/frontend.d',
);

has '+BASECONNECTOR' => (
    is => 'rw',
    isa => 'Connector',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->backend();
    },
);

has backend => (
    is => 'rw',
    isa => 'Connector',
    init_arg => 'backend',
    lazy => 1,
    default => sub {
        my $self = shift;
        return OpenXPKI::Config::Backend->new(LOCATION => $self->config_dir);
    },
);

has credential_backend => (
    is => 'rw',
    isa => 'Bool',
    default => 0
    );

# Here we do the chain loading of a serialized/signed config
sub BUILD {
    my $self = shift;
    my $args = shift;

    # when we are here, the BASECONNECTOR is already initialized which is
    # usually an instance of O::C::Backend. We now probe if there is a
    # node called "bootstrap" and if so we replace the current backend
    if ($self->backend()->exists('bootstrap')) {

        # this is a connector definition
        my $bootstrap = $self->backend()->get_hash('bootstrap');

        my $class = $bootstrap->{class} || 'OpenXPKI::Config::Loader';
        if ($class !~ /\A(\w+\:\:)+\w+\z/) {
            die "Invalid class name $class";
        }
        ##! 16: 'Config bootstrap ' . Dumper $bootstrap
        eval { Module::Load::load($class) }; die "Unable to bootstrap config, can not use $class: $@" if $@;

        delete $bootstrap->{class};

        my $conn = $class->new( $bootstrap );
        $self->backend( $conn );
    }

    # we initialize the checksum before injecting the code ref to avoid setting
    # $Storable::Deparse and to have the same hash with openxpkiadm
    $self->backend()->checksum();

    # If the node credential is defined on the top level we make assume
    # it contains a connector specification to create a globally available
    # node to receive passwords from
    if ($self->backend()->exists('credentials')) {
        my $conn = $self->backend();
        my $meta = $conn->get_meta('credentials');
        if ($meta->{TYPE} ne "hash" || !$conn->exists('credentials.class')) {
            warn "Found credential node but it does not look like a connector specification"
        } else {
            # There is a dragon inside! We read the connector details and
            # afterwards delete the node and write back the preinitialized
            # connector. This makes assumptions on the internal cache and might
            # also not work with other backend classes.
            $self->credential_backend(1);
            my $cc = $self->get_connector('credentials');
            $self->_init_cache();
            # as it is not allowed to change the type we need to unset it first
            $conn->set('credentials' => undef);
            # now we directly attach the connector to it
            $conn->set('credentials' => $cc);
            Log::Log4perl->get_logger('system')->info("Added credential connector");
        }
    }

    # check if the system node is present
    $self->backend()->exists('system') || die "Loaded config does not contain service node.";

}

sub checksum {
    my $self = shift;
    $self->BASECONNECTOR()->_config(); # makes sure the backend is initialized
    return $self->BASECONNECTOR()->checksum();
}


sub endpoint_config {

    my $self = shift;
    my $service = shift;
    my $endpoint = shift;

    # Special handling of WebUI
    if ($service eq 'webui') {
        return $self->get_wrapper(['service', 'webui', 'default']);
    }

    if (!$endpoint) {
        $self->log()->info("Request for service config requires endpoint");
        return undef;
    }

    # @todo: Implement wildcard and default config
    if (!$self->exists(['service', $service, $endpoint ])) {
        $self->log()->info("Requested service config ($service/$endpoint) does not exist");
        return undef;
    }
    return $self->get_wrapper(['service', $service, $endpoint ]);

}

1;

__END__
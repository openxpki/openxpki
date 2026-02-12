package OpenXPKI::Client::Service::WebUI::Session;
use OpenXPKI -class;

require overload;

# Core modules
use Digest::MD5;
use Digest::SHA qw( hmac_sha256_hex );
use MIME::Base64;
use Data::Dumper ();
use Safe;
use Scalar::Util qw( reftype refaddr );
use Carp;

# CPAN modules
use Log::Log4perl qw( :easy );
use Crypt::CBC;

# Project modules
use OpenXPKI::Database;

=head1 NAME

OpenXPKI::Client::Service::WebUI::Session - Frontend session management

=head1 DESCRIPTION

A standalone session class for OpenXPKI frontend sessions, storing data in a
SQL database.

Session data is serialized with L<Data::Dumper> and optionally encrypted with
AES. Session IDs are HMAC-hashed when an encryption key is configured.

=head2 SQL SCHEMA

    CREATE TABLE IF NOT EXISTS `frontend_session` (
      `session_id` varchar(255) NOT NULL PRIMARY KEY,
      `data` longtext,
      `created` int(10) unsigned NOT NULL,
      `modified` int(10) unsigned NOT NULL,
      `ip_address` varchar(45) DEFAULT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE utf8mb4_general_ci;

=head1 SYNOPSIS

    my $session = OpenXPKI::Client::Service::WebUI::Session->new(
        db_params   => \%params,    # passed to OpenXPKI::Database->new(db_params => ...)
        id          => $sid,        # skip or set to undef to create a new session
        table_name  => 'test',      # optional
        encrypt_key => $key,        # optional
        log_ip      => 1,           # optional
    );

=cut

# Status bit flags for tracking session state
use constant {
    STATUS_UNSET    => 1 << 0,
    STATUS_NEW      => 1 << 1,
    STATUS_MODIFIED => 1 << 2,
    STATUS_DELETED  => 1 << 3,
};

=head1 ATTRIBUTES

=cut
=head2 db_params

A I<HashRef> of parameters passed to L<OpenXPKI::Database> to construct the
database connection. Must contain at least C<type> (e.g. C<"MySQL">,
C<"SQLite">) and any driver-specific keys such as C<name>, C<host>, C<user>,
C<passwd>.

=cut

has db_params => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

=head2 db

The L<OpenXPKI::Database> instance used for all database operations. Built
automatically from L</db_params>.

=cut

has db => (
    is => 'ro',
    isa => 'OpenXPKI::Database',
    lazy => 1,
    init_arg => undef,
    builder => '_build_db',
);

sub _build_db ($self) {
    OpenXPKI::Database->new(
        log => $self->log,
        db_params => $self->db_params,
        autocommit => 1,
    );
}

=head2 encrypt_key

If provided, session data will be encrypted using AES via L<Crypt::CBC>. The
session IDs will also be HMAC-hashed using this key.

=cut

has encrypt_key => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_encrypt_key',
);

=head2 log_ip

If enabled, the client's IP address will be logged in the session table.

=cut

has log_ip => (
    is => 'ro',
    isa => 'Bool',
    default => sub { 0 },
);

=head2 table_name

The name of the database table used to store session data.

Default: C<"frontend_session">. The database namespace (if any) is handled
by the L<OpenXPKI::Database> driver.

=cut
has table_name => (
    is => 'ro',
    isa => 'Str',
    default => sub { 'frontend_session' },
);

# Requested session ID (may be undef for new sessions).
# After construction, use the id() method to get the effective session ID.
has requested_id => (
    is => 'ro',
    isa => 'Str|Undef',
    init_arg => 'id',
);

# Session metadata (id, ctime, atime, etime, expire_list)
has metainfo => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
    default => sub { +{} },
    lazy => 1,
    clearer => 'clear_metainfo', # resets to default if lazy => 1
);

# User session parameters
has params => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
    default => sub { +{} },
    lazy => 1,
    clearer => 'clear_params', # resets to default if lazy => 1
);

# Session state bitmask (bare = no accessor, accessed via hash slot)
has status => (
    is => 'bare',
    init_arg => undef,
    default => sub { STATUS_UNSET },
);

=head2 crypt

Optional encryption handler for session data. If L</encrypt_key> is set,
this attribute will be initialized with a L<Crypt::CBC> object configured to
use AES encryption via L<Crypt::OpenSSL::AES>.

The encryption is used to protect session data stored in the database. When
no encryption key is provided, session data is stored in plaintext and this
attribute remains undefined.

=cut

has crypt => (
    is => 'ro',
    lazy => 1,
    init_arg => undef,
    default => sub ($self) {
        return unless $self->has_encrypt_key;
        Crypt::CBC->new(
            -key => $self->encrypt_key,
            -cipher => 'Crypt::OpenSSL::AES',
            -nodeprecate => 1,
        );
    },
);

has log => (
    is => 'ro',
    lazy => 1,
    init_arg => undef,
    default => sub { Log::Log4perl->get_logger('openxpki.client.service.webui.session') },
);

sub BUILD ($self, $args) {
    Log::Log4perl->initialized or Log::Log4perl->easy_init($ERROR);

    # Try to load existing session from database
    if (my $sid = $self->requested_id) {
        $self->_db_load($sid);
    }

    # No existing session loaded: generate a new one
    unless ($self->metainfo->{id}) {
        # Initialize session metadata with default values
        my $current_time = time();
        $self->metainfo({
            id          => $self->_generate_id,
            ctime       => $current_time,
            atime       => $current_time,
        });
        $self->{status} |= STATUS_NEW;
    }

    $self->log->trace(sprintf(
        'Session initialized: tablename = %s',
        $self->table_name,
    ));
}

=head1 METHODS

=head2 id

Returns the session ID.

=cut

sub id ($self) {
    return $self->metainfo->{id};
}

=head2 param

Get or set session parameters.

    # Get all public parameter names
    my @names = $session->param;

    # Get a single parameter
    my $val = $session->param('key');

    # Set one or more parameters
    $session->param(key => $value);
    $session->param(key1 => $val1, key2 => $val2);

    # Named parameter syntax (CGI.pm-style)
    $session->param(-name => 'key', -value => $value);

=cut

sub param ($self, @args) {
    if ($self->{status} & STATUS_DELETED) {
        carp "param(): attempt to read/write deleted session";
    }

    # No args: return all parameter names
    return keys $self->params->%* if @args == 0;

    # Single arg: get parameter value
    return $self->params->{ $args[0] } if @args == 1;

    # Pairs: $name => $value, ...
    my %h = @args;
    if ((@args % 2) == 0) {
        my $count = 0;
        while (my ($name, $val) = each %h) {
            $self->params->{$name} = $val;
            $count++;
        }
        $self->{status} |= STATUS_MODIFIED;
        return $count;
    }

    croak "param(): usage error. Invalid syntax";
}

=head2 expire

Set or get session/parameter expiration.

    # Get session expiration (seconds), undef if not set
    my $etime = $session->expire;

    # Set session expiration
    $session->expire('1h');
    $session->expire(3600);

    # Set per-parameter expiration
    $session->expire('mykey', '10m');
    $session->expire('mykey', 600);

    # Cancel expiration
    $session->expire(0);

Time values can be plain seconds or use suffixes: C<s> (second), C<m> (minute),
C<h> (hour), C<d> (day), C<w> (week), C<M> (month), C<y> (year).

=cut

sub expire ($self, @args) {
    # No args: return session expiration time
    return $self->metainfo->{etime} if @args == 0;

    # One arg: set session-level expiration
    if (@args == 1) {
        my $time = $args[0];
        if (defined $time && ($time =~ m/^\d$/) && $time == 0) {
            $self->metainfo->{etime} = undef;
        } else {
            $self->metainfo->{etime} = $self->_str2seconds($time);
        }
        $self->{status} |= STATUS_MODIFIED;
        return 1;
    }

    # Two args: per-parameter expiration
    my ($param_name, $time) = @args;
    if (($time =~ m/^\d$/) && $time == 0) {
        delete $self->metainfo->{expire_list}->{$param_name};
    } else {
        $self->metainfo->{expire_list}->{$param_name} = $self->_str2seconds($time);
    }
    $self->{status} |= STATUS_MODIFIED;
    return 1;
}

=head2 flush

Synchronizes in-memory session data with the database.

Should be called before the session object goes out of scope. Handles storing
modified/new sessions and removing deleted sessions.

=cut

sub flush ($self) {
    return unless $self->id;
    return if not defined $self->{status} or $self->{status} == STATUS_UNSET;

    # New + deleted = never persisted, just discard
    if (($self->{status} & STATUS_NEW) && ($self->{status} & STATUS_DELETED)) {
        $self->clear_metainfo;
        $self->clear_params;
        $self->{status} &= ~(STATUS_NEW | STATUS_DELETED);
        return 1;
    }

    # Deleted: remove from database
    if ($self->{status} & STATUS_DELETED) {
        $self->_db_remove;
        $self->clear_metainfo;
        $self->clear_params;
        $self->{status} &= ~STATUS_DELETED;
        return 1;
    }

    # New or modified: serialize and store
    if ($self->{status} & (STATUS_NEW | STATUS_MODIFIED)) {
        $self->_db_store;
        $self->{status} &= ~(STATUS_NEW | STATUS_MODIFIED);
    }

    return 1;
}

=head2 clone

Deletes the current session from the database and returns a new session object
with the same database configuration but a new session ID.

=cut

sub clone ($self) {
    $self->log->debug('Clone frontend session');
    $self->delete;
    $self->flush;
    return ref($self)->new(
        db_params  => $self->db_params,
        table_name => $self->table_name,
        $self->has_encrypt_key ? (encrypt_key => $self->encrypt_key) : (),
        $self->log_ip          ? (log_ip      => $self->log_ip)      : (),
    );
}

=head2 clear

Clears session parameters.

    $session->clear;              # clear all public params
    $session->clear('key');       # clear one parameter
    $session->clear(\@keys);      # clear several parameters

=cut

sub clear ($self, $params = undef) {
    if (defined $params) {
        $params = [$params] unless ref $params;
    } else {
        $params = [ $self->param ];
    }

    delete $self->params->{$_} for @$params;
    $self->{status} |= STATUS_MODIFIED;
}

=head2 delete

Marks the session for deletion. The actual removal from the database happens
on the next call to L</flush>.

=cut

sub delete ($self) {
    $self->{status} |= STATUS_DELETED;
}

#
# Session ID generation
# Generate a new session ID using MD5 (compatible with CGI::Session::ID::md5)
#

sub _generate_id ($self) {
    my $md5 = Digest::MD5->new;
    $md5->add($$, time(), rand(time));
    return $md5->hexdigest;
}


#
# Serialization
#

sub _freeze ($self, $data) {
    my $d = Data::Dumper->new([$data], ['D']);
    $d->Indent(0);
    $d->Purity(1);
    $d->Useqq(0);
    $d->Deepcopy(0);
    $d->Quotekeys(1);
    $d->Terse(0);
    return $d->Dump() . ';$D';
}

sub _thaw ($self, $string) {
    my ($safe_string) = $string =~ m/^(.*)$/s;
    my $rv = Safe->new->reval($safe_string);
    die "Couldn't deserialize session data: $@" if $@;
    # Re-bless objects from Safe compartment to fix package namespaces
    _rebless_from_safe($rv);
    return $rv;
}

# Walk a data structure and re-bless any objects that came from a Safe
# compartment (their packages would otherwise point into Safe's namespace).
# Uses old-style subs to preserve @_ aliasing semantics needed for in-place
# modification of overloaded blessed references.
sub _rebless_from_safe {
    my %seen;
    my @queue = _rebless_values(shift);
    while (@queue) {
        defined(my $x = shift @queue) or next;
        $seen{ refaddr($x) || '' }++ and next;
        my $r = reftype($x) or next;
        if    ($r eq 'HASH')                  { push @queue, _rebless_values(@{$x}{keys %$x}) }
        elsif ($r eq 'ARRAY')                 { push @queue, _rebless_values(@$x) }
        elsif ($r eq 'SCALAR' || $r eq 'REF') { push @queue, _rebless_values($$x) }
    }
}

sub _rebless_values {
    for (@_) {
        next unless blessed $_;
        if (overload::Overloaded($_)) {
            my $rt = reftype $_;
            if    ($rt eq 'HASH')                   { $_ = bless { %$_ }, ref $_ }
            elsif ($rt eq 'ARRAY')                  { $_ = bless [ @$_ ], ref $_ }
            elsif ($rt eq 'SCALAR' || $rt eq 'REF') { $_ = bless \do { my $o = $$_ }, ref $_ }
        } else {
            bless $_, ref $_;
        }
    }
    return @_;
}


#
# Time parsing
#

# Convert time strings like "1h", "30m" to seconds.
# Accepts plain integers, or integers with suffix: s m h d w M y
sub _str2seconds ($self, $str) {
    return unless defined $str;
    return $str if $str =~ m/^[-+]?\d+$/;

    my %map = (s => 1, m => 60, h => 3600, d => 86400, w => 604800, M => 2592000, y => 31536000);
    my ($koef, $unit) = $str =~ m/^([+-]?\d+)([smhdwMy])$/;
    die "_str2seconds(): couldn't parse '$str'" unless defined $koef && defined $unit;
    return $koef * $map{$unit};
}


#
# Database operations
#

# HMAC-hash the session ID when an encryption key is configured
sub _hash_sid ($self, $sid) {
    return $self->has_encrypt_key
        ? hmac_sha256_hex($sid, $self->encrypt_key)
        : $sid;
}

# Load existing session data from database
sub _db_load ($self, $sid) {
    my $hashed_sid = $self->_hash_sid($sid);

    my $datastr = $self->db->select_value(
        from    => $self->table_name,
        columns => ['data'],
        where   => { session_id => $hashed_sid },
    );

    unless ($datastr) {
        $self->log->debug("Frontend session was empty: $hashed_sid") if defined $datastr;
        return;
    }

    # Decrypt if an encryption key is configured
    $datastr = $self->crypt->decrypt(decode_base64($datastr)) if $self->crypt;

    $self->log->trace("data = $datastr") if $self->log->is_trace;

    my $data = $self->_thaw($datastr);
    unless (ref $data eq 'HASH') {
        $self->log->warn("Session data is not a hash: $hashed_sid");
        return;
    }
    unless (($data->{metainfo}//{})->{id}) {
        $self->log->warn("Session data does not contain metainfo: $hashed_sid");
        return;
    }

    my $meta = $data->{metainfo};

    # Check session-level expiration
    if ($meta->{etime} && ($meta->{atime} + $meta->{etime}) <= time()) {
        $self->db->delete_and_commit(
            from  => $self->table_name,
            where => { session_id => $hashed_sid },
        );
        $self->log->debug("Frontend session expired and removed: $hashed_sid");
        return;
    }

    # Check per-parameter expiration
    if (my $elist = $meta->{expire_list}) {
        my @expired = grep { ($meta->{atime} + $elist->{$_}) <= time() } keys %$elist;
        if (@expired) {
            delete $data->{params}->{$_} for @expired;
            delete $elist->{$_} for @expired;
        }
    }

    # Update access time
    $meta->{atime} = time();
    $self->{status} |= STATUS_MODIFIED; # access time was updated

    # Populate session attributes
    $self->metainfo($data->{metainfo});
    $self->params($data->{params});

    $self->log->debug("Frontend session retrieved: $hashed_sid");
}

# Store serialized session data to database
sub _db_store ($self) {
    $self->log->trace("Store frontend session data") if $self->log->is_trace;

    my $hashed_sid = $self->_hash_sid($self->id);

    my $datastr = $self->_freeze({
        metainfo => $self->metainfo,
        params => $self->params,
    });
    # Encrypt if configured
    $datastr = encode_base64($self->crypt->encrypt($datastr)) if $self->crypt;

    my $ip = ($self->log_ip && $ENV{REMOTE_ADDR}) ? $ENV{REMOTE_ADDR} : '';
    my $now = time();

    $self->db->merge_and_commit(
        into => $self->table_name,
        set => {
            data       => $datastr,
            modified   => $now,
            ip_address => $ip,
        },
        set_once => {
            created => $now,
        },
        where => {
            session_id => $hashed_sid,
        },
    );

    $self->log->debug("Frontend session stored: $hashed_sid");
}

# Remove session from database
sub _db_remove ($self) {
    my $hashed_sid = $self->_hash_sid($self->id);

    $self->db->delete_and_commit(
        from  => $self->table_name,
        where => { session_id => $hashed_sid },
    );
    $self->log->debug("Frontend session removed: $hashed_sid");
}

__PACKAGE__->meta->make_immutable;

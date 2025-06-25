package CGI::Session::Driver::openxpki;
use OpenXPKI -base => 'CGI::Session::Driver::DBI';

# Core modules
use MIME::Base64;
use Digest::SHA qw(hmac_sha256_hex);

# CPAN modules
use Log::Log4perl qw(:easy);
use Log::Log4perl::MDC;
use Crypt::CBC;

=head1 NAME

CGI::Session::Driver::openxpki - C<CGI:Session> driver using DBI for openxpki

=head1 DESCRIPTION

Store OpenXPKI frontend session data in an SQL database.

It is based on L<CGI::Session::Driver::DBI> but uses fixed/additional column
names and adds some security options.

=head2 SQL Schema

    CREATE TABLE IF NOT EXISTS `frontend_session` (
      `session_id` varchar(255) NOT NULL PRIMARY KEY,
      `data` longtext,
      `created` int(10) unsigned NOT NULL,
      `modified` int(10) unsigned NOT NULL,
      `ip_address` varchar(45) DEFAULT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE utf8mb4_general_ci;

=head2 Config Options

    session:
        driver: driver:openxpki

        params:
            DataSource: dbi:mysql:dbname=openxpki;host=db.example.com
            NameSpace: openxpki
            User: openxpki_session
            Password: mypass
            EncryptKey: mysecretkey
            LogIP: 1

=over

=item NameSpace

The I<TableName> options is set to the fixed value C<"frontend_session">.
In case you have a RDBMS that requires namespaces, e.g. Oracle, you can pass an
additional I<NameSpace> which is prefixed to the tablename.

=item EncryptKey

This is an optional parameter that adds some extra security against
attackers or curious server/database admins.

The data portion of the session is encrypted with AES using this
value as secret key. This prevents database admins (or intruders) from
reading or manipulating session data.

In additon, the session ID passed to the access methods is hashed with an
HMAC function using this key to prevent users from stealing sessions if they
are able to traverse through the session table.

=item LogIP

Boolean, default is C<0>. If set to C<1> the environment variable C<REMOTE_ADDR>
is logged into the C<ip_address> column. This is mainly meant for debugging or
monitoring and not used for the session handling itself.

=back

For other database related parameters, see L<CGI::Session::Driver::DBI>.

=head2 Connection handling

The database connection is opened upon first use, e.g. a call to L</store>,
L</retrieve> or L</remove>. It is closed in L</store>.

This is more reliable than only using the C<DESTROY> method to close the
connection (like L<CGI::Session::Driver::DBI> does) because the DBI object might
have already been destroyed then. L</store> is only called via
L<CGI::Session-E<gt>flush()|CGI::Session/flush> which should be used as a final
action like the deprecated C<CGI::Session-E<gt>close()>.

If another call to L</store>, L</retrieve> or L</remove> is made after the
connection was closed then a new connection will be opened.

=head1 METHODS

=head2 init

Driver setup, called by L<C<CGI::Session-E<gt>load()>|CGI::Session/load> via
L<C<CGI::Session::Driver::DBI-E<gt>new()>|CGI::Session::Driver::DBI/new>.

=cut
sub init ($self) {
    Log::Log4perl->initialized or Log::Log4perl->easy_init($ERROR);

    $self->{IdColName} = 'session_id';
    $self->{DataColName} = 'data';
    $self->{TableName} = join '.', $self->{NameSpace}//(), 'frontend_session';
    $self->{_crypt} = Crypt::CBC->new(
        -key => $self->{EncryptKey},
        -cipher => 'Crypt::OpenSSL::AES',
        -nodeprecate => 1,
    ) if $self->{EncryptKey};

    $self->log->trace('Frontend session driver initialized');
    return 1;
}

=head2 get_handle

Returns a L<DBI> database handle. Connects to the database upon first call.

=cut
sub get_handle ($self) {
    if (not $self->{Handle})  {
        my $dbi = DBI->connect(
            $self->{DataSource}, $self->{User}, $self->{Password},
            {
                PrintError => 1,
                AutoCommit => 1,
                # LongReadLen for Oracle
                LongReadLen => $self->{LongReadLen} ? $self->{LongReadLen} : 100000,
            }
        );
        if ($dbi) {
            $self->{Handle} = $dbi;
        } else {
            $self->set_error("Couldn't connect to database: " . DBI->errstr);
        }
    }
    return $self->{Handle};
}

=head2 log

Returns a L<Log::Log4perl::Logger> instance.

=cut
sub log ($self) {
    $self->{_logger} = Log::Log4perl->get_logger('openxpki.client.service.webui.session')
        unless $self->{_logger};
    return $self->{_logger};
}

=head2 retrieve

Retrieve serialized session data I<Str> associated with the given ID.

Called by L<C<CGI::Session-E<gt>load()>|CGI::Session/load>.

B<Parameters:>

=over

=item * B<$sid> I<Str> - session ID

=back

=cut
sub retrieve ($self, $sid) {
    $self->get_handle or return;

    $sid = hmac_sha256_hex($sid, $self->{EncryptKey}) if $self->{EncryptKey};
    my $datastr = $self->SUPER::retrieve($sid);

    if (not $datastr) {
        return if not defined $datastr; # pass through undef = error
        $self->log->debug("Frontend session was empty: $sid");
        return '';
    }

    $self->log->debug("Frontend session retrieved: $sid");

    if ($self->{_crypt}) {
        $datastr = $self->{_crypt}->decrypt( decode_base64($datastr) );
    }

    $self->log->trace("data = $datastr") if $self->log->is_trace;

    return $datastr;
}

=head2 store

Store data into database and close connection (see L</Connection handling>).

Called by L<C<CGI::Session-E<gt>flush()>|CGI::Session/flush> if the session was
modified.


B<Parameters:>

=over

=item * B<$sid> I<Str> - session ID

=item * B<$datastr> I<Str> - serialized session data

=item * B<$etime> I<Int> - optional: time

=back

=cut
sub store ($self, $sid, $datastr, $etime = undef) {
    $self->log->trace("Store frontend session data = $datastr") if $self->log->is_trace;
    my $dbh = $self->get_handle or return;

    $datastr = encode_base64($self->{_crypt}->encrypt($datastr)) if $self->{_crypt};
    $sid = hmac_sha256_hex($sid, $self->{EncryptKey}) if $self->{EncryptKey};

    my $sth = $dbh->prepare_cached("SELECT ".$self->{IdColName}." FROM ".$self->{TableName}." WHERE ".$self->{IdColName}." = ?", undef, 3);
    unless ( defined $sth ) {
        return $self->set_error( 'store() - $dbh->prepare_cached failed: ' . $sth->errstr );
    }

    $sth->execute( $sid )
      or return $self->set_error( 'store() - $sth->execute failed: ' . $sth->errstr );

    my $rc = $sth->fetchrow_array;
    $sth->finish;

    my $action_sth;
    my @args = ($datastr, time(), (($self->{LogIP} && $ENV{REMOTE_ADDR}) ? $ENV{REMOTE_ADDR} : ''), $sid);

    if ( $rc ) {
        $action_sth = $dbh->prepare_cached(
            sprintf(
                "UPDATE %s SET %s = ?, modified = ?, ip_address = ? WHERE %s = ?",
                $self->{TableName}, $self->{DataColName}, $self->{IdColName}
            ),
            undef, 3
        );
        $self->log->debug("Frontend session updated: $sid");
    } else {
        push @args, time();
        $action_sth = $dbh->prepare_cached(
            sprintf(
                "INSERT INTO %s (%s, modified, ip_address, %s, created) VALUES(?, ?, ?, ?, ?)",
                $self->{TableName}, $self->{DataColName}, $self->{IdColName},
            ),
            undef, 3
        );
        $self->log->debug("Frontend session created: $sid");
    }
    unless ( defined $action_sth ) {
        return $self->set_error( 'store() - $dbh->prepare failed: ' . $dbh->errstr );
    }

    $action_sth->execute(@args)
        or return $self->set_error( 'store() - $action_sth->execute failed: ' . $action_sth->errstr );

    $action_sth->finish;

    $self->{Handle}->disconnect;
    $self->{Handle} = undef;

    return 1;
}

=head2 remove

Remove session data associated with the given ID.

Called by L<C<CGI::Session-E<gt>flush()>|CGI::Session/flush> if
L<C<CGI::Session-E<gt>delete()>|CGI::Session/delete> was called before.

B<Parameters:>

=over

=item * B<$sid> I<Str> - session ID

=back

=cut
sub remove ($self, $sid) {
    $self->log->debug("Frontend session removal: $sid");
    $self->get_handle or return;
    $sid = hmac_sha256_hex( $sid, $self->{EncryptKey}) if $self->{EncryptKey};
    return $self->SUPER::remove($sid);
}

=head2 dump

No-op (returns 1).

=cut
sub dump { 1 }

=head2 traverse

Not implemented (throws an error).

=cut
sub traverse ($self, @args) {
    die "traverse() is not supported";
}

=head2 set_error

Logs the given error string and calls L<CGI::Session::Driver/set_error>.

=cut
sub set_error ($self, $error = '') {
    $self->log->error($error);
    return $self->SUPER::set_error($error);
}

sub DESTROY ($self) {
    eval { $self->{Handle}->disconnect if $self->{Handle} };
}

1;

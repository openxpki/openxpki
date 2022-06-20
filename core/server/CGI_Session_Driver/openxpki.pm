package CGI::Session::Driver::openxpki;

use English;
use warnings;
use Log::Log4perl qw(:easy);
use Log::Log4perl::MDC;
use Data::Dumper;
use MIME::Base64;
use Crypt::CBC;
use Digest::SHA qw(hmac_sha256_hex);
use base 'CGI::Session::Driver::DBI';

sub init {

    my $self = shift;

    Log::Log4perl->initialized() || Log::Log4perl->easy_init($ERROR);

    $self->{IdColName} = 'session_id';
    $self->{DataColName} = 'data';

    if ($self->{NameSpace}) {
        $self->{TableName} = $self->{NameSpace} . '.frontend_session';
    } else {
         $self->{TableName} = 'frontend_session';
    }

    if ($self->{EncryptKey}) {
        $self->{_crypt} = Crypt::CBC->new(
            -key => $self->{EncryptKey},
            -cipher => 'Crypt::OpenSSL::AES',
            -nodeprecate => 1,
        );
    }

    Log::Log4perl->get_logger('session')->trace('Session driver initalized');

    if (! defined $self->{Handle} )  {
        # copy from CGI::S::D::DBI as we need to add LongReadLen for Oracle
        $self->{Handle} = DBI->connect(
            $self->{DataSource}, $self->{User}, $self->{Password}, {
                RaiseError=>1, PrintError=>1, AutoCommit=>1,
                LongReadLen => $self->{LongReadLen} ?  $self->{LongReadLen} : 100000
            }
        );
        unless ( $self->{Handle} ) {
            return $self->set_error( "init(): couldn't connect to database: " . DBI->errstr );
        }
        $self->{_disconnect} = 1;
    }
    return 1;


    return $self->SUPER::init();
}

sub retrieve {

    my $self = shift;
    my $sid = shift;

    my $log = Log::Log4perl->get_logger('session');

    if ($self->{EncryptKey}) {
        $sid = hmac_sha256_hex( $sid, $self->{EncryptKey});
    }

    my $datastr = $self->SUPER::retrieve($sid);

    if (!$datastr) {
        $log->debug("Session retrieve $sid (was empty)");
        return '';
    }

    $log->debug("Session retrieve $sid");

    if ($self->{_crypt}) {
        $datastr = $self->{_crypt}->decrypt( decode_base64($datastr) );
    }

    $log->trace($datastr) if ($log->is_trace);

    return $datastr;
}

sub store {

    my $self = shift;
    my ($sid, $datastr) = @_;

    my $log = Log::Log4perl->get_logger('session');

    $log->trace($datastr) if ($log->is_trace);

    if (!($sid && $datastr)) {
        die "Session store without data/sid";
    }

    if ($self->{_crypt}) {
        $datastr = encode_base64( $self->{_crypt}->encrypt($datastr) );
    }

    if ($self->{EncryptKey}) {
        $sid = hmac_sha256_hex( $sid, $self->{EncryptKey});
    }

    my $dbh = $self->{Handle};
    my $sth = $dbh->prepare_cached("SELECT ".$self->{IdColName}." FROM ".$self->{TableName}." WHERE ".$self->{IdColName}." = ?", undef, 3);
    unless ( defined $sth ) {
        return $self->set_error( "store(): \$dbh->prepare failed with message " . $sth->errstr );
    }

    $sth->execute( $sid ) or return $self->set_error( "store(): \$sth->execute failed with message " . $sth->errstr );
    my $rc = $sth->fetchrow_array;
    $sth->finish;

    my $action_sth;
    my @args = ($datastr, time(), (($self->{LogIP} && $ENV{REMOTE_ADDR}) ? $ENV{REMOTE_ADDR} : ''), $sid);

    if ( $rc ) {
        $action_sth = $dbh->prepare_cached("UPDATE ".$self->{TableName}." SET ".$self->{DataColName}." = ?, modified = ?, ip_address = ? WHERE ".$self->{IdColName}." = ?", undef, 3);
        $log->debug("Session store $sid (update)");
    } else {
        $action_sth = $dbh->prepare_cached("INSERT INTO ".$self->{TableName}." (".$self->{DataColName}.", modified,  ip_address, ".$self->{IdColName}.", created) VALUES(?, ?, ?, ?, ?)", undef, 3);
        $log->debug("Session store $sid (create)");
        push @args, time();
    }

    unless ( defined $action_sth ) {
        return $self->set_error( "store(): \$dbh->prepare failed with message " . $dbh->errstr );
    }
    $action_sth->execute(@args)
        or return $self->set_error( "store(): \$action_sth->execute failed " . $action_sth->errstr );

    $action_sth->finish;

    return 1;
}

sub remove {

    my $self = shift;
    my $sid = shift;

    if ($self->{EncryptKey}) {
        $sid = hmac_sha256_hex( $sid, $self->{EncryptKey});
    }

    return $self->SUPER::remove($sid);

}

sub dump { 1 }

sub traverse {
    my $self = shift;
    die "traverse() is not supported";
}

sub set_error {

    my $self = shift;
    my $error = shift;

    Log::Log4perl->get_logger('session')->error($error);
    $self->SUPER::set_error();

    die $error;

}

1;

__END__;

=head1 NAME

CGI::Session::Driver::openxpki - CGI:Session driver using DBI for openxpki

=head1 DESCRIPTION

Stores OpenXPKI frontend session data in a SQL database.

It is based on CGI::Session::Driver::DBI but uses fixed/additional columns
names and adds some security options.

=head2 SQL Schema

    CREATE TABLE IF NOT EXISTS `frontend_session` (
      `session_id` varchar(255) NOT NULL PRIMARY KEY,
      `data` longtext,
      `created` int(10) unsigned NOT NULL,
      `modified` int(10) unsigned NOT NULL,
      `ip_address` varchar(45) DEFAULT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

=head2 Config Options

    [session]
    driver = driver:openxpki

    [session_driver]
    DataSource = dbi:mysql:dbname=openxpki
    NameSpace = oxischema
    User = openxpki_session
    Password = openxpki
    EncryptKey = SessionEncryptionSecret
    LogIP = 1

=over

=item NameSpace

The used TableName is set to the fixed value "frontend_session". In case
you have a RDBMS that requires namespaces, e.g. Oracle, you can pass an
additional NameSpace which is prefixed to the tablename.

=item EncryptKey

This is an optional parameter that adds some extra security against
attackers or curious server/database admins.

The data portion of the session is encrypted with AES using this
value as secret key. This prevents database admins (or intruders) from
reading or even manipulation session data.

In additon, the session id retrieved from the frontend is hashed with an
HMAC function using this key to prevent users from stealing sessions if they
are able to traverse through the session table.

=item LogIP

Boolean, default is off. If set the IP is logged into an extra field in the
tables. This is meant mainly for debugging/monitoring and not used for the
session handling itself.

=back

For all database related paramaters, @see CGI::Session::Driver::DBI


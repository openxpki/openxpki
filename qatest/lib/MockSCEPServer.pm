# MockSCEPServer
#
# USAGE:
#
# Write a Mojolicious::Lite script like the following:
#
#   #!/usr/bin/env perl
#   use Mojolicious::Lite;
#
#   use lib 'lib';
#   use MockSCEPServer;
#
#   helper scepd => sub { state $scepd = MockSCEPServer->new( config => $config };
#
#   get '/scep' => sub {
#       my $self = shift;
#
#       $self->scepd->handle();
#   }
#
#   app->start;

package MockSCEPServer;
use Moose;

use File::Temp();
use MIME::Base64;

use OpenXPKI::Test::CertHelper;

has 'config' => (is => 'rw');

my %pki_ops = (
    GetCACert => sub {
        my $self = shift;
        my $mojo = shift;

        $mojo->res->headers->content_type('application/x-x509-ca-cert');
        $mojo->res->content->asset(
            Mojo::Asset::File->new( path => $self->config->{crt_der} ) );
        $mojo->rendered(200);
        return $mojo;
    },
    PKIOperation => sub {
        my $self = shift;
        my $mojo = shift;
        my $msg  = shift;

        my $fhin  = File::Temp->new( UNLINK => 0 );
        my $fhout = File::Temp->new( UNLINK => 0 );
        my $msgfname = $fhin->filename;

        my $der = $msg;
        $der =~ s/%([0-9a-f]{2})/sprintf("%s",pack("H2",$1))/eig;
        $der = MIME::Base64::decode($der);

        print $fhin $der;
        close $fhin;
        close $fhout;

        $ENV{SCEP_PASS} ||= $self->config->{pass};

        my @cmd = (
            'openca-scep', '-new',           '-passin',  'env:SCEP_PASS',
            '-signcert',   $self->config->{crt_pem},  '-msgtype', 'CertRep',
            '-status',     'PENDING',        '-keyfile', $self->config->{key_der},
            '-inform',     'DER',            '-in',      $fhin->filename,
            '-out',        $fhout->filename, '-outform', 'DER',
        );

        $mojo->app->log->debug( '  exec: ' . join( ', ', @cmd ) ) if $self->verbose;
        my $rc = system(@cmd);
        $rc >>= 8;
        if ( $rc == 0 ) {
            $mojo->res->headers->content_type('application/x-pki-message');
            $mojo->res->content->asset(
                Mojo::Asset::File->new( path => $fhout->filename ) );

        #        unlink $fhin->filename;
        #        unlink $fhout->filename;
            $mojo->rendered(200);
            return $mojo;
        } else {
            die "Error running: ", join(', ', @cmd);
        }
    },
);



sub handle {
    my $self = shift;
    my $mojo = shift;
    my $config = $self->config;

    my @names = $mojo->param;

    my $message   = $mojo->param('message');
    my $operation = $mojo->param('operation');

    if ( my $opsub = $pki_ops{$operation} ) {
        return $opsub->( $self, $mojo, $message );
    }
    else {
        $mojo->render(
            text => "ERROR: pki operation '$operation' not supported" );
    }
};

sub BUILD {
    my $self = shift;
    my $config = $self->config;

    if ( not $config ) {
        die "MockSCEPServer - no config";
        $self->config( $config = {} );
    }
    $config->{basedir} ||= 'mock-scep-server.d';
    $config->{opensslcnf} ||= $config->{basedir} . '/openssl.cnf';
    $config->{key_der} ||= $config->{basedir} . '/key.der';
    $config->{crt_der} ||= $config->{basedir} . '/crt.der';
    $config->{crt_pem} ||= $config->{basedir} . '/crt.pem';

    OpenXPKI::Test::CertHelper->via_openssl(
        basedir    => $config->{basedir},
        commonName => 'scepserver.test.openxpki.org',
        password => 'my-scep-server-passphrase',
        verbose => 1,
    );
}



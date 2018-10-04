package MockSC;
use Moose;
use JSON;
use CGIMock;
use CGI::Session;
use Config::Std;
use Data::Dumper;
use English;
use MIME::Base64;
use OpenXPKI::Client::SC;
use Log::Log4perl qw(:easy);

has 'session' => (
    is => 'rw',
    isa => 'Object|HashRef',
    default => sub { return new CGI::Session(undef, undef, {Directory=>'/tmp'}); }
);

has 'client' => (
    is => 'rw',
    isa => 'Object',
    lazy => 1,
    builder => '_init_client'
);

has 'defaults' => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { return {}; }    
);

has 'persist' => (
    is => 'rw',
    isa => 'Int',    
    default => 0
);

sub _init_client {

    my $self = shift;
    
    my $configfile = '/etc/openxpki/sc/default.conf';
    read_config $configfile => my %config;
    my %card_config = %config;

    Log::Log4perl->init('/etc/openxpki/sc/log.conf');

    return OpenXPKI::Client::SC->new({
        session => $self->session(),
        config => { socket => '/var/openxpki/openxpki.socket' },
        card_config => \%card_config,
        auth => { stack => '_SmartCard' }
    });
    
}

sub mock_request {
    
    my $self = shift;
    
    my $class = shift;
    my $method = shift;
    my $data = shift || {};
    
    my $cgi = CGIMock->new({ 
        data => { %{$data}, %{$self->defaults()} },
        url_data => { 
            '_class' => $class,
            '_method' => $method
        }
    });
    
    my $result = $self->client()->handle_request({ cgi => $cgi });
    
    if (!$self->persist()) {
        $self->client()->disconnect();
    }
    
    my $out;
    $result->render( \$out );
    return JSON->new->decode($out); 
    
}


sub session_decrypt {
    
    my $self  = shift;
    my $enc = shift;
       
    if (!$enc) { return ''; }
        
    my $session = $self->session();
    
    if (!$session->param('aeskey')) {
        die "No session secret defined!";
    }
    
    my $data;
    eval{
        my $cipher = Crypt::CBC->new( -key => pack('H*', $session->param('aeskey')),
            -cipher => 'Crypt::OpenSSL::AES' );
            
         $data = $cipher->decrypt( decode_base64($enc) );
            
    };
    
    if($EVAL_ERROR || !$data) {
        die "Unable to do decryption!";            
    }
    
    return $data;
    
}


1;
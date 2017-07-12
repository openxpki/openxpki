
package OpenXPKI::Client::SC;

use Moose;

use English;
use Data::Dumper;

extends 'OpenXPKI::Client::Simple';

has 'card_config' => (
    required => 1,
    is => 'ro',
    isa => 'HashRef',
);

sub handle_request {

    my $self = shift;
    my $args = shift;
    my $cgi = $args->{cgi};

    my %extra;
    my ($class) = ( $cgi->url_param('_class') =~ /([a-zA-Z0-9\_]+)/ );
    my ($method) = ( $cgi->url_param('_method') =~ /([a-zA-Z0-9\_]+)/ );

    if (!$class || !$method) {
        die "You need to pass _class and _method!";
    }

    my $log = $self->logger();
    $log->trace("Loading handler class $class, method $method, extra params " . Dumper \%extra );

    $class = 'OpenXPKI::Client::SC::'.ucfirst($class);
    $method = 'handle_' . $method;

    eval "use $class;1";
    if ($EVAL_ERROR) {
        $log->error("Failed loading action class $class");
        die "Failed loading action class $class";
    }

    my $result;

    $log->debug("Method is $method");
    eval {
        $result = $class->new({
            client => $self,
            cgi => $cgi,
            config =>  $self->card_config(),
            extra => \%extra
        });
        $result->$method( );
        $log->trace( Dumper $result );
    };
    if ($EVAL_ERROR) {
        $log->error("Execution of $class->$method failed!");
    }
    $log->debug('request handled');

    return $result;

}

1;
##########################################################
############## Mason server config #######################
##########################################################
package OpenXPKI::Client::HTML::Mason::Test::Server;
use base qw/Test::HTTP::Server::Simple HTTP::Server::Simple::Mason/;
use File::Spec;

sub mason_config {
    $ENV{'OPENXPKI_SOCKET_FILE'} = 't/20_webserver/test_instance/var/openxpki/openxpki.socket';
    return (
        comp_root => File::Spec->rel2abs('./htdocs'),
        allow_globals => [ qw( $context %session_cache ) ],
    );
}

1;

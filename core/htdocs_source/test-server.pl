#!/usr/bin/env perl
use Mojolicious::Lite -signatures;

# This is a test server accessed by the [Local request - ...] button on
# http://localhost:4200/openxpki/#/test
#
# It must be run on the same host where the browser runs.
#
# Start it with
#   morbo -l http://*:7780 ./test-server.pl
# or
#   ./test-server.pl daemon -l http://*:7780

get '/*therest' => sub ($c) {
    $c->render(json => { answer => 'Hello World!', the_rest => $c->param('therest') });
};

# Remove a default header
hook after_dispatch => sub ($c) {
    $c->res->headers->add('Access-Control-Allow-Origin' => '*');
};

app->start;

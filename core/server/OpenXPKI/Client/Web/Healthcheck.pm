package OpenXPKI::Client::Web::Healthcheck;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# CPAN modules
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init($FATAL);


my @allowed_commands = qw( showenv );

# do NOT expose this unless you are in a test environment
# set directly from here, e.g. for testing
# push @allowed_commands ,'showenv';
# set from ENV via apache
@allowed_commands = split /\W+/, $ENV{OPENXPKI_HEALTHCHECK} if ($ENV{OPENXPKI_HEALTHCHECK});

my $commands = {
    showenv => sub($c) {
        return $c->render(json => \%ENV);
    },
    ping => sub ($c) {
        my $client = $c->oxi_client;
        if (!$client) {
            ERROR("ping failed");
            return $c->render(json => { ping => 0 }, status => 500);
        } else {
            TRACE("ping ok");
            return $c->render(json => { ping => 1 });
        }
    },
};

sub index ($self) {
    my $command = $self->param('command');

    return $commands->{ping}($self) if 'ping' eq $command;

    if (List::Util::any { $command eq $_ } @allowed_commands) {
        if (my $sub = $commands->{$command}) {
            return $sub->($self);
        }
        else {
            return $self->render(text => "Method unsupported\n", status => 404);
        }
    }

    return $self->render(text => "Method unsupported or not allowed\n", status => 404);

}

1;

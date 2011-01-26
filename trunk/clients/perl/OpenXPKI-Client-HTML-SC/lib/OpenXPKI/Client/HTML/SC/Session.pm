package OpenXPKI::Client::HTML::SC::Session;

use strict;
use warnings;

use base qw( Apache2::Controller::Session::Cookie );

use English '-no_match_vars';
use Apache2::Controller::X;

my $session;    #nothing here

#sub new {
#	my ($self) = @_;
#my $sessid = $self->get_session_id();
# print($sessid);

#}
#sub get_options {
#     my ($self) = @_;
#
#      my $r = $self->{r};
#      eval {
#          $r->pnotes->{a2c}{dbh} ||= DBI->connect(
#              'dbi:mysql:database=myapp;host=mydbhost';
#              'myuser', 'mypassword'
#          );
#      };
#      a2cx "cannot connect to DB: $EVAL_ERROR" if $EVAL_ERROR;
#
#      my $dbh = $r->pnotes->{a2c}{dbh};    # save handle for later use
# in controllers, etc.

#     return {
#        Directory      => "/tmp/sessionsscb",
#        LockDirectory  => "/var/lock/sessionsscb",
#     };
# }

# sub get_options {
#     my ($self) = @_;
#
#     my $opts = $self->get_directive('A2C_Session_Opts');
#
#     if (!$opts) {
#         my $hostname = $self->{r}->hostname();
#         my $tmp = File::Spec->tmpdir();
#         my $dir = File::Spec->catfile($tmp, 'A2C', $hostname);
#         my $sess = File::Spec->catfile($dir, 'sess');
#         my $lock = File::Spec->catfile($dir, 'lock');
#
#         if (!exists $created_temp_dirs{$hostname}) {
#             do { mkdir || a2cx "Cannot create $_: $OS_ERROR" }
#                 for grep !-d, $dir, $sess, $lock;
#             $created_temp_dirs{$hostname} = 1;
#         }
#
#
#         };
#     }
#     $opts = {
#             Directory       => "/tmp/SCSession/a"
#             LockDirectory   => "/var/lock/SCSession/a",
#
#     DEBUG "returning session opts:\n".Dump($opts);
#     return $opts;
# }

1;

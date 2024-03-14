package OpenXPKI;
use strict;
use warnings;

use OpenXPKI::VERSION;
our $VERSION = $OpenXPKI::VERSION::VERSION;

use Import::Into;

=head1 NAME

OpenXPKI - Base module to reduce boilerlate code in our packages.

=head1 SYNOPSIS

    use OpenXPKI;

    #
    # is equivalent to:
    #

    use strict;
    use warnings;
    use utf8; # allows for UTF-8 characters within the source code
    use English;

    # Language features
    use feature "current_sub";
    use feature "isa";
    use feature "say";
    use feature "signatures";
    use feature "state";
    no feature "indirect";
    no feature "multidimensional";
    no feature "bareword_filehandles";

    # Core modules
    use Data::Dumper;
    use Scalar::Util "blessed";

    # CPAN modules
    use Type::Params "signature_for";
    use Feature::Compat::Try;

=cut

sub import {
    my $self = shift;

    # import required modules and pragmas into the calling package

    # pragmas
    strict->import::into(1);
    warnings->import::into(1);
    utf8->import::into(1);
    English->import::into(1);

    # Enable language features: use feature qw( ... )
    feature->import::into(1, qw(
        current_sub
        isa
        say
        signatures
        state
    ));

    # Disable language features: no feature qw( ... )
    feature->unimport::out_of(1, qw(
        indirect
        multidimensional
        bareword_filehandles
    ));

    # Core modules
    Data::Dumper->import::into(1);
    Scalar::Util->import::into(1, qw( blessed ));

    # CPAN modules
    Type::Params->import::into(1, qw( signature_for ));

    # Disable "experimental" warnings: should be done after other imports to safely disable warnings in Perl < 5.36
    warnings->unimport::out_of(1, qw(
        experimental::isa
        experimental::signatures
    ));

    # try {...} catch ($e) {...} - should be done after other imports to safely disable warnings
    Feature::Compat::Try->import::into(1); # use Feature::Compat::Try

}

=head1 DESCRIPTION

This class only defines an C<import> method which uses L<Import::Into> to
import various pragmas and modules into the calling package.

=head2 use feature "current_sub"

Provides the C<__SUB__> token that returns a reference to the current subroutine
or undef outside of a subroutine.

=head2 use feature "isa"

New C<isa> infix operator:

    if ($o isa 'OpenXPKI::Exception') {
        ...
    }

Also see L<https://perldoc.perl.org/feature#The-'isa'-feature>.

=head2 use feature "say"

New function C<say> which behaves like C<print> with a trailing newline:

    say "Yay";

Also see L<https://perldoc.perl.org/feature#The-'say'-feature>.

=head2 use feature "signatures"

Enables subroutine signatures:

    sub message ($self, $a, $b) {
        ...
    }

Also see L<https://perldoc.perl.org/feature#The-'signatures'-feature>.

=head2 use feature "state"

New C<state> keyword:

    sub do_things {
        # will be set on first call to do_things() and preserved
        state $log = Log::Log4perl->get_logger();
        ...
    }

Also see L<https://perldoc.perl.org/feature#The-'state'-feature>.

=head2 no feature "indirect"

Disable indirect object syntax:

    use OpenXPKI::Server::Session;

    my $sess = OpenXPKI::Server::Session->new; # ok
    my $sess = new OpenXPKI::Server::Session;  # dies

Also see L<https://perldoc.perl.org/feature#The-'indirect'-feature>.

=head2 no feature "multidimensional"

Disable auto conversion of e.g. C<$foo{$x, $y}> into C<$foo{join($;, $x, $y)}>
(this was a Perl 4 feature).

Also see L<https://perldoc.perl.org/feature#The-'multidimensional'-feature>.

=head2 no feature "bareword_filehandles"

Disable bareword filehandles for builtin functions operations:

    open my $fh, '>', $file; # ok
    open FH, '>', $file;     # dies

Also see L<https://perldoc.perl.org/feature#The-'bareword_filehandles'-feature>.

=head2 use Data::Dumper

Provides the C<Dumper> function:

    $self->log->trace(Dumper $obj) if $self->log->is_trace;

=head2 use Scalar::Util "blessed"

Provides the C<blessed> function:

    if (blessed $result) {
        ...
    }

=head2 use Type::Params "signature_for"

Provides the C<signature_for> function:

    signature_for merge => (
        method => 1,
        named => [
            into     => 'Str',
            set      => 'HashRef',
            set_once => 'Optional[ HashRef ]', { default => {} },
            where    => 'HashRef[Value]',
        ],
    );
    sub merge ($self, $arg) {
        if ($arg->set_once) ...
    }

Also see L<https://metacpan.org/pod/Type::Params#signature_for-$function_name-=%3E-(-%25spec-)>.

=head2 use Feature::Compat::Try

Provides syntax support for try/catch control flow:

   try {
      attempt_a_thing();
      return "success";
   }
   catch ($e) {
      warn "It failed - $e";
      return "failure";
   }

Also see L<https://metacpan.org/pod/Feature::Compat::Try>.

=cut

1;

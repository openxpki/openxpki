package OpenXPKI::Server::API2::Plugin::Crypto::password_quality::CheckEntropyRole;
use feature 'unicode_strings';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::password_quality::CheckEntropyRole -
Check password entropy

=head1 CHECKS

This role adds the following checks to
L<OpenXPKI::Server::API2::Plugin::Crypto::password_quality::Validate>:

C<entropy>.

Enabled by default: C<entropy>.

For more information about the checks see
L<OpenXPKI::Server::API2::Plugin::Crypto::password_quality>.

=cut

use Moose::Role;

# Core modules
use POSIX qw(floor);

# Project modules
use OpenXPKI::Debug;


requires 'register_check';
requires 'password';
requires 'enable';


use constant {
    OTHER => '__unlisted character class',
    UNICODE_ASSIGNED_CHARACTERS => 143924,
};


has min_entropy => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => sub { 60 },
);

has _unicode_blocks => (
    is => 'ro',
    isa => 'HashRef',
    traits  => ['Hash'],
    init_arg => undef,
    lazy => 1,
    builder => '_build_unicode_blocks',
    handles => {
        # Returns the unicode block range by given block name
        unicode_block => 'get',
        # Returns a list of all defined unicode block names
        unicode_block_names => 'keys',
    },
);

sub _build_unicode_blocks {
    my $result = {};
    # cat ~/Unicode\ Basic\ Multilingual\ Plane.txt | perl -e 'use utf8; while (<>) { chomp; next if /^(#|$)/; ($n,$r1,$r2) = m/^(.*) \(([^-]+)-([^-]+)\)$/; $n=~s/\x{0027}/\\\x{0027}/; print "[ 0x$r1 => 0x$r2 ] => \x{0027}$n\x{0027},\n";} '

    # List of selected blocks (= character classes) from Unicode's Basic Multilingual Plane (plane 0).
    # Multiple ranges may refer to a block of the same name
    my $unicode_plane0_selected_blocks = [
        # manually separated:
        [ 0x0000 => 0x001F, 'Basic Latin (Control)' ],
        [ 0x0020 => 0x002F, 'Basic Latin (Punctuation)' ],
        [ 0x0030 => 0x0039, 'Basic Latin (Number)' ],
        [ 0x003A => 0x0040, 'Basic Latin (Punctuation)' ],
        [ 0x0041 => 0x005A, 'Basic Latin (Letter, uppercase)' ],
        [ 0x005B => 0x0060, 'Basic Latin (Punctuation)' ],
        [ 0x0061 => 0x007A, 'Basic Latin (Letter, lowercase)' ],
        [ 0x007B => 0x007F, 'Basic Latin (Punctuation)' ],
        # generated:
        [ 0x0080 => 0x00FF, 'Latin-1 Supplement' ],
        [ 0x0100 => 0x024F, 'Latin Extended-A + Latin Extended-B' ],
        [ 0x1D00 => 0x1DBF, 'Phonetic Extensions + Phonetic Extensions Supplement' ],
        [ 0x1E00 => 0x1EFF, 'Latin Extended Additional' ],
        [ 0x0250 => 0x02AF, 'IPA Extensions' ],
        [ 0x0370 => 0x03FF, 'Greek and Coptic' ],
        [ 0x0400 => 0x052F, 'Cyrillic + Cyrillic Supplement' ],
        [ 0x0530 => 0x058F, 'Armenian' ],
        [ 0x0590 => 0x05FF, 'Hebrew' ],
        [ 0x0600 => 0x06FF, 'Arabic' ],
        [ 0x0700 => 0x074F, 'Syriac' ],
        [ 0x0750 => 0x077F, 'Arabic Supplement' ],
        [ 0x0780 => 0x07BF, 'Thaana' ],
        [ 0x07C0 => 0x07FF, 'N\'Ko' ],
        [ 0x0800 => 0x083F, 'Samaritan' ],
        [ 0x0840 => 0x085F, 'Mandaic' ],
        [ 0x0860 => 0x086F, 'Syriac Supplement' ],
        [ 0x08A0 => 0x08FF, 'Arabic Extended-A' ],
        [ 0x0900 => 0x097F, 'Devanagari' ],
        [ 0x0980 => 0x09FF, 'Bengali' ],
        [ 0x0A00 => 0x0A7F, 'Gurmukhi' ],
        [ 0x0A80 => 0x0AFF, 'Gujarati' ],
        [ 0x0B00 => 0x0B7F, 'Oriya' ],
        [ 0x0B80 => 0x0BFF, 'Tamil' ],
        [ 0x0C00 => 0x0C7F, 'Telugu' ],
        [ 0x0C80 => 0x0CFF, 'Kannada' ],
        [ 0x0D00 => 0x0D7F, 'Malayalam' ],
        [ 0x0D80 => 0x0DFF, 'Sinhala' ],
        [ 0x0E00 => 0x0E7F, 'Thai' ],
        [ 0x0E80 => 0x0EFF, 'Lao' ],
        [ 0x0F00 => 0x0FFF, 'Tibetan' ],
        [ 0x1000 => 0x109F, 'Myanmar' ],
        [ 0x10A0 => 0x10FF, 'Georgian' ],
        [ 0x1100 => 0x11FF, 'Hangul Jamo' ],
        [ 0x1200 => 0x137F, 'Ethiopic' ],
        [ 0x1380 => 0x139F, 'Ethiopic Supplement' ],
        [ 0x13A0 => 0x13FF, 'Cherokee' ],
        [ 0x1400 => 0x167F, 'Unified Canadian Aboriginal Syllabics' ],
        [ 0x1680 => 0x169F, 'Ogham' ],
        [ 0x1700 => 0x171F, 'Tagalog' ],
        [ 0x1720 => 0x173F, 'Hanunoo' ],
        [ 0x1740 => 0x175F, 'Buhid' ],
        [ 0x1760 => 0x177F, 'Tagbanwa' ],
        [ 0x1780 => 0x17FF, 'Khmer' ],
        [ 0x1800 => 0x18AF, 'Mongolian' ],
        [ 0x18B0 => 0x18FF, 'Unified Canadian Aboriginal Syllabics Extended' ],
        [ 0x1900 => 0x194F, 'Limbu' ],
        [ 0x1950 => 0x197F, 'Tai Le' ],
        [ 0x1980 => 0x19DF, 'New Tai Lue' ],
        [ 0x19E0 => 0x19FF, 'Khmer Symbols' ],
        [ 0x1A00 => 0x1A1F, 'Buginese' ],
        [ 0x1A20 => 0x1AAF, 'Tai Tham' ],
        [ 0x1B00 => 0x1B7F, 'Balinese' ],
        [ 0x1B80 => 0x1BBF, 'Sundanese' ],
        [ 0x1BC0 => 0x1BFF, 'Batak' ],
        [ 0x1C00 => 0x1C4F, 'Lepcha' ],
        [ 0x1C50 => 0x1C7F, 'Ol Chiki' ],
        [ 0x1C80 => 0x1C8F, 'Cyrillic Extended-C' ],
        [ 0x1C90 => 0x1CBF, 'Georgian Extended' ],
        [ 0x1CC0 => 0x1CCF, 'Sundanese Supplement' ],
        [ 0x1CD0 => 0x1CFF, 'Vedic Extensions' ],
        [ 0x1F00 => 0x1FFF, 'Greek Extended' ],
        [ 0x2C00 => 0x2C5F, 'Glagolitic' ],
        [ 0x2C60 => 0x2C7F, 'Latin Extended-C' ],
        [ 0x2C80 => 0x2CFF, 'Coptic' ],
        [ 0x2D00 => 0x2D2F, 'Georgian Supplement' ],
        [ 0x2D30 => 0x2D7F, 'Tifinagh' ],
        [ 0x2D80 => 0x2DDF, 'Ethiopic Extended' ],
        [ 0x2DE0 => 0x2DFF, 'Cyrillic Extended-A' ],
        [ 0x2E80 => 0x2EFF, 'CJK Radicals Supplement' ],
        [ 0x2F00 => 0x2FDF, 'Kangxi Radicals' ],
        [ 0x2FF0 => 0x2FFF, 'Ideographic Description Characters' ],
        [ 0x3000 => 0x303F, 'CJK Symbols and Punctuation' ],
        [ 0x3040 => 0x309F, 'Hiragana' ],
        [ 0x30A0 => 0x30FF, 'Katakana' ],
        [ 0x3100 => 0x312F, 'Bopomofo' ],
        [ 0x3130 => 0x318F, 'Hangul Compatibility Jamo' ],
        [ 0x3190 => 0x319F, 'Kanbun' ],
        [ 0x31A0 => 0x31BF, 'Bopomofo Extended' ],
        [ 0x31C0 => 0x31EF, 'CJK Strokes' ],
        [ 0x31F0 => 0x31FF, 'Katakana Phonetic Extensions' ],
        [ 0x3200 => 0x32FF, 'Enclosed CJK Letters and Months' ],
        [ 0x3300 => 0x33FF, 'CJK Compatibility' ],
        [ 0x3400 => 0x4DBF, 'CJK Unified Ideographs Extension A' ],
        [ 0x4DC0 => 0x4DFF, 'Yijing Hexagram Symbols' ],
        [ 0x4E00 => 0x9FFF, 'CJK Unified Ideographs' ],
        [ 0xA000 => 0xA48F, 'Yi Syllables' ],
        [ 0xA490 => 0xA4CF, 'Yi Radicals' ],
        [ 0xA4D0 => 0xA4FF, 'Lisu' ],
        [ 0xA500 => 0xA63F, 'Vai' ],
        [ 0xA640 => 0xA69F, 'Cyrillic Extended-B' ],
        [ 0xA6A0 => 0xA6FF, 'Bamum' ],
        [ 0xA800 => 0xA82F, 'Syloti Nagri' ],
        [ 0xA830 => 0xA83F, 'Common Indic Number Forms' ],
        [ 0xA840 => 0xA87F, 'Phags-pa' ],
        [ 0xA880 => 0xA8DF, 'Saurashtra' ],
        [ 0xA8E0 => 0xA8FF, 'Devanagari Extended' ],
        [ 0xA900 => 0xA92F, 'Kayah Li' ],
        [ 0xA930 => 0xA95F, 'Rejang' ],
        [ 0xA960 => 0xA97F, 'Hangul Jamo Extended-A' ],
        [ 0xA980 => 0xA9DF, 'Javanese' ],
        [ 0xA9E0 => 0xA9FF, 'Myanmar Extended-B' ],
        [ 0xAA00 => 0xAA5F, 'Cham' ],
        [ 0xAA60 => 0xAA7F, 'Myanmar Extended-A' ],
        [ 0xAA80 => 0xAADF, 'Tai Viet' ],
        [ 0xAAE0 => 0xAAFF, 'Meetei Mayek Extensions' ],
        [ 0xAB00 => 0xAB2F, 'Ethiopic Extended-A' ],
        [ 0xAB70 => 0xABBF, 'Cherokee Supplement' ],
        [ 0xABC0 => 0xABFF, 'Meetei Mayek' ],
        [ 0xAC00 => 0xD7AF, 'Hangul Syllables' ],
        [ 0xD7B0 => 0xD7FF, 'Hangul Jamo Extended-B' ],
        [ 0xF900 => 0xFAFF, 'CJK Compatibility Ideographs' ],
        [ 0xFB00 => 0xFB4F, 'Alphabetic Presentation Forms' ],
        [ 0xFB50 => 0xFDFF, 'Arabic Presentation Forms-A' ],
        [ 0xFE10 => 0xFE1F, 'Vertical Forms' ],
    ];

    my $_block_ranges = {};
    for my $def (@$unicode_plane0_selected_blocks) {
        my $block = $def->[2];
        $result->{$block}->{char_count} += ($def->[1] - $def->[0] + 1);
        push @{$_block_ranges->{$block}}, sprintf('\x{%x}-\x{%x}', $def->[0], $def->[1]);
    }

    for my $block (keys %$_block_ranges) {
        my $list = sprintf '[%s]', join(",", @{ $_block_ranges->{$block} });
        $result->{$block}->{regex} = qr/$list/;
    }

    my $char_count = 0;
    $char_count += $_ for map { $_->{char_count} } values %{ $result };

    $result->{OTHER()}->{char_count} = UNICODE_ASSIGNED_CHARACTERS - $char_count;

    return $result;
}


after hook_register_checks => sub {
    my $self = shift;
    $self->register_check('entropy' => 'check_entropy');
    $self->add_default_check('entropy');
};


sub check_entropy {
    my $self = shift;
    if ($self->_calc_entropy($self->password) < $self->min_entropy) {
        return [ "entropy" => "I18N_OPENXPKI_UI_PASSWORD_QUALITY_INSUFFICIENT_ENTROPY" ];
    }
    return;
}

sub _calc_entropy {
    my ($self, $passw) = @_;

    return 0 unless (defined($passw) && $passw ne '');

    my $entropy = 0;

    my $classes = +{};

    my $eff_len = 0.0;      # the effective length
    my $char_count = +{};   # to count characters quantities
    my $distances = +{};    # to collect differences between adjacent characters

    my $len = length($passw);

    my $prev_nc = 0;

    for (my $i = 0; $i < $len; $i++) {
        my $c = substr($passw, $i, 1);
        my $nc = ord($c);
        $classes->{$self->_get_char_class($c)} = 1;

        my $incr = 1.0;     # value/factor for increment effective length

        if ($i > 0) {
            my $d = $nc - $prev_nc;

            if (exists($distances->{$d})) {
                $distances->{$d}++;
                $incr /= $distances->{$d};
            }
            else {
                $distances->{$d} = 1;
            }
        }

        if (exists($char_count->{$c})) {
            $char_count->{$c}++;
            $eff_len += $incr * (1.0 / $char_count->{$c});
        }
        else {
            $char_count->{$c} = 1;
            $eff_len += $incr;
        }

        $prev_nc = $nc;
    }

    # printf "Validated passwort contains characters from these blocks: %s\n", join ", ", sort keys %$classes;

    my $pci = 0; # Password complexity index
    for (keys(%$classes)) {
        $pci += $self->unicode_block($_)->{char_count};
    }

    if ($pci != 0) {
        my $bits_per_char = log($pci) / log(2.0);
        $entropy = floor($bits_per_char * $eff_len);
    }
    ##! 32: "Password entropy: $entropy"
    return $entropy;
}

sub _get_char_class {
    my ($self, $char) = @_;
    for my $block (grep { $_ ne OTHER } $self->unicode_block_names) {
        return $block if $char =~ $self->unicode_block($block)->{regex};
    }
    return OTHER;
}

1;

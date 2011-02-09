#!/usr/bin/perl -w

if ($#ARGV != 0) {
    print "usage: $0 <input.bdf>\n";
    exit -1;
}

$first = 0;
$last = 255;
$chars_total = $last - $first + 1;

$input_bdf = $ARGV[0];
open(INPUT_BDF, "<", "$input_bdf") || die $!;

while (<INPUT_BDF>) {
    if ( $_ =~ m/^COMMENT (.*?)$/ ) {
	$name = $1;
	$name =~ s/\s/_/;
	$name =~ s/-/_/;
	$NAME = uc $name;
	$output_c = "$name" . '.c';
	print "output file: $output_c\n";
    } elsif ($_ =~ m/FAMILY_NAME (.*?)$/) {
	$family = $1;
	$family =~ s/\"|\'//g;
    } elsif ( $_ =~ m/^FONTBOUNDINGBOX (\d+) (\d+) (\d+) ([-+]?\d+)$/ ) {
	$width = $1;
	$height = $2;
    } elsif ( $_ =~ m/^CHARS (\d+)/) {
	last;
    }
}

$data_size = $chars_total * $height;

open(OUTPUT_C, ">", "$output_c");
print OUTPUT_C
"/*
 * $output_c
 *
 * Font family: $family
 *
 * Font widtch: $width
 * Font height: $height
 * Chars: $first..$last ($chars_total)
 *
 * file generated by $0
 */

#include <linux/font.h>
#include <linux/module.h>

#define FONTDATAMAX $data_size

static const unsigned char fontdata_$name" . "[FONTDATAMAX] = {

";

$cur_enc = $first;
$prev_enc = $first - 1;

while (<INPUT_BDF>) {
    if ( $_ =~ m/(^[\w\d]{2}$)/ ) {
	$hex = $1;
	$bin = sprintf '%0' . "$width" . 'b', hex($hex);
	$bin =~ tr/01/~#/;
	print OUTPUT_C "\t0x" . "$hex,\t/* $bin */\n";
    } elsif ( $_ =~ m/^ENDCHAR$/ ) {
	print OUTPUT_C "\n";
    } elsif ( $_ =~ m/^ENCODING (.*?)$/ ) {
	$prev_enc = $cur_enc;
	$cur_enc = $1;
	if ( $cur_enc == $last + 1 ) {
	    last;
	}
	if ( $cur_enc > $prev_enc + 1 ) {
	    print OUTPUT_C "\t/* chars " .
		($prev_enc+1) . ".." . ($cur_enc-1) . " are skipped! */\n\n";
	}
	print OUTPUT_C "\t" . "/* $cur_enc */\n";
    }
}

print OUTPUT_C "};

const struct font_desc font_$name = {
\t.idx    = " . "$NAME" . "_IDX,
\t.name   = \"$NAME\",
\t.width  = $width,
\t.height = $height,
\t.data   = fontdata_$name,
\t.pref   = 0,
};
EXPORT_SYMBOL(font_$name);
";

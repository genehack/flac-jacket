#! /usr/bin/perl

# $Id$
# $URL$

use strict;
use warnings;

use lib "/home/genehack/proj/flac-jacket/lib";
use FlacJacket;

unlink 'audio.cddb';  
unlink $_ foreach glob( '*.inf' );
foreach my $wav ( glob( '*.wav' )) {
  `flac $wav`;
  unlink $wav;
}

my $file = 'audio.cdindex';
print "About to parse '$file' file and rename files -- hit <RET> to continue";
<STDIN>;
FlacJacket::RenameFlacsFromFile( $file , 1 , 2006 , 'Unclassified' );

unlink $file;
chdir( '..' );
rmdir 'disk-1';

print "About to tag files -- edit meta/*yml as needed and hit <RET> to continue";
<STDIN>;
FlacJacket::RetagCurrentDirectory();

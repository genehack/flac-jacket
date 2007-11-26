#! /usr/bin/perl

use strict;
use warnings;

use WebService::MusicBrainz;

my $rel = WebService::MusicBrainz->new_release();
my $res = $rel->search( { DISCID => 'Cd7CHsInTZYAfTUqcjyQa.DZipc-' } );
my $trk = $res->track;
print "TRK: $trk";

my $xml = $res->as_xml();

open( OUT , '>' , 'foo.xml' );
print OUT $xml;
close( OUT );


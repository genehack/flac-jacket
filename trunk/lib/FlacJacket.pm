#! /usr/bin/perl

package FlacJacket;

use strict;
use warnings;

use Carp;
use Cwd;
use File::Copy;
use File::Path;
use Image::Magick;
use MP3::Info;
use XML::Simple;
use YAML             qw/ DumpFile LoadFile /;

# ApplyTagsToFile
sub ApplyTagsToFile {
  my( $tags , $file ) = ( @_ );

  my $ret;
  if    ( $file =~ /.flac$/ ) { $ret = ApplyTagsToFlac( $tags , $file ) }
  elsif ( $file =~ /.mp3$/ )  { $ret = ApplyTagsToMp3( $tags , $file )  }
  else                        { croak "'$file' isn't an MP3 or FLAC file\n" }

  if    ( $ret == -1 ) { carp "ERROR removing tags from $file" }
  elsif ( $ret == -2 ) { carp "ERROR applying tags to $file"   }

  return;
} #/ApplyTagsToFile

# ApplyTagsToFlac
sub ApplyTagsToFlac {
  my( $tags , $file ) = ( @_ );

  my $ret1 = system "metaflac --remove-all-tags $file";
  return -1 if $ret1;
    
  my @options = (
    "--import-picture-from=./cover.jpg"         ,
    "--set-tag=\"ALBUM=$tags->{album}\""          ,
    "--set-tag=\"DISCNUMBER=$tags->{disk}\""      ,
    "--set-tag=\"TITLE=$tags->{title}\""          ,
    "--set-tag=\"TRACKNUMBER=$tags->{track}\""    ,
    "--set-tag=\"TRACKTOTAL=$tags->{numTracks}\"" ,
    "--set-tag=\"DATE=$tags->{year}\""            ,
  );
  foreach ( @{ $tags->{artist} } ) { push @options , "--set-tag=\"ARTIST=$_\"" }
  foreach ( @{ $tags->{genre} }  ) { push @options , "--set-tag=\"GENRE=$_\""  }
  
  my $options = join ' ' , @options;
  my $ret2 = system "metaflac $options $file";
  return -2 if $ret2;
    
  return 0;
  
} #/ApplyTagsToFlac

# ApplyTagsToMp3
sub ApplyTagsToMp3 {
  my( $tags , $file ) = ( @_ );

  my $ret1 = system "eyeD3 --remove-all $file 2>/dev/null >/dev/null";
  return -1 if $ret1;
    
  my $artist = join '|' , @{ $tags->{artist} };
  my $genre  = join '|' , @{ $tags->{genre} };
  my @options = (
    '-2'                                    ,
    "--add-image=./cover.jpg:FRONT_COVER"   ,
    "--album=\"$tags->{album}\""            ,
    "--artist=\"$artist\""                  ,
    "--genre=\"$genre\""                    ,
    "--title=\"$tags->{title}\""            ,
    "--track=\"$tags->{track}\""            ,
    "--track-total=\"$tags->{numTracks}\""  ,
    "--year=\"$tags->{year}\""              ,
  );

  my $options = join ' ' , @options;
  my $ret2 = system "eyeD3 $options $file 2>/dev/null >/dev/null";
  return -2 if $ret2;
  
  return 0;
      
} #/ApplyTagsToMp3

# Id3ToYAML
sub Id3ToYAML {
  my $file = shift
    or croak "Need a file name for Id3ToYAML()";

  my @count = glob '*.mp3' ;
  my $count = @count;
  
  my $tag = get_mp3tag( $file )
    or croak "Can't get ID3 tag info from '$file'";

  foreach ( qw/ ALBUM ARTIST TITLE TRACKNUM YEAR / ) {
    croak "Didn't get value for '$_'\n"
      unless $tag->{$_};
  }

  my $artist = $tag->{ARTIST};
  my @artists;
  if ( $artist =~ /\|/ ) { @artists = split /\|/ , $artist }
  else                  { @artists = ( $artist ) }
  
  my $genre  = $tag->{GENRE} || 'Unclassified';
  my @genres;
  if ( $genre =~ /\|/ ) { @genres = split /\|/ , $genre }
  else                 { @genres = ( $genre ) }

  # if we're converting over an existing MP3 dir, we want everything to be
  # unclassified, so it has to be listened to at least once to get tagged
  # properly
  unshift @genres , 'Unclassified';
      
  my $yaml;
  $yaml->{album}     = $tag->{ALBUM};
  $yaml->{artist}    = \@artists;
  $yaml->{disk}      = 1;
  $yaml->{genre}     = \@genres;
  $yaml->{numTracks} = $count;
  $yaml->{title}     = $tag->{TITLE};
  $yaml->{track}     = $tag->{TRACKNUM};
  $yaml->{year}      = $tag->{YEAR};
  
  my( $prefix ) = $file =~ /^\d-(\d\d)-/ 
    or croak "can't get prefix from $file\n";
  my $out = "meta/1-$prefix-meta.yml";
  DumpFile( $out , $yaml );

  my $return = LoadFile( $out );
  return $return;
  
} #/Id3ToYAML

# MakeCover
sub MakeCover {
  my $file = shift;
  my $size = 200;

  my @potential_files = qw|
                            ./art/cover-front
                            ./art/insert-front
                            ./art/disk
                          |;
  if ( $file ) {
    unshift @potential_files , $file;
  }
  
  my $real_file;
  foreach ( @potential_files ) {
    if    ( -e "$_.png" ) { $real_file = "$_.png" ; last }
    elsif ( -e "$_.jpg" ) { $real_file = "$_.jpg" ; last }
  }
  
  die "Can't seem to locate a cover graphic"
    unless $real_file;
    
  my $p = Image::Magick->new;
  $p->Read( $real_file );
  $p->Scale( geometry => $size );
  $p->Write( './cover.jpg' );
  
} #/MakeCover

# ParseSingleArtistCD
sub ParseSingleArtistCD {
  my( $data , $disk , $year , $genre ) = ( @_ );

  my $album     = $data->{Title};
  my $numTracks = $data->{NumTracks};

  my $artist    = $data->{SingleArtistCD}{Artist};
  my @artist;
  if ( $artist =~ /\|/ ) { @artist = split /\|/ , $artist } 
  else                  { @artist = ( $artist ) }

  my @genre;
  if ( $genre =~ /\|/ ) { @genre = split /\|/ , $genre }
  else                 { @genre = ( $genre ) }

  my @input_tracks;
  if ( ref( $data->{SingleArtistCD}{Track} ) eq 'ARRAY' ) {
    @input_tracks = @{ $data->{SingleArtistCD}{Track} };
  }
  else {
    @input_tracks = ( $data->{SingleArtistCD}{Track} );
  }
  
  my @tracks;
  foreach my $href ( @input_tracks ) {
    my $trackNum = ( sprintf "%02d" , $href->{Num} );
    
    my $track = {
      disk      => $disk         ,
      title     => $href->{Name} ,
      track     => $trackNum     ,
      numTracks => $numTracks    ,
      genre     => \@genre       ,
      year      => $year         ,
      artist    => \@artist      ,
      album     => $album        ,
    };

    ### FIXME: should just take this bit out and write a script to convert a
    ### SingleArtistCD for a mult-artist CD into a MultipleArtistCD file
    if ( $artist =~ /Various Artists/i ) {
      my( $artist , $title ) = $href->{Name} =~ /^(.*?)\s?\/\s?(.*)$/
        or die( "can't parse ",$href->{Name},"\n" );
      $track->{title}  = $title;
      my @artist;
      if ( $artist =~ /\|/ ) { @artist = split /\|/ , $artist } 
      else                  { @artist = ( $artist ) }
      $track->{artist} = \@artist
    }

    push @tracks , $track;
  }

  return \@tracks;
  
} #/ParseSingleArtistCD


# ParseMultiArtistCD
sub ParseMultiArtistCD {
  my( $data , $disk , $year , $genre ) = ( @_ );

  my $album     = $data->{Title};
  my $numTracks = $data->{NumTracks};

  my @genre;
  if ( $genre =~ /\|/ ) { @genre = split /\|/ , $genre }
  else                 { @genre = ( $genre ) }

  my @tracks;
  foreach my $href ( @{ $data->{MultipleArtistCD}{Track}} ) {
    my $trackNum = ( sprintf "%02d" , $href->{Num} );

    my @artist;
    if ( $href->{Artist} =~ /\|/ ) { @artist = split /\|/ , $href->{Artist} }
    else                          { @artist = ( $href->{Artist} )          }
    
    my $track = {
      disk      => $disk         ,
      title     => $href->{Name} ,
      track     => $trackNum     ,
      numTracks => $numTracks    ,
      genre     => \@genre       ,
      year      => $year         ,
      artist    => \@artist      ,
      album     => $album        ,
    };
    
    push @tracks,  $track;
  }

  return \@tracks;
  
} #/ParseMultiArtistCD


# RenameFlacsFromFile
sub RenameFlacsFromFile {
  my( $file , $disk , $year , $genre ) = ( @_ );

  croak( "no '$file' file" ) unless (-e "./$file" );
  my $data = XMLin( $file );

  my $tracks;
  if (    $data->{SingleArtistCD}   ) {
    $tracks = ParseSingleArtistCD( $data , $disk , $year , $genre );
  }
  elsif ( $data->{MultipleArtistCD} ) {
    $tracks = ParseMultiArtistCD( $data , $disk , $year , $genre );
  }
  else { croak "Can't find '*ArtistCD' element!\n" }
  
  mkpath "../meta" unless -d "../meta";

  foreach my $track ( @$tracks ) {
    my $file = sprintf "../meta/%1d-%02d-meta.yml" , $disk , $track->{track};
    DumpFile( $file , $track );

    my $flac = sprintf "track_%02d.flac" , $track->{track};
    my $dest = sprintf "../%1d-%02d-%s.flac" ,
      $disk , $track->{track} , SanitizeFileName( $track->{title} );
    move( $flac , $dest );
  }  
} #/RenameFlacsFromFile

# RetagCurrentDirectory
sub RetagCurrentDirectory {

  my $change = 0;

  my( $album , $album_warning );
    
  foreach my $meta ( glob 'meta/*.yml' ) {

    my( $prefix ) = $meta =~ m|/(\d-\d\d)-|
      or croak "Can't get prefix from '$meta'\n";

    my( $disk ) = $prefix =~ m|^(\d)-|
      or croak "Can't get disk number from '$prefix' (from '$meta')\n";
    
    my $tags = LoadFile( $meta );

    if ( $album->[$disk] ) {
      if ( $album->[$disk] ne $tags->{album} ) {
        my $pwd = cwd();
        carp "Inconsistent album names seen in $pwd! ($meta)"
          unless $album_warning;
        $album_warning++;
      }
    }
    else { $album->[$disk] = $tags->{album} }

    my $name = FlacJacket::SanitizeFileName( $tags->{title} );
    if ( my @files = glob( "$prefix-$name.*" )) {
      foreach my $file ( @files ) {
        next if ( -M $file < -M $meta );
        print "Retagging '$file'\n";
        FlacJacket::ApplyTagsToFile( $tags , $file );
        $change++;
      }
    }
    else {
      print "FIXING FILE NAME for $prefix-$name\n";
      if ( my @files = glob( "$prefix-*" )) {
        foreach my $file ( @files ) {
          my $suffix = ( split /\./ , $file )[-1];
          my $dest = "$prefix-$name.$suffix";
          move( $file , $dest );
          print "Retagging '$dest'\n";
          FlacJacket::ApplyTagsToFile( $tags , $dest );
          $change++;
        }
      }
      else {
        croak "COULDN'T FIND A FILE TO FIX!";
      }
    }
  }

  if ( $change ) {
    print "Applying Replay Gain to album\n";
    if ( glob( "*.flac" )) {
      `metaflac --add-replay-gain *.flac`;
    }
    if ( glob( "*.mp3" )) {
      `mp3gain -akp *.mp3`;
    }
  }
  
} #/RetagCurrentDirectory


# RipDisk
sub RipDisk {
  my( $disk , $year , $genre ) = ( @_ );

  my $dir = "./disk-$disk";
  mkpath $dir
    or die "Couldn't make ./$dir ($!)";
  chdir $dir;
  
  #`cdda2wav -Icooked_ioctl -D/dev/cdrom -L 0 -J`;
  `cdda2wav -D/dev/sg2 -L 0 -x -paranoia -B track`;
  unlink 'audio.cddb';
  unlink $_ foreach glob( '*.inf' );
#  `cdparanoia -B 1-`;
  foreach my $wav ( glob( '*.wav' )) {
    `flac $wav`;
    unlink $wav;
  }

  my $file = 'audio.cdindex';
  print "\n\n\n\nAbout to parse '$file' file and rename files -- hit <RET> to continue";
  <STDIN>;
  RenameFlacsFromFile( $file , $disk , $year , $genre );

  unlink $file;
  chdir( '..' );
  rmdir $dir;

  print "\n\n\n\nAbout to tag files -- cover.jpg MUST EXIST! -- edit meta/*yml as needed and hit <RET> to continue";
  <STDIN>;
  RetagCurrentDirectory();
    
} #/RipDisk

# SanitizeFileName
sub SanitizeFileName {
  my( $name ) = ( @_ );
  $name =~ s/[^-.a-zA-Z0-9]//g;
  return $name;
} #/SanitizeFileName


1;

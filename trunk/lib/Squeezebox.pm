package Squeezebox;

use strict;
use warnings;

use Net::Telnet;
use Sys::Hostname;
use Socket;
use URI::Escape;

sub build_player_list {
  my $SC    = _connect_to_squeezecenter();
  my $query = 'players 0 10';
  $SC->print( $query );
  # we're going to get back something that looks like this (after it's decoded):
  # (It will be one long line, not wrapped like this example.) 
  # players 0 10 count:3 playerindex:0 playerid:00:04:20:05:7b:88 uuid:
  # ip:192.168.1.40:22231 name:bedroom model:squeezebox isplayer:1
  # displaytype:graphic-280x16 canpoweroff:1 connected:1 playerindex:1
  # playerid:192.168.1.17 uuid: ip:192.168.1.17:56306 name:mpg321 from
  # 192.168.1.17 model:http isplayer:0 canpoweroff:0 connected:1 playerindex:2
  # playerid:00:04:20:07:87:0e uuid: ip:192.168.1.41:26607 name:genehack
  # model:squeezebox2 isplayer:1 displaytype:graphic-320x32 canpoweroff:1
  # connected:1
  
  my $response = $SC->getline();
  
  my @players = split /playerindex%3A\d+ / , $response;
  shift @players; # get rid of the junk at the beginning of the line

  my %players;
  foreach my $player ( @players ) {
    my %player_data;
    foreach ( split / / , $player ) {
      my( $key , $value ) = $_ =~ /^(\S+?)%3A(.*)$/;
      $value = uri_unescape( $value );
      $player_data{$key} = $value if $value;
    }
    
    # the 'ip' value is actually 'ip:port'. let's clean that up.
    ( $player_data{ip} , $player_data{port} ) = $player_data{ip} =~ /^(.*?):(.*?)$/
      or die "Can't parse IP and port from $player_data{ip}\n";
    
    my $name = $player_data{name};
    $players{$name} = \%player_data;
  }

  return \%players;
}

sub fetch_token {
  my $player = shift || die "Need a player.\n";
  my $token  = shift || die "Need a token.\n";
  
  my $SC = _connect_to_squeezecenter();
  $SC->print("$player $token ?");

  # we're going to get back something that looks like this:
  
  # 192.168.1.17 title The%20W.A.N.D.

  # the first part may or may not be the same as $player -- we're just going to ignore that
  # the second part _will_ eq $token
  # the third part -- everything after $token -- is URL encoded and what we want

  # so grab that third part, remove the URL encoding, and save it

  ( $token ) = $SC->getline =~ / $token (.*)$/;
  return uri_unescape( $token );
}

sub get_player_from_current_host {
  my $SC      = _connect_to_squeezecenter();
  my $players = build_player_list( $SC );
  my $ip      = inet_ntoa(( gethostbyname( hostname ))[4] );
  
  foreach my $player ( keys %$players ) {
    if ( $players->{$player}{ip} eq $ip ) {
      return uri_escape( $player );
    }
  }

  return 0;
}

{
  my $SC;
  sub _connect_to_squeezecenter {
    return $SC if $SC;
    
    my $squeezecenter_host = 'jukebox';
    my $squeezecenter_port = '9090';
    
    $SC = Net::Telnet->new(
      Host       => $squeezecenter_host ,
      Port       => $squeezecenter_port ,
      Telnetmode => 0                   , 
    );
    
    return $SC;
  }
}

1;

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
  module_name    => 'FlacJacket' ,
  license        => 'perl',
  dist_author    => 'John SJ Anderson <genehack@genehack.org>',
  add_to_cleanup => [ 'FlacJacket-*' ],
  build_requires => {} ,
  requires       => {
    'Audio::M4P::QuickTime' => 0 ,
    'Carp'                  => 0 ,
    'Cwd'                   => 0 ,
    'File::Copy'            => 0 ,
    'File::Path'            => 0 ,
    'File::Remove'          => 0 ,
    'FindBin'               => 0 ,
    'Imager'                => 0 ,
    'List::MoreUtils'       => 0 ,
    'MP3::Info'             => 0 ,
    'Net::Telnet'           => 0 ,
    'Socket'                => 0 ,
    'Sys::Hostname'         => 0 ,
    'URI::Escape'           => 0 ,
    'XML::Simple'           => 0 ,
    'YAML'                  => 0 ,
    'perl'                  => '5.10.0' ,
  } ,
);

$build->create_build_script;


requires "Carp" => "0";
requires "IO::Socket::INET" => "0";
requires "JSON" => "0";
requires "LWP::UserAgent" => "0";
requires "Moo" => "0";
requires "Net::HTTP::Spore" => "0";
requires "Net::HTTP::Spore::Middleware::DefaultParams" => "0";
requires "strict" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "DDP" => "0";
  requires "Data::Dumper" => "0";
  requires "Net::HTTP::Spore::Middleware::Mock" => "0";
  requires "Net::Ping" => "0";
  requires "Test::LWP::UserAgent" => "0";
  requires "Test::More" => "0";
  requires "Try::Tiny" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "6.30";
};

on 'develop' => sub {
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
};

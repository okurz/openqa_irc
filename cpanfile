requires 'Bot::BasicBot::Pluggable::Module';
requires 'App::Bot::BasicBot::Pluggable';
requires 'Carp';
requires 'Mojo::UserAgent';
requires 'POE::Component::SSLify';
requires 'strict';
requires 'warnings';

on 'test' => sub {
  requires 'Perl::Tidy';
  requires 'Perl::Critic';
  requires 'Test::More';
  requires 'Mojo::Base';
  requires 'Mojo::Transaction';
};

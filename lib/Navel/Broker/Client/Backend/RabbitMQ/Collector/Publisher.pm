# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-broker-client-backend-rabbitmq is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Broker::Client::Backend::RabbitMQ::Collector::Publisher 0.1;

use Navel::Base;

use AnyEvent::RabbitMQ 1.19;

use Navel::Utils::Broker::Client::Backend::RabbitMQ;
use Navel::Logger::Message;
use Navel::Utils 'json_constructor';

#-> class variables

my $net;

my $json_constructor = json_constructor;

#-> functions

sub init {
}

sub enable {
    shift->(1);
}

sub disable {
    undef $net;

    shift->(1);
}

sub is_connectable {
    shift->(1, 1);
}

sub publish {
    my $done = shift;

    if (my @channels = values %{$net->channels}) {
        my $events = W::queue()->dequeue;

        if (@{$events}) {
            W::log(
                [
                    'info',
                    'sending ' . @{$events} . ' event(s) to exchange ' . W::collector()->{publisher_backend_input}->{fanout_exchange} . '.'
                ]
            );

            $channels[0]->publish(
                exchange => W::collector()->{publisher_backend_input}->{fanout_exchange},
                header => {
                    delivery_mode => 2
                },
                body => $json_constructor->encode($events),
                on_inactive => sub {
                    W::log(
                        [
                            'warning',
                            'idle (inactive) channel.'
                        ]
                    );

                    $done->(1);
                },
                on_ack => sub {
                    W::log(
                        [
                            'info',
                            'publicaton done.'
                        ]
                    );

                    $done->(1);
                },
                on_nack => sub {
                    W::log(
                        [
                            'warning',
                            'an error occurred during the publicaton.'
                        ]
                    );

                    my $size_left = W::queue()->size_left;

                    W::queue()->enqueue($size_left < 0 ? @{$events} : splice @{$events}, - ($size_left > @{$events} ? @{$events} : $size_left));

                    $done->(1);
                }
            );
        } else {
            W::log(
                [
                    'debug',
                    'no event to send.'
                ]
            );

            $done->(1);
        }
    } else {
        W::log(
            [
                'err',
                'publisher has no channel opened.'
            ]
        );

        $done->(1);
    }
}

sub connect {
    $net = Navel::Utils::Broker::Client::Backend::RabbitMQ::connect(
        host => W::collector()->{publisher_backend_input}->{host},
        port => W::collector()->{publisher_backend_input}->{port},
        user => W::collector()->{publisher_backend_input}->{user},
        pass => W::collector()->{publisher_backend_input}->{password},
        vhost => W::collector()->{publisher_backend_input}->{vhost},
        timeout => W::collector()->{publisher_backend_input}->{timeout},
        tls => W::collector()->{publisher_backend_input}->{tls},
        on_channel_opened => sub {
            shift->confirm->declare_exchange(
                exchange => W::collector()->{publisher_backend_input}->{fanout_exchange},
                type => 'fanout',
                on_success => sub {
                    W::log(
                        [
                            'notice',
                            'exchange declared.'
                        ]
                    );
                },
                on_failure => sub {
                    W::log(
                        [
                            'err',
                            Navel::Logger::Message->stepped_message('failure.', \@_)
                        ]
                    );

                    undef $net;
                }
            );
        },
        on_error => sub {
            undef $net;
        }
    );

    shift->(1);
}

*is_net_ready = \&Navel::Utils::Broker::Client::Backend::RabbitMQ::is_net_ready;

sub is_connected {
    shift->(1, Navel::Utils::Broker::Client::Backend::RabbitMQ::is_connected($net));
}

sub is_connecting {
    shift->(1, Navel::Utils::Broker::Client::Backend::RabbitMQ::is_connecting($net));
}

sub is_disconnected {
    shift->(1, Navel::Utils::Broker::Client::Backend::RabbitMQ::is_disconnected($net));
}

sub is_disconnecting {
    shift->(1, Navel::Utils::Broker::Client::Backend::RabbitMQ::is_disconnecting($net));
}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Broker::Client::Backend::RabbitMQ::Collector::Publisher

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-broker-client-backend-rabbitmq is licensed under the Apache License, Version 2.0

=cut

# image name lzh/cinder-volume:kilo
FROM registry.lzh.site:5000/lzh/openstackbase:kilo

MAINTAINER Zuhui Liu penguin_tux@live.com

ENV BASE_VERSION 2015-09-21
ENV OPENSTACK_VERSION kilo


ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get dist-upgrade -y
RUN apt-get install cinder-volume -y
RUN apt-get clean

RUN env --unset=DEBIAN_FRONTEND

RUN cp -rp /etc/cinder/ /cinder
RUN rm -rf /var/log/cinder/*
RUN rm -rf /var/lib/cinder/cinder.sqlite

ADD entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

ADD cinder-volume.conf /etc/supervisor/conf.d/cinder-volume.conf

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
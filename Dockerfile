FROM progrium/busybox:latest
MAINTAINER Alan LaMielle <alan.lamielle@gmail.com>

RUN opkg-install curl

VOLUME ["/etc/env.d"]
CMD ["/bin/rethinkdb-bootstrap.sh"]

ADD rethinkdb-bootstrap.sh /bin/

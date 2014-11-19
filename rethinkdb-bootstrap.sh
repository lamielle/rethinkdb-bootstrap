#!/bin/sh

# Compute env vars to use in a 'docker run' command
# to bootstrap a RethinkDB cluster using etcd.
#
# Based on two gists:
#
# https://gist.github.com/yaronr/aa5e9d1871f047568c84
# https://gist.github.com/philips/56fa3f5dae9060fbd100
#
# and progrium's start script from progrium/consul

bridge_ip="$(ip ro | awk '/^default/{print $3}')"
private_ip=$COREOS_PRIVATE_IPV4
echo "bridge_ip =" $bridge_ip
echo "private_ip =" $private_ip

# Atomically determine if we're the first to bootstrap
curl -L --fail http://$bridge_ip:4001/v2/keys/rethinkdb.com/bootstrap/bootstrapped?prevExist=false -XPUT -d value=$private_ip
if [ $? != 0 ]; then
  # Another node won the race, assume joining with the rest.
  echo "Not first machine, joining others..."
  export first="$(etcdctl --peers $bridge_ip:4001 get --consistent /rethinkdb.com/bootstrap/bootstrapped)"
  echo "first =" $first

  others=$(etcdctl --peers $bridge_ip:4001 ls /rethinkdb.com/bootstrap/machines | while read line; do
          ip=$(etcdctl --peers $bridge_ip:4001 get --consistent ${line})
          if [ "${ip}" != "${first}" ]; then
            echo -n "--join ${ip} "
          fi
        done)

  joins="--join $first $others"
else
  # We're the first to bootstrap.
  echo "First machine, setting rethinkdb bootstrap flag..."
  joins=""
fi

echo "Joins are:" $joins

etcdctl --peers $bridge_ip:4001 set /rethinkdb.com/bootstrap/machines/$HOSTNAME $private_ip >/dev/null

echo "Writing environment.rethinkdb"
cat > /etc/env.d/environment.rethinkdb <<EOF
RETHINKDB_PORTS="-p $private_ip:28015:28015 \
-p $private_ip:29015:29015 \
-p $private_ip:8080:8080"
RETHINKDB_JOIN="${joins}"
EOF

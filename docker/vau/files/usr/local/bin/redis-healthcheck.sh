#!/bin/bash
REAL_IP=$3
REAL_PORT=$4

#external check script cannot access environment variables, so we need to get it from file
REDIS_PASSWORD=$(cat /var/config/haproxy/secrets/redis_password)

echo "Checking $REAL_IP:$REAL_PORT"

  # check if redis is up and running
  if [[ "$( echo ping | timeout 2 redis-cli -a $REDIS_PASSWORD -h $REAL_IP -p $REAL_PORT --tls --cacert /var/config/haproxy/secrets/ca.crt --no-auth-warning )" = "PONG" ]]; then
      echo "Redis server up and running"
      # check if redis is master
      if [[ "$( echo "info replication" | timeout 2 redis-cli -a $REDIS_PASSWORD -h $REAL_IP -p $REAL_PORT --tls --cacert /var/config/haproxy/secrets/ca.crt  --no-auth-warning | grep "role:master" | wc -l )" -eq 1 ]]; then
        echo "Redis server $REAL_IP:$REAL_PORT is master"
        exit 0
      else
        echo "Redis server $REAL_IP:$REAL_PORT is slave"
        exit 1
      fi
  else
      echo "Redis server $REAL_IP:$REAL_PORT not ready"
      exit 1
  fi
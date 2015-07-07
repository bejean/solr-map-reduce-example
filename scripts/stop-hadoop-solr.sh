#!/bin/bash

export HOME="$( cd "$( dirname "$0" )/.." && pwd )"

# Variables initialisation
. $HOME/scripts/setenv.sh
cd $HOME

## Stop Solr (2 nodes)
#######################
cd $SOLR_HOME/server2
java -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar --stop 1>stop.log 2>&1 &
cd $SOLR_HOME/server
java -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar --stop 1>stop.log 2>&1 &
sleep 5

cd $HOME

## Stop HDFS+YARN
##################
$HADOOP_HOME/sbin/stop-yarn.sh
$HADOOP_HOME/sbin/stop-dfs.sh
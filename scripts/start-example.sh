#!/bin/bash

export HOME="$( cd "$( dirname "$0" )/.." && pwd )"

# Variables initialisation
. $HOME/scripts/setenv.sh
cd $HOME

# SETUP SCRIPT - Setup hdfs, yarn, and solr - then build the indexes with mapreduce and deploy them to Solr
#
# Requires: Solr trunk Java 1.7+, curl
# Tested on linux/OSX.
#######################

## Start HDFS+YARN
##################

# start hdfs
echo "start hdfs"
$HADOOP_HOME/sbin/stop-dfs.sh
$HADOOP_HOME/sbin/start-dfs.sh

# start yarn
echo "start yarn"
$HADOOP_HOME/sbin/stop-yarn.sh
$HADOOP_HOME/sbin/start-yarn.sh

# hack wait for datanode to be ready and happy and able
echo "sleep 10"
sleep 10

## Upload Sample Data
#######################

# upload sample files
samplefile=sample-statuses-20120906-141433-medium.avro
$HADOOP_HOME/bin/hdfs dfs -mkdir /indir
$HADOOP_HOME/bin/hdfs dfs -put $samplefile /indir/$samplefile


## Start Solr (2 nodes)
#######################

# stop solr nodes
echo "start solr nodes"
cd $SOLR_HOME/server2
java -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar --stop 1>stop.log 2>&1 &
cd $SOLR_HOME/server
java -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar --stop 1>stop.log 2>&1 &
sleep 5

echo "start solr node 1 (8983)"
cd $SOLR_HOME/server
java -Xmx512m -DzkRun -DnumShards=2 -Dsolr.directoryFactory=solr.HdfsDirectoryFactory -Dsolr.lock.type=hdfs -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr1 -Dsolr.hdfs.confdir=$HADOOP_CONF_DIR -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar 1>example.log 2>&1 &

echo "start solr node 2 (7574)"
cd $SOLR_HOME/server2
java -Xmx512m -Djetty.port=7574 -DzkHost=127.0.0.1:9983 -DnumShards=2 -Dsolr.directoryFactory=solr.HdfsDirectoryFactory -Dsolr.lock.type=hdfs -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr2 -Dsolr.hdfs.confdir=$HADOOP_CONF_DIR -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar 1>example2.log 2>&1 &

# wait for solr to be ready
echo "sleep 15"
sleep 15

cd $HOME

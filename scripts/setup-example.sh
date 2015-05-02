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

# Simulate disk for HDFS
#export HDFS_DISK=$HOME/hdfs_disk1
#mkdir -p $HDFS_DISK

#########################################################
# NameNode port        : 8020, 
# DataNode ports       : 50010, 50020
# ResourceManager port : 8032 
# ZooKeeper port       : 9983
# Solr port            : 8983
# NameNode web port    : 50070
# DataNodes web port   : 50075
#########################################################

## Get Hadoop
#############

# download hadoop
if [ ! -f "$HADOOP_DISTRIB.tar.gz" ]; then
    echo "Download Hadoop distribution $HADOOP_DISTRIB.tgz "
    curl -o $HADOOP_DISTRIB.tar.gz "$HADOOP_DISTRIB_URL" 
    if [[ $? -ne 0 ]]
    then
      echo "Failed to download hadoop at $HADOOP_DISTRIB"
      exit 1
    fi
else
    echo "hadoop distribution already exists"
fi

# extract hadoop
echo "Setup Hadoop distribution in $HADOOP_DISTRIB"
if [ -d "hadoop" ]; then
  rm hadoop
fi
if [ -d "$HADOOP_DISTRIB" ]; then
  rm -rf "$HADOOP_DISTRIB"
fi
if [ ! -d "$HADOOP_DISTRIB" ]; then
    tar -zxf "$HADOOP_DISTRIB.tar.gz"
    if [[ $? -ne 0 ]]
    then
      echo "Failed to extract hadoop from $HADOOP_DISTRIB.tar.gz"
      exit 1
    fi
    ln -s $HADOOP_DISTRIB hadoop
    mv $HOME/hadoop/etc/hadoop $HOME/hadoop/etc/hadoop.original
    cp -r $HOME/hadoop_conf/conf $HOME/hadoop/etc/hadoop
fi

# make the hadoop data dirs
if [ -d "hadoop-data" ]; then
    rm -rf hadoop-data
fi
mkdir hadoop-data
mkdir hadoop-data/hdfs_disk1
mkdir hadoop-data/tmp

## Get Solr
###########

# download solr
if [ ! -f "$SOLR_DISTRIB.tgz" ]; then
    echo "Download Solr distribution $SOLR_DISTRIB.tgz "
    curl -o $SOLR_DISTRIB.tgz "$SOLR_DISTRIB_URL"
    if [[ $? -ne 0 ]]
    then
      echo "Failed to download Solr at $SOLR_DISTRIB_URL"
      exit 1
    fi
else
    echo "solr distribution already exists"
fi

# extract solr
echo "Setup Solr distribution in $SOLR_DISTRIB"
if [ -d "solr" ]; then
  rm solr
fi
if [ -d "$SOLR_DISTRIB" ]; then
  rm -rf "$SOLR_DISTRIB"
fi
if [ ! -d "$SOLR_DISTRIB" ]; then
    tar -zxf "$SOLR_DISTRIB.tgz"
    if [[ $? -ne 0 ]]
    then
      echo "Failed to extract Solr from $SOLR_DISTRIB.tgz"
      exit 1
    fi
    ln -s $SOLR_DISTRIB solr
fi


## Start HDFS+YARN
##################

# start hdfs
echo "start hdfs"

echo "stop any running namenode"
$HADOOP_HOME/sbin/stop-dfs.sh

echo "format namenode"

$HADOOP_HOME/bin/hdfs namenode -format -force

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

# solr comes with collection1 preconfigured, so we juse use that rather than using 
# the collections api
cd solr
mv example server

echo "copy in twitter schema.xml file"
# pwd hack, because otherwise for some reasons the next cp command failed !!!
pwd
cp -f ../solr_conf/schema.xml server/solr/$COLLECTION/conf/schema.xml

# setting up a 2nd node
cp -rf server server2

# stop solr nodes
echo "start solr nodes"
cd server2
java -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar --stop 1>stop.log 2>&1 &
cd ../server
java -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar --stop 1>stop.log 2>&1 &
sleep 5

# Bootstrap config files to ZooKeeper
# unzip solr.war because solr was necver stared and so jar file are not available in server/solr-webapp/webapp
unzip -o server/webapps/solr.war -d server/solr-webapp/webapp
java -classpath "server/solr-webapp/webapp/WEB-INF/lib/*:server/lib/ext/*" org.apache.solr.cloud.ZkCLI -cmd bootstrap -zkhost 127.0.0.1:9983 -solrhome server/solr -runzk 8983
sleep 5

echo "start solr node 1 (8983)"
cd ../server
java -Xmx512m -DzkRun -DnumShards=2 -Dsolr.directoryFactory=solr.HdfsDirectoryFactory -Dsolr.lock.type=hdfs -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr1 -Dsolr.hdfs.confdir=$HADOOP_CONF_DIR -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar 1>example.log 2>&1 &

echo "start solr node 2 (7574)"
cd ../server2
java -Xmx512m -Djetty.port=7574 -DzkHost=127.0.0.1:9983 -DnumShards=2 -Dsolr.directoryFactory=solr.HdfsDirectoryFactory -Dsolr.lock.type=hdfs -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr2 -Dsolr.hdfs.confdir=$HADOOP_CONF_DIR -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar 1>example2.log 2>&1 &

# wait for solr to be ready
echo "sleep 15"
sleep 15

cd $HOME

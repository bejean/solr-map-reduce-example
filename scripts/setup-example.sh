#!/bin/bash

export HOME="$( cd "$( dirname "$0" )/.." && pwd )"

# Variables initialisation
. $HOME/scripts/setenv.sh
cd $HOME

## Solr + Hadoop Dists
#######################

# Using Hadoop 2.6.0
hadoop_version="2.6.0"
hadoop_distrib="hadoop-$hadoop_version"
hadoop_distrib_url="http://archive.apache.org/dist/hadoop/core/$hadoop_distrib/$hadoop_distrib.tar.gz"

# Using Solr 4.10.4
solr_version="4.10.4"
solr_distrib="solr-$solr_version"
solr_distrib_url="http://archive.apache.org/dist/lucene/solr/$solr_version/$solr_distrib.tgz"


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
if [ ! -f "$hadoop_distrib.tar.gz" ]; then
    echo "Download Hadoop distribution $hadoop_distrib.tgz "
    curl -o $hadoop_distrib.tar.gz "$hadoop_distrib_url" 
    if [[ $? -ne 0 ]]
    then
      echo "Failed to download hadoop at $hadoop_distrib"
      exit 1
    fi
else
    echo "hadoop distribution already exists"
fi

# extract hadoop
echo "Setup Hadoop distribution in $hadoop_distrib"
if [ -d "hadoop" ]; then
  rm hadoop
fi
if [ -d "$hadoop_distrib" ]; then
  rm -rf "$hadoop_distrib"
fi
if [ ! -d "$hadoop_distrib" ]; then
    tar -zxf "$hadoop_distrib.tar.gz"
    if [[ $? -ne 0 ]]
    then
      echo "Failed to extract hadoop from $hadoop_distrib.tar.gz"
      exit 1
    fi
    ln -s $hadoop_distrib hadoop
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
if [ ! -f "$solr_distrib.tgz" ]; then
    echo "Download Solr distribution $solr_distrib.tgz "
    curl -o $solr_distrib.tgz "$solr_distrib_url"
    if [[ $? -ne 0 ]]
    then
      echo "Failed to download Solr at $solr_distrib_url"
      exit 1
    fi
else
    echo "solr distribution already exists"
fi

# extract solr
echo "Setup Solr distribution in $solr_distrib"
if [ -d "solr" ]; then
  rm solr
fi
if [ -d "$solr_distrib" ]; then
  rm -rf "$solr_distrib"
fi
if [ ! -d "$solr_distrib" ]; then
    tar -zxf "$solr_distrib.tgz"
    if [[ $? -ne 0 ]]
    then
      echo "Failed to extract Solr from $solr_distrib.tgz"
      exit 1
    fi
    ln -s $solr_distrib solr
fi


# solr comes with collection1 preconfigured, so we juse use that rather than using 
# the collections api
cd $solr_distrib
mv example server

echo "copy in twitter schema.xml file"
cp -f solr_conf/schema.xml $solr_distrib/server/solr/collection1/conf/schema.xml

# setting up a 2nd node
cp -r -f server server2

# Bootstrap config files to ZooKeeper
java -classpath "server/solr-webapp/webapp/WEB-INF/lib/*:server/lib/ext/*" org.apache.solr.cloud.ZkCLI -cmd bootstrap -zkhost 127.0.0.1:9983 -solrhome server/solr -runzk 8983

cd server
java -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar --stop
java -Xmx512m -DzkRun -DnumShards=2 -Dsolr.directoryFactory=solr.HdfsDirectoryFactory -Dsolr.lock.type=hdfs -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr1 -Dsolr.hdfs.confdir=$hadoop_conf_dir -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar 1>example.log 2>&1 &

cd ../server2
java -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar --stop
java -Xmx512m -Djetty.port=7574 -DzkHost=127.0.0.1:9983 -DnumShards=2 -Dsolr.directoryFactory=solr.HdfsDirectoryFactory -Dsolr.lock.type=hdfs -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr2 -Dsolr.hdfs.confdir=$hadoop_conf_dir -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar 1>example2.log 2>&1 &



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

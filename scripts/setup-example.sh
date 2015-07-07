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

## Check working directory
##########################
if [ ! -d "$WORK_HOME" ]; then
  echo "$WORK_HOME doesn't exist. Stop !" 
  echo "Create it with appropriate read/write access." 
  exit 1
fi

if [ "$(ls -A $WORK_HOME)" ]; then
  echo "$WORK_HOME not empty. Stop !" 
  exit 1
fi

cp -r scripts $WORK_HOME/.

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
echo "Setup Hadoop distribution in $WORK_HOME/$HADOOP_DISTRIB"
tar -zxf "$HADOOP_DISTRIB.tar.gz" -C $WORK_HOME/.
if [[ $? -ne 0 ]]
then
  echo "Failed to extract hadoop from $HADOOP_DISTRIB.tar.gz to $WORK_HOME/$HADOOP_DISTRIB"
  exit 1
fi
ln -s $WORK_HOME/$HADOOP_DISTRIB $WORK_HOME/hadoop
mv $WORK_HOME/hadoop/etc/hadoop $WORK_HOME/hadoop/etc/hadoop.original
cp -r $HOME/hadoop_conf/conf $WORK_HOME/hadoop/etc/hadoop
sed -i -e "s|WORK_HOME|${WORK_HOME}|g" $WORK_HOME/hadoop/etc/hadoop/core-site.xml
sed -i -e "s|WORK_HOME|${WORK_HOME}|g" $WORK_HOME/hadoop/etc/hadoop/hdfs-site.xml

mkdir $WORK_HOME/hadoop-data
mkdir $WORK_HOME/hadoop-data/hdfs_disk1
mkdir $WORK_HOME/hadoop-data/tmp

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
echo "Setup Solr distribution in $WORK_HOME/$SOLR_DISTRIB"
tar -zxf "$SOLR_DISTRIB.tgz" -C $WORK_HOME/.
if [[ $? -ne 0 ]]
then
  echo "Failed to extract Solr from $SOLR_DISTRIB.tgz to $WORK_HOME/$SOLR_DISTRIB"
  exit 1
fi
ln -s $WORK_HOME/$SOLR_DISTRIB $WORK_HOME/solr

## Start HDFS+YARN
##################


#echo "stop any running namenode"
#$HADOOP_HOME/sbin/stop-dfs.sh

echo "format hdfs namenode"
$HADOOP_HOME/bin/hdfs namenode -format -force

# start hdfs
echo "start hdfs"
$HADOOP_HOME/sbin/start-dfs.sh

# start yarn
echo "start yarn"
$HADOOP_HOME/sbin/start-yarn.sh

# hack wait for datanode to be ready and happy and able
echo "Waiting HDFS and YARN start ..."
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
cd $SOLR_HOME
mv example server

# unzip solr.war because solr was necver stared and so jar file are not available in server/solr-webapp/webapp
unzip -o server/webapps/solr.war -d server/solr-webapp/webapp

echo "copy in twitter schema.xml file"
# pwd hack, because otherwise for some reasons the next cp command failed !!!
pwd
cp -f $HOME/solr_conf/schema.xml server/solr/$COLLECTION/conf/.
cp -f $HOME/solr_conf/set-map-reduce-classpath.sh server/scripts/map-reduce/.

# setting up a 2nd node
cp -rf server server2

# stop solr nodes
#echo "start solr nodes"
#cd $SOLR_HOME/server2
#java -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar --stop 1>stop.log 2>&1 &
#cd $SOLR_HOME/server
#java -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar --stop 1>stop.log 2>&1 &
#sleep 5

# Bootstrap config files to ZooKeeper
cd $SOLR_HOME
java -classpath "server/solr-webapp/webapp/WEB-INF/lib/*:server/lib/ext/*" org.apache.solr.cloud.ZkCLI -cmd bootstrap -zkhost 127.0.0.1:9983 -solrhome server/solr -runzk 8983
sleep 5

echo "start solr node 1 (8983)"
cd $SOLR_HOME/server
java -Xmx512m -DzkRun -DnumShards=2 -Dsolr.directoryFactory=solr.HdfsDirectoryFactory -Dsolr.lock.type=hdfs -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr1 -Dsolr.hdfs.confdir=$HADOOP_CONF_DIR -DSTOP.PORT=7983 -DSTOP.KEY=key -jar start.jar 1>example.log 2>&1 &

echo "start solr node 2 (7574)"
cd $SOLR_HOME/server2
java -Xmx512m -Djetty.port=7574 -DzkHost=127.0.0.1:9983 -DnumShards=2 -Dsolr.directoryFactory=solr.HdfsDirectoryFactory -Dsolr.lock.type=hdfs -Dsolr.hdfs.home=hdfs://127.0.0.1:8020/solr2 -Dsolr.hdfs.confdir=$HADOOP_CONF_DIR -DSTOP.PORT=6574 -DSTOP.KEY=key -jar start.jar 1>example2.log 2>&1 &

# wait for solr to be ready
echo "Waiting Solr nodes start ..."
sleep 15

cd $HOME

cp log4j.properties $WORK_HOME/.
cp readAvroContainer.conf $WORK_HOME/.

#--------------------
echo "HDFS, YARN and Solr nodes stated"
echo "Name node web interface available at http://localhost:50070/"
echo "Data node web interface available at http://localhost:50075/"
echo "Solr node 1 web interface available at http://localhost:8983/"
echo "Solr node 2 web interface available at http://localhost:7574/"


#!/bin/bash

export HOME="$( cd "$( dirname "$0" )/.." && pwd )"

# Variables initialisation
. $HOME/scripts/setenv.sh
cd $WORK_HOME

# 
## Build an index with map-reduce and deploy it to SolrCloud
#######################

source solr/server/scripts/map-reduce/set-map-reduce-classpath.sh

#echo "$HADOOP_CONF_DIR"
#echo "$SOLR_HOME/dist/"
#echo "$COLLECTION"
#echo "hadoop/bin/hadoop --config $HADOOP_CONF_DIR jar $SOLR_HOME/dist/solr-map-reduce-*.jar -D 'mapred.child.java.opts=-Xmx500m' -libjars '$HADOOP_LIBJAR' --morphline-file readAvroContainer.conf --zk-host 127.0.0.1:9983 --output-dir hdfs://127.0.0.1:8020/outdir --collection $COLLECTION --log4j log4j.properties --go-live --verbose 'hdfs://127.0.0.1:8020/indir'"

hadoop/bin/hadoop --config $HADOOP_CONF_DIR jar $SOLR_HOME/dist/solr-map-reduce-*.jar -D 'mapred.child.java.opts=-Xmx500m' -libjars "$HADOOP_LIBJAR" --morphline-file readAvroContainer.conf --zk-host 127.0.0.1:9983 --output-dir hdfs://127.0.0.1:8020/outdir --collection $COLLECTION --log4j log4j.properties --go-live --verbose "hdfs://127.0.0.1:8020/indir"

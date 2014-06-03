#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
this="${BASH_SOURCE-$0}"
bin=$(cd -P -- "$(dirname -- "$this")" && pwd -P)
script="$(basename -- "$this")"
this="$bin/$script"

export HIBENCH_VERSION="2.2"

export JAVA_HOME=/usr/java/default
export PATH=$PATH:$JAVA_HOME/bin
#export CLASSPATH=$CLASSPATH:.
alias scalac='/opt/toolchain/scala-2.10.3/bin/scalac'


###################### Global Paths ##################

export CDH_HOME=/opt/cloudera/parcels/CDH

export MR2=1

if [ $MR2 = "1" ]; then
  export HADOOP_HOME=$CDH_HOME/lib/hadoop-mapreduce #MR2
  export HADOOP_MAPRED_HOME=$CDH_HOME/lib/hadoop-mapreduce #MR2
  export HADOOP_EXAMPLES_JAR=$HADOOP_HOME/hadoop-mapreduce-examples.jar #MR2
  export HADOOP_CONF_DIR=/etc/hadoop/conf.cloudera.YARN-1
else 
  export HADOOP_HOME=$CDH_HOME/lib/hadoop-0.20-mapreduce #MR1  
  export HADOOP_MAPRED_HOME=$CDH_HOME/lib/hadoop-0.20-mapreduce
  export HADOOP_EXAMPLES_JAR=$HADOOP_HOME/hadoop-examples.jar #MR1
  export HADOOP_CONF_DIR=/etc/hadoop/conf.cloudera.MAPREDUCE-1
fi

export HADOOP_EXECUTABLE=/usr/bin/hadoop
export HIBENCH_HOME=/var/lib/jenkins/HiBench
export HIBENCH_CONF=$HIBENCH_HOME/conf

export HIVE_HOME=`printenv HIVE_HOME`
export MAHOUT_HOME=`printenv MAHOUT_HOME`
export NUTCH_HOME=`printenv NUTCH_HOME`
export DATATOOLS=`printenv DATATOOLS`


echo HADOOP_EXECUTABLE=${HADOOP_EXECUTABLE:? "ERROR: Please set paths in $this before using HiBench."}
echo HADOOP_CONF_DIR=${HADOOP_CONF_DIR:? "ERROR: Please set paths in $this before using HiBench."}
echo HADOOP_EXAMPLES_JAR=${HADOOP_EXAMPLES_JAR:? "ERROR: Please set paths in $this before using HiBench."}

if [ -z "$HIBENCH_HOME" ]; then
    export HIBENCH_HOME=`dirname "$this"`/..
fi

if [ -z "$HIBENCH_CONF" ]; then
    export HIBENCH_CONF=${HIBENCH_HOME}/conf
fi


if [ -f "${HIBENCH_CONF}/funcs.sh" ]; then
    . "${HIBENCH_CONF}/funcs.sh"
fi

if [ -z "$HIVE_HOME" ]; then
    #export HIVE_HOME=${HIBENCH_HOME}/common/hive-0.9.0-bin
    export HIVE_HOME=$CDH_HOME/lib/hive
fi


if $HADOOP_EXECUTABLE version|grep -i -q cdh4; then
	HADOOP_VERSION=cdh4
else if $HADOOP_EXECUTABLE version|grep -i -q cdh5; then
	HADOOP_VERSION=cdh5
  else 
	HADOOP_VERSION=hadoop1
  fi
fi

if [ -z "$MAHOUT_HOME" ]; then
    export MAHOUT_HOME=${HIBENCH_HOME}/common/mahout-distribution-$HADOOP_VERSION
fi

#export MAHOUT_HOME=/opt/cloudera/parcels/CDH/lib/mahout
echo $MAHOUT_HOME

if [ -z "$NUTCH_HOME" ]; then
    export NUTCH_HOME=${HIBENCH_HOME}/nutchindexing/nutch-1.2-$HADOOP_VERSION
fi


if [ -z "$DATATOOLS" ]; then
    export DATATOOLS=${HIBENCH_HOME}/common/autogen/dist/datatools.jar
fi

if [ $# -gt 1 ]
then
    if [ "--hadoop_config" = "$1" ]
          then
              shift
              confdir=$1
              shift
              HADOOP_CONF_DIR=$confdir
    fi
fi
HADOOP_CONF_DIR="${HADOOP_CONF_DIR:-$HADOOP_HOME/conf}"

# base dir HDFS
#export DATA_HDFS=HiBench
export DATA_HDFS=/user/jenkins/HiBench

# local report
if [ $MR2 = "0" ]; then
  export HIBENCH_REPORT=${HIBENCH_HOME}/hibench_MR1.report
else
  export HIBENCH_REPORT=${HIBENCH_HOME}/hibench_MR2.report
fi

################# Compress Options #################
# swith on/off compression: 0-off, 1-on
export COMPRESS_GLOBAL=1
export COMPRESS_CODEC_GLOBAL=org.apache.hadoop.io.compress.DefaultCodec
#export COMPRESS_CODEC_GLOBAL=com.hadoop.compression.lzo.LzoCodec
#export COMPRESS_CODEC_GLOBAL=org.apache.hadoop.io.compress.SnappyCodec

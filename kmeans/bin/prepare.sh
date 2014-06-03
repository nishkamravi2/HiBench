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
set -u 

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

echo "========== preparing kmeans data =========="
# configure
DIR=`cd $bin/../; pwd`
. "${DIR}/../bin/hibench-config.sh"
. "${DIR}/conf/configure.sh"


# compress check
if [ $COMPRESS -eq 1 ]; then
    COMPRESS_OPT="-compress true \
        -compressCodec $COMPRESS_CODEC \
        -compressType BLOCK "
else
    COMPRESS_OPT="-compress false"
fi

# paths check
$HADOOP_EXECUTABLE fs -rm -r -skipTrash ${INPUT_HDFS}

# generate data

echo $MAHOUT_HOME

OPTION="-sampleDir ${INPUT_SAMPLE} -clusterDir ${INPUT_CLUSTER} -numClusters ${NUM_OF_CLUSTERS} -numSamples ${NUM_OF_SAMPLES} -samplesPerFile ${SAMPLES_PER_INPUTFILE} -sampleDimension ${DIMENSIONS}"
export HADOOP_CLASSPATH=`${MAHOUT_HOME}/bin/mahout classpath | tail -1`

export HADOOP_CLASSPATH=$HADOOP_CLASSPATH:${HIBENCH_HOME}/common/autogen/lib/uncommons-maths-1.2.2.jar


#exec "$HADOOP_EXECUTABLE" --config $HADOOP_CONF_DIR jar ${DATATOOLS} org.apache.mahout.clustering.kmeans.GenKMeansDataset -libjars /var/lib/jenkins/HiBench/common/mahout-distribution-0.7-hadoop1/examples/target/mahout-examples-0.7-job.jar ${COMPRESS_OPT} ${OPTION}

#exec "$HADOOP_EXECUTABLE" --config $HADOOP_CONF_DIR jar ${DATATOOLS} org.apache.mahout.clustering.kmeans.GenKMeansDataset -libjars /opt/cloudera/parcels/CDH/lib/mahout/mahout-examples-0.9-cdh5.1.0-SNAPSHOT-job.jar,${HIBENCH_HOME}/common/autogen/lib/uncommons-maths-1.2.2.jar  ${COMPRESS_OPT} ${OPTION}


echo "$HADOOP_EXECUTABLE" --config $HADOOP_CONF_DIR jar ${DATATOOLS} org.apache.mahout.clustering.kmeans.GenKMeansDataset -libjars ${HIBENCH_HOME}/common/mahout-distribution-cdh5/examples/target/mahout-examples-0.9-cdh5.1.0-SNAPSHOT-job.jar,${HIBENCH_HOME}/common/autogen/lib/uncommons-maths-1.2.2.jar ${COMPRESS_OPT} ${OPTION}

exec "$HADOOP_EXECUTABLE" --config $HADOOP_CONF_DIR jar ${DATATOOLS} org.apache.mahout.clustering.kmeans.GenKMeansDataset -libjars ${HIBENCH_HOME}/common/mahout-distribution-cdh5/examples/target/mahout-examples-0.9-cdh5.1.0-SNAPSHOT-job.jar,${HIBENCH_HOME}/common/autogen/lib/uncommons-maths-1.2.2.jar ${COMPRESS_OPT} ${OPTION}




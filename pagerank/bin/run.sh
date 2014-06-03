h
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

echo "========== running pagerank bench =========="
# configure
DIR=`cd $bin/../; pwd`
. "${DIR}/../bin/hibench-config.sh"
. "${DIR}/conf/configure.sh"

# compress check

if [ $MR2 = 0 ]; then
 if [ $COMPRESS -eq 1 ]
 then
    COMPRESS_OPT="-Dmapred.output.compress=true \
    -Dmapred.output.compression.codec=$COMPRESS_CODEC"
 else
    COMPRESS_OPT="-Dmapred.output.compress=false"
 fi
else
 if [ $COMPRESS -eq 1 ]
 then
    COMPRESS_OPT="-Dmapreduce.output.fileoutputformat.compress=true \
    -Dmapreduce.output.fileoutputformat.compress.codec=$COMPRESS_CODEC"
 else
    COMPRESS_OPT="-Dmapreduce.output.fileoutputformat.compress=false"
 fi
fi

# path check
$HADOOP_EXECUTABLE fs -rm r -skipTrash $OUTPUT_HDFS

# pre-running
if [ $MR2 = 0 ]; then
 VSIZE=$($HADOOP_EXECUTABLE job -history $INPUT_HDFS/vertices | grep 'HiBench.Counters.*|BYTES_DATA_GENERATED')
 VSIZE=${VSIZE##*|}
 VSIZE=${VSIZE//,/}

 ESIZE=$($HADOOP_EXECUTABLE job -history $INPUT_HDFS/edges | grep 'HiBench.Counters.*|BYTES_DATA_GENERATED')
 ESIZE=${ESIZE##*|}
 ESIZE=${ESIZE//,/}

 SIZE=$((VSIZE+ESIZE))
fi

if [ $BLOCK -eq 0 ]
then
    OPTION="${COMPRESS_OPT} ${INPUT_HDFS}/edges ${OUTPUT_HDFS} ${PAGES} ${NUM_REDS} ${NUM_ITERATIONS} nosym new"
else
    OPTION="${COMPRESS_OPT} ${OUTPUT_HDFS} ${PAGES} ${NUM_REDS} ${NUM_ITERATIONS} ${BLOCK_WIDTH}"
fi

START_TIME=`timestamp`

# run bench
if [ $BLOCK -eq 0 ]
then
    $HADOOP_EXECUTABLE jar ${DIR}/pegasus-2.0.jar pegasus.PagerankNaive $OPTION
    
else
    $HADOOP_EXECUTABLE jar ${DIR}/pegasus-2.0.jar pegasus.PagerankInitVector ${COMPRESS_OPT} ${OUTPUT_HDFS}/pr_initvector ${PAGES} ${NUM_REDS}
    result=$?
    if [ $result -ne 0 ]
    then
	echo "ERROR: Hadoop job failed to run successfully." 
	exit $result
    fi

    $HADOOP_EXECUTABLE fs -rm -r -skipTrash ${OUTPUT_HDFS}/pr_input
    $HADOOP_EXECUTABLE fs -rm -r -skipTrash ${OUTPUT_HDFS}/pr_iv_block

    $HADOOP_EXECUTABLE jar ${DIR}/pegasus-2.0.jar pegasus.matvec.MatvecPrep ${COMPRESS_OPT} ${OUTPUT_HDFS}/pr_initvector ${OUTPUT_HDFS}/pr_iv_block ${PAGES} ${BLOCK_WIDTH} ${NUM_REDS} s makesym
    result=$?
    if [ $result -ne 0 ]
    then
        echo "ERROR: Hadoop job failed to run successfully."
        exit $result
    fi

    $HADOOP_EXECUTABLE fs -rm -r -skipTrash ${OUTPUT_HDFS}/pr_initvector
    $HADOOP_EXECUTABLE fs -rm -r -skipTrash ${OUTPUT_HDFS}/pr_edge_colnorm

    $HADOOP_EXECUTABLE jar ${DIR}/pegasus-2.0.jar pegasus.PagerankPrep ${COMPRESS_OPT} ${INPUT_HDFS}/edges ${OUTPUT_HDFS}/pr_edge_colnorm ${NUM_REDS} makesym
    result=$?
    if [ $result -ne 0 ]
    then
        echo "ERROR: Hadoop job failed to run successfully."
        exit $result
    fi

    $HADOOP_EXECUTABLE fs -rm -r -skipTrash ${OUTPUT_HDFS}/pr_edge_block
    
    $HADOOP_EXECUTABLE jar ${DIR}/pegasus-2.0.jar pegasus.matvec.MatvecPrep ${COMPRESS_OPT} ${OUTPUT_HDFS}/pr_edge_colnorm ${OUTPUT_HDFS}/pr_edge_block ${PAGES} ${BLOCK_WIDTH} ${NUM_REDS} null nosym
    result=$?
    if [ $result -ne 0 ]
    then
        echo "ERROR: Hadoop job failed to run successfully."
        exit $result
    fi

    $HADOOP_EXECUTABLE fs -rm -r -skipTrash ${OUTPUT_HDFS}/pr_edge_colnorm

    $HADOOP_EXECUTABLE jar ${DIR}/pegasus-2.0.jar pegasus.PagerankBlock ${OPTION}
    result=$?
    if [ $result -ne 0 ]
    then
        echo "ERROR: Hadoop job failed to run successfully."
        exit $result
    fi
fi

# post-running
END_TIME=`timestamp`

if [ $MR2 = 0 ]; then 
 gen_report "PAGERANK" ${START_TIME} ${END_TIME} ${SIZE}
else
 gen_report2 "PAGERANK" ${START_TIME} ${END_TIME}
fi

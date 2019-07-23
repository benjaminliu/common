#!/bin/bash

#修改成jar的文件名，不包含后面的.jar
APP_NAME=service1

#active的profile
PROFILE=prod

#最小堆
XMS=512m

#最大堆
XMX=512m

#线程栈大小
XSS=256k

#MetaspaceSize
META=256m

#MaxMetaspaceSize
MAXMETA=256m

#所用版本的java的bin文件夹全路径,不包含java
JAVABIN=/usr/jdk1.8.0_121/bin

#-----------------------------------下面的基本不用修改--------------------------------------

#jar名
JAR_FILE=$APP_NAME.jar

#当前时间戳
DATESTR=`date +%F.%H%M%S`

#取运行脚本的绝对路径
BIN_HOME=$(dirname $(readlink -f $0))

#上一层目录路径
PARENT=$BIN_HOME/..

#创建GC_LOG_HOME文件夹
GC_LOG_HOME=$BIN_HOME/gclog
if [ ! -d "$GC_LOG_HOME" ];then
  mkdir $GC_LOG_HOME
fi

#创建dump文件夹
DUMP_HOME=$PARENT/dump
if [ ! -d "$DUMP_HOME" ];then
  mkdir $DUMP_HOME
fi

#创建bak文件夹
BAK_HOME=$PARENT/bak
if [ ! -d "$BAK_HOME" ];then
  mkdir $BAK_HOME
fi

#找到java的路径
if [ ! -d "$JAVABIN" ];then
    JAVA_EXE=java
else
    JAVA_EXE=$JAVABIN/java
fi


#JVM参数
JVM_OPTS="-XX:+UseConcMarkSweepGC -XX:CMSInitiatingOccupancyFraction=75 -XX:+UseCMSInitiatingOccupancyOnly ${JVM_OPTS}"
JVM_OPTS="-Xloggc:${GC_LOG_HOME}/gc-${DATESTR}.log -XX:-PrintGCDetails -XX:+PrintGCDateStamps -XX:-PrintTenuringDistribution ${JVM_OPTS}"
JVM_OPTS="-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${DUMP_HOME} ${JVM_OPTS}"
JVM_OPTS="-XX:-UseGCOverheadLimit -XX:-OmitStackTraceInFastThrow ${JVM_OPTS}"
JVM_OPTS="-XX:+AlwaysPreTouch -XX:-UseBiasedLocking -XX:AutoBoxCacheMax=20000 ${JVM_OPTS}"
JVM_OPTS="-Xss${XSS} -Xms${XMS} -Xmx${XMX} -XX:MetaspaceSize=${META} -XX:MaxMetaspaceSize=${MAXMETA} ${JVM_OPTS}"
JVM_OPTS="-Dloader.path=. ${JVM_OPTS}"

#开始运行
start(){
  checkpid
  if [ ! -n "$pid" ]; then
    echo $JVM_OPTS
    echo "$APP_NAME starting..."
    nohup $JAVA_EXE -jar $JVM_OPTS $JAR_FILE  --spring.profiles.active=$PROFILE >/dev/null 2>$BIN_HOME/error.log &
    sleep 1s
    status
    echo "--------"
    echo "$APP_NAME started"
  else
      echo "$APP_NAME is runing, PID: $pid"   
  fi
}

#停止进程
stop(){
    checkpid
    if [ ! -n "$pid" ]; then
     echo "$APP_NAME is not runing"
    else
      echo "$APP_NAME stoping..."
      kill -9 $pid
      echo "$APP_NAME stopped"
    fi 
}

#重启进程
restart(){
    stop 
    sleep 1s
    start
}

status(){
   checkpid
   if [ ! -n "$pid" ]; then
     echo "$APP_NAME not runing"
   else
     echo "$APP_NAME is runing at PID: $pid"
   fi 
}

#拷贝bin文件夹
backup(){
    NEW_BAK=$BAK_HOME/$DATESTR

    mkdir $NEW_BAK

    cp ./* $NEW_BAK
}

#dump内存
dump(){
    checkpid
    jmap -dump:format=b,file=$DUMP_HOME/$APP_NAME.$DATESTR.hprof $pid
}

#检查进程是否已经运行
checkpid(){
    pid=`ps -ef |grep $JAR_FILE |grep -v grep |awk '{print $2}'`
}

#如果输入第一个参数，就执行第一个参数，否则执行restart
if [ ! -n "$1" ]; then
	echo "restating..."
	restart
else
  case $1 in  
    start) start;;  
    stop) stop;; 
    restart) restart;;  
    status) status;;
    backup) backup;;
    dump) dump;;
    *) echo "restart.sh {start|stop|restart|status|backup|dump}";;
  esac 
fi 
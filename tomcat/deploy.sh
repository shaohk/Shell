#!/bin/bash
#para:
#	$1:type 	--- app\weixin
#	$2 version	--- git_commit_number	
#	$3 NodeList	--- tomcat NodeList


source /etc/profile

[ $1'x' = 'x' ] && echo "TYPE is null" && exit 1
TYPE=$1
shift
[ $1'x' = 'x' ] && echo "VER is null" && exit 1
VER=$1
shift
[ $# = 0 ] && echo "NodeList is null" && exit 1

SALTROOT=/mysqldata/saltdata
BASEDIR=$SALTROOT/tomcat
HISDIR=$BASEDIR/history

function deploy()
{
	# $1 节点名称
	# $2 WAR包
	# $3 应用类型app\weixin
	TOMCAT_HOME="/opt/tomcat8080"

	MD=`/usr/bin/md5sum $HISDIR/$TYPE/$2 | awk '{print $1}'`

	if [ ! `salt $1 cmd.run "ps -ef | grep tomcat | grep -v grep" | grep -o " tomcat "` ]
	then
		echo $1 tomcat is not running
	else	
		salt $1 cmd.run "ps -ef | grep tomcat | grep -v grep | awk '{print \$2}' | xargs kill"
	fi

	i=0	
	while [ `salt $1 cmd.run "ps -ef | grep tomcat | grep -v grep" | grep -o " tomcat "` ]
	do
		let "i=i+1"
		echo "tomcat is stail runing...."
		sleep 2
		if [ $i = 5 ]
		then
			salt $1 cmd.run "ps -ef | grep tomcat | grep -v grep | awk '{print \$2}' | xargs kill -9"
		fi
	done

	salt $1 cmd.run "rm -rf $TOMCAT_HOME/webapps/ROOT*"
	#拷贝本地WAR包到minion机器上
	salt $1 cp.get_file "salt://tomcat/history/$3/$2" $TOMCAT_HOME/webapps/$2

	if [ ! `salt $1 file.check_hash $TOMCAT_HOME/webapps/$2 md5:$MD | grep True` ];
	then
		salt $1 cp.get_file "salt://tomcat/history/$3/$2" $TOMCAT_HOME/webapps/$2
		if [ ! `salt $1 file.check_hash $TOMCAT_HOME/webapps/$2 md5:$MD | grep True` ];
		then
			echo "the WAR package's MD5 is error"
			exit 1
		fi
	fi

	#启动minion上tomcat服务
	salt $1 cmd.run "chown -R tomcat.tomcat $TOMCAT_HOME"
	salt $1 cmd.run "su - tomcat -c '$TOMCAT_HOME/bin/startup.sh'"
	sleep 20
}

if [ $VER'x' = newx ]
then
	if [ -f $BASEDIR/app/$TYPE/ROOT*.war ]
	then
		[ -d $HISDIR/$TYPE ] || mkdir $HISDIR/$TYPE
		version=`ls $BASEDIR/app/$TYPE/`
		version=${version#ROOT-}
		version=${version:0:8}
		mv -f $BASEDIR/app/$TYPE/ROOT*.war $HISDIR/$TYPE/ROOT##$version.war
		for node in $@
		do
			deploy $node ROOT##$version.war $TYPE
		done
		[ `ls -l $HISDIR/$TYPE | wc -l` = '11' ] && ls -l -t $HISDIR/$TYPE | awk 'NR==11 {print $9}' | xargs -I {} rm -rf $1/{}
		exit 0
	else 
		echo "NO WAR PACKAGE"
	fi
	
else
	[ -f $BASEDIR/app/$TYPE/ROOT*.war ] && rm -rf $BASEDIR/app/$TYPE/ROOT*.war
	version=${VER:0:8}
	if [ ! -f $HISDIR/$TYPE/ROOT##$version.war ]
	then
		echo the version $VER is not exist && exit 1
	fi
	for node in $@
	do
		echo $node
		deploy $node ROOT##$version.war $TYPE
	done
fi


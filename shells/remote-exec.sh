#!/bin/bash --login
if [ $# -eq 0 ]
then
    echo "参数不存在，第一个参数为需要执行的主机序号(空格分割)，第二个是需要执行该命令的用户，第三个是需要执行的命令"
	echo "例子：remote-exec.sh \"1 2 3\" \"root\" \"ls -l /app\""
else
	for i in $1
	  do 
		ssh $2@hadoop$i $3
		echo ------hadoop$i-----done
	done
fi


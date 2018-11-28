# CDH6 deployment cluster manual
## 环境准备
### 配置阿里云yum源
参看  
https://opsx.alibaba.com/mirror
### 关闭防火墙与SELINUX
`systemctl stop firewalld.service`  
`systemctl disable firewalld.service`  
`setenforce 0`
修改/etc/selinux/config 文件，SELINUX=disabled  
### 配置host
`vim /etc/hosts`
### 配置SSH免密
生成秘钥
`ssh-keygen -t rsa -P ''`
将公钥发送到集群其他节点
for i in {101..103}; do ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.$i;done
### 配置时间同步NTP服务
#### 主节点用作NTP同步服务器
修改`/etc/ntp.conf`文件
```
driftfile /var/lib/ntp/drift
restrict 127.0.0.1
restrict -6 ::1
restrict default nomodify notrap
server ntp1.aliyun.com prefer
minpoll 6
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys 
```
启动ntp服务`systemctl start ntpd`
#### 其他节点同步主节点服务器时间
同样修改ntp.conf文件
```
driftfile /var/lib/ntp/drift
restrict 127.0.0.1
restrict -6 ::1
restrict default kod nomodify notrap nopeer noquery
restrict -6 default kod nomodify notrap nopeer noquery
#这里是主节点的主机名或者ip
server cdh-master.test.com
minpoll 6
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
```
ok保存退出，请求服务器前，请先使用ntpdate手动同步一下时间：ntpdate -u 192.168.101 (主节点ntp服务器).  
### 禁用透明大页面压缩
`echo never > /sys/kernel/mm/transparent_hugepage/defrag`  
`echo never > /sys/kernel/mm/transparent_hugepage/enabled`  
并将上面的两条命令写入开机自启动  
`vim /etc/rc.local`
### 优化交换分区
```
vim /etc/sysctl.conf
vm.swappiness = 10
sysctl -p /etc/sysctl.conf
```
## 文件准备 prepare package
### Cloudera Manager 6.0.0
https://archive.cloudera.com/cm6/6.0.0/redhat7/
yum/RPMS/x86_64/  
所需文件 
cloudera-manager-agent-6.0.0-530873.el7.x86_64.rpm  
cloudera-manager-daemons-6.0.0-530873.el7.x86_64.rpm  
cloudera-manager-server-6.0.0-530873.el7.x86_64.rpm  
cloudera-manager-server-db-2-6.0.0-530873.el7.x86_64.rpm  
### CDH 6.0.0
https://archive.cloudera.com/cdh6/6.0.0/parcels/
所需文件：  
CDH-6.0.0-1.cdh6.0.0.p0.537114-el7.parcel  
CDH-6.0.0-1.cdh6.0.0.p0.537114-el7.parcel.sha256  
manifest.json  
## 卸载openJDK 安装OracleJDK
`rpm -qa | grep java-1. | xargs -I {} rpm -e --nodeps {}`
### 下载jdk rpm包
https://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html  
安装  
rpm -ivh jdk-8u191-linux-x64.rpm  
将`export JAVA_HOME=/usr/java/latest`写入`/etc/profile`的最后一行并执行`source /etc/profile`  
注：如果是安装的解压版，jdk路径必须是`/usr/java/`  
## 安装MySQL
### 推荐使用yum源进行安装  
https://dev.mysql.com/downloads/repo/yum/  
下载好RPM包后  
`rpm -Uvh mysql80-community-release-el6-n.noarch.rpm`  
对于不同版本(例：使用5.7版本)  
`yum-config-manager --disable mysql80-community`  
`yum-config-manager --enable mysql57-community`  
`yum install -y mysql-community-server`  
### 启动MySQL服务  
`systemctl start mysqld`  
### 启动成功后，使用该命令查看临时密码  
`grep 'temporary password' /var/log/mysqld.log`  
### 登录MySQL  
`mysql -uroot -p` 然后输入刚才得到的密码即可  
### 修改密码  
`set password=PASSWORD('XXX')` 或 `ALTER USER 'root'@'localhost' IDENTIFIED BY 'xxx';`
### 安装MySQL jdbc Driver
`wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz`
### 解压后将jar包放入/usr/share/java中
`tar zxvf mysql-connector-java-5.1.46.tar.gz`  
`mkdir -p /usr/share/java/`  
`cd mysql-connector-java-5.1.46`  
`cp mysql-connector-java-5.1.46-bin.jar /usr/share/java/mysql-connector-java.jar`  
注：因为cloudera-manager需要这个driver，并且指定了driver存放路径是`/usr/share/java`  
### 创建必要的数据库
```
create database scm default character set utf8 default collate utf8_general_ci;
create database amon default character set utf8 default collate utf8_general_ci;
create database rman default character set utf8 default collate utf8_general_ci;
create database hue default character set utf8 default collate utf8_general_ci;
create database metastore default character set utf8 default collate utf8_general_ci;
create database sentry default character set utf8 default collate utf8_general_ci;
create database nav default character set utf8 default collate utf8_general_ci;
create database oozie default character set utf8 default collate utf8_general_ci;
flush privileges;
```
## 安装 Cloudera Manager
新建/opt/cloudera目录  
使用rpm -ivh 包名 安装之前下载的rpm文件，daemon -> server -> server-db -> agent  . 期间会提示缺少某些依赖，可根据提示，使用yum进行安装
完毕后，执行`/opt/cloudera/cm/schema/scm_prepare_database.sh <databaseType> <databaseName> <databaseUser>  <datapasswd>`，会生成/etc/cloudera-scm-server/db.properties,里面是数据库的连接信息，如果这个文件有误，或者不存在，后面的服务无法启动。如果数据库连接有误，可以手动修改db.properties这个文件。
  
将之前下载的CDH-6.0.0-1.cdh6.0.0.p0.537114-el7.parcel包 放入/opt/cloudera/parcel-repo/目录中，并将sha256后缀改成sha  
注意：这点必须注意，否则系统会重新下载CDH-6.0.0-1.cdh6.0.0.p0.537114-el7.parcel文件。
重要！--->在manifest.json文件中，找到对应版本的hash，复制到.sha文件中。如果manifest.json文件中hash错误，系统也会重新下载CDH包。因为sha256里面存的数文件的sha256，而manifest.json里面存的是hash(sha1)，所以不能直接匹配，sha1可以使用sha1sum来计算生成。
### 启动 Cloudera Manager
先给相关目录赋权  
chown cloudera-scm:cloudera-scm  /opt/cloudera/ -R  
chown cloudera-scm:cloudera-scm  /var/log/cloudera-scm-agent -R  
启动`systemctl start cloudera-scm-server`
可以查看启动日志  
`tail -f /var/log/cloudera-scm-server/cloudera-scm-server.log`  
看到此条信息，说明启动完成  
`INFO WebServerImpl:com.cloudera.server.cmf.WebServerImpl: Started Jetty server.`
### CDH 安装 
此步开始进入图形化安装，按照操作提示安装即可
## CDH 安装遇到的问题
### Can't open /var/run/cloudera-scm-agent/process/94-yarn-JOBHISTORY/supervisor_status: 权限不够
如遇到 `Can't open /var/run/cloudera-scm-agent/process/94-yarn-JOBHISTORY/supervisor_status: 权限不够`类似的错误，可以去`/var/log/`下查看日志去查找真正的错误，CM上报的错一般不是真实的错误信息
  
### the last packet sent successfully to the server was 0 milliseconds ago
数据库地址的问题，可以手动修改db.properties中的数据库连接信息。
### 一些Hbase，yarn,无法启动
有可能是没有HDFS的写入权限

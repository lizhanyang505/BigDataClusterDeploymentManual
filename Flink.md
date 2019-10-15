# Flink集群搭建(Standalone)
## Prepare
下载Flink: [Flink-scala_2.11](https://www.apache.org/dyn/closer.lua/flink/flink-1.9.0/flink-1.9.0-bin-scala_2.11.tgz)  
下载hadoop-prebuild(hadoop-2.7.5): [PreBuild-hadoop-2.7.5](https://repo.maven.apache.org/maven2/org/apache/flink/flink-shaded-hadoop-2-uber/2.7.5-7.0/flink-shaded-hadoop-2-uber-2.7.5-7.0.jar)  
## Configuration
### 配置flink-conf.yaml
指定java路径，此处配置可以便于在多java版本中运行适合Flink的java版本  
`env.java.home: /path/to/java`  
  
指定Flink运行日志存储目录  
`env.log.dir: /path/to/log`  
  
(standalone运行模式)指定jobmanager rpc访问地址  
`jobmanager.rpc.address: 192.168.1.2`  
  
(standalone运行模式)指定jobmanager rpc访问端口  
`jobmanager.rpc.port: 6123`  
  
指定jobmanger 堆内存    
`jobmanager.heap.size: 2048m`  
  
指定完成的job日志存储目录(支持写到hdfs，如果写到本地，则以file://开头)  
`jobmanager.archive.fs.dir: file:///app/log/flink/jobStore`   
  
指定已完成job过期时间(已完成job会在默认1个小时后过期，即在ui界面中看不见)   
`jobstore.expiration-time: 604800`  
  
指定Flink web UI界面访问端口  
`rest.port: 4048`  
  
指定web ui界面上展示的job数  
`web.history: 20`  
  
指定taskmanager 堆内存(此内存所有slot共享)  
`taskmanager.heap.size: 2048m`  
  
指定该taskmanager有多少个slot可用  
`taskmanager.numberOfTaskSlots: 4`  
  
指定默认并行度(并行度优先级：代码中的setParallelism > 启动时设置的 > 配置默认)  
`parallelism.default: 1`  
  
指定task错误时，其他task的重试策略
`jobmanager.execution.failover-strategy: region`  
full: 当出现错误恢复的时候，所有task都会重启  
region: 只有受失败task影响的task会重启  
  
指定能从web ui 提交任务(从webui提交的任务与命令有略微不同，不同点在于job执行完之后，web方式提交的不会执行execute之后的代码，而命令行的会)
`web.submit.enable: true`
  
### 配置master文件
用于指定哪台机器要启动jobmanager  
添加`192.168.1.2:4048`有多个jobmanager可以继续添加，一行一个  
### 配置slaves文件
用于指定哪台机器要启动taskmanager  
```
192.168.1.2
192.168.1.3
192.168.1.4
192.168.1.5
```
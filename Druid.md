#Druid 中数据的获取
## 以pull方式获取
以该方式获取需要启动druid中的实时节点(realtime Nodes)，在启动节点的过程中需要配置数据摄取的相关参数，在druid中这个配置文件名为Ingestion Spec  
### Ingestion Spec 配置文件数据结构
该配置文件是一个**JSON文本**，由三部分组成
1. **dataSchema** 是一个JSON对象，指明数据源格式、数据解析、维度等信息
2. **ioConfig** JSON对象，指明数据如何在Druid中储存
3. **tuningConfig**JSON对象，指明存储优化配置
#### dataSchema 
包含了数据类型，数据由哪些列构成，以及哪些是指标列，哪些是维度列
1. datasource：string类型，数据源名字
2. parser：JSON对象，包含了如何解析数据的相关内容
3. metricsSpec：list包含了所有的指标列信息
4. granularity：json对象，指明了数据的存储和查询粒度

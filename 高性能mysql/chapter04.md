# 第四章 schema与数据类型优化

## 4.1 选择优化的数据类型
1. 更小的通常更好
2. 简单就好
3. 尽量避免NULL
    - 可为NULL的列使得索引, 索引统计和值比较都更复杂;
    - 可为NULL的列会使用更多的存储空间
    - 当可为NULL的列被索引时, 每个索引记录需要一个额外的字节;
    - 通常把NULL编程NOT NULL带来的性能提升比较小, 但是, 如果计划在列上建索引, 就应该尽量避免设计成可NULL的列
    - 例外: InnoDB使用单独的位(bit)存储BULL值, 所以对于稀疏数据有很好的空间效率, 但这一点不适用于MyISAM;

### 4.1.1 整数类型
- tinyint, smallint, mediumint, int, bigint分别使用8,16,24,32,,64为存储空间;
- mysql 可以为整数类型制定宽度, 例如int(11), int(20), 对大多数应用没有意义, 只不过规定了mysql的交互工具用来显示字符的个数;

### 4.1.2 实数类型
- float 4字节, double八字节;
- decimal 用于存储精确的小数,MySQL5.0和更高的版本中,最高允许65个数字, 将数字打包保存到一个二进制字符串中,例如,decimal(18, 9)小数点两边个存储9个数字, 一共9字节,小数点前后各占4个字节, 小数点本身占1个字节;

### 4.1.3 字符串类型
1. varchar和char, 很难精确地解释这些值是怎么样存储在磁盘和内存中的, 因为这跟存储引擎的具体实现有关, 下面的描述假设使用的存储引擎是InnoDB或者MyISAM;

(1) varchar:
- varchar 比char更节省空间, 除非MySQL表使用row_format=fixed;
- varchar 需要使用1或者2个额外字节记录字符串长度: 如果列的最大长度<=255, 则使用一字节,否则使用两字节,例如:
~~~
假设采用latin1字符集;
varchar(10)需要11个字节的存储空间;
varchar(1000)需要1002个字节;
~~~
- 适用场景:
~~~
a. 字符串列的最大长度比平均长度大很多;
b. 列的更新很少, 所以碎片不成问题;
c. 使用了像utf-8这样复杂的字符集;
~~~

(2). char
- 存储char时会删除所有的末尾空格;
- 适用场景:
~~~
a. 适合存储很短的字符串, 或者长度接近的, 例如md5值;
b. 经常变更的数据;
c. 非常短的列
~~~

2.BLOB和TEXT类型
- BLOB和TEXT都是为了存储很大的数据而设计的字符串数据类型, 分别采用二进制和字符方式存储;
- 差别:
    
    (1). BLOB存储的是二进制数据, 没有排序规则或字符集, 而TEXT有字符集和排序规则;
- 使用枚举代替字符串类型:
    
    (1). 枚举列可以把一些不重复的字符串存储成一个预定义的集合, 会根据列表值的数量压缩到1或者连2个字节中, MySQL会在内部将每个值保存为整数,并在表的`.frm`文件中保存"数字-字符串"映射关系的"查找表";
    
    (2). 枚举字段是按照内部存储的整数而不是定义的字符串进行排序的;

### 4.1.4 日期和时间类型
1. DATETIME
 - 范围: 1001 ~ 9999, 精度为秒, 8字节存储;
2. TIMESTAMP(除特殊行为外, 应尽量使用)
 - 范围: 1970 ~2038, 4字节存储, 默认为NOT NULL;
3. 如果需要存储比秒更小粒度的日期和时间值怎么办?
 - 可以使用BIGINT类型存储微秒级别的时间戳;
 - 使用DOUBLE存储秒之后的小数位;
 - 使用MariaDB代替MySQL

### 4.1.5 位数据类型
- to be continued

### 4.1.6 选择标示符
1. 小技巧 
    - 整数通常是标识列最好的选择;
    - enum 和 set类型通常是糟糕的选择;
    - 字符串类型, 应该尽量避免, 很消耗空间, 通常比数字类型慢;
    - 如果存储的是UUID, 更好的做法用UNHEX()函数转换UUID值为16字节的数字, 并且存储在BINARY(16)中, 检索时可以通过HEX()函数来格式化为十六进制格式;

### 4.1.7 特殊类型数据
- 某些类型的数据并不直接与内置类型一致, 比如IPv4地址, 人们常用varchar(15)来存储IP地址, 然而, 他们实际上是32位无符号整数, 不是字符串, 所以应该用无符号整数存储IP地址, MySQL提供INET_ATON()和INET_NTOA(), 以用于在两种表示方法之间转换;

## 4.2 MySQL schema 设计中的缺陷
- 太多的列
- 太多的关联(粗略的经验法则, 如果希望查询执行的快速且并发性能好, 单个的查询组好在12张表以内做关联)
- 过度的枚举类型
- 变相的枚举(set类型)
- NULL 相关(即使需要存储一个事实上的的"空值", 也许可以使用0, 某个特殊值, 或者空字符串)

## 4.3 范式和反范式
### 4.3.1 范式的优点和缺点
 - 优点
 ~~~
    （1）范式化的更新操作通常比反范式化要快；
    （2）较好的范式化， 就只有很少或者没有重复数据；
    （3）范式化的表通常更小， 可以更好的放入内存， 所以执行操作会更快；
 ~~~
 - 缺点
 ~~~
    （1）范式化的设计通常需要关联，甚至是多次关联， 不但代价昂贵， 甚至可能导致一些索引策略无效；
 ~~~

### 4.3.2 反范式的优点和缺点
- P130的例子值得一看；

### 4.3.3 混用范式化和反范式化
- 最常见的反范式化数据的方法是复制或者缓存；

## 4.4 缓存表和汇总表
- 有时提升性能最好的方法是在同一张表中保存衍生的冗余数据；
- P132的例子值得一看；

    ### 4.4.1 物化视图
    - pass
    ### 4.4.2 计数器表
    - P135的例子值得一看

## 4.5 加快ALTER TABLE 操作的速度
 - mysql 的 ALTER TABLE操作的性能对大表来说是个大问题；
 - 常见的场景， 能使用的技巧只有两种：
    ~~~
    （1）. 先在一台不提供服务的机器上执行ALTER TABLE，然后和提供服务的主库进行切换；
    （2）. “影子拷贝”
    ~~~
- 不是所有的ALTER TABLE操作都会引起表重建，例如， 有两种方法可以改变或者删除一个列的默认值（例子P137）
    ### 4.5.1 只修改 .frm文件， 例子P138
    - 以下操作是有可能不需要重建表的：
    ~~~
        (1). 移除(不是增加)一个列的AUTO_INCREMENT属性;
        (2). 增加、移除或更改ENUM 和 SET常量
    ~~~
    ### 4.5.2 快速创建MyISAM
    - 为了高效的载入数据到MyISAM表中，有一个常用的技巧是先禁用索引、载入数据，然后重启索引；
    
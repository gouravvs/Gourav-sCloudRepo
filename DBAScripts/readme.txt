This readme file contains details and names of all the DBA related scripts 
Instance level queries which has to be executed on master database 
and 
Database level queries which has to be executed on each user database as per the requirement .

Instance level scripts :

1. BlockingChainStatus    --- Check Blocking Chains 
2. CriticalLogs24hrs      --- Check Critical logs for past 24 hrs ,
3. CurrentRunningQueries  --- Live running Queries , (You can also add a time limit such as  queries taking longer than 5 mins )
4. DatabaseStatus         --- Shows basic details of databases like status, compatibility , collatoin etc
5. DeadlockCount          --- Gives no of deadlocks in last 1 day
6. DeadlockSummary        --- Details of the deadlocks from deadlock report
7. MemoryConfigCheck      --- Checks OS and SQL memory 
8. SQLAgentJobsHealth     --- Detials of Jobs from SQL sever agent
9. SQLAgentsstatus        --- Staus of SQL agent in running or stopped state
10.SQLserverUptime        --- Shows the Uptime( time from last start) of the SQL server
11.TOP_IO_cosumingqueries --- TOP 200 IO consuming queries (historical)
12.TOP_IO_cosumptionLive  --- Live IO conuming Queries
13.TOPCPUConsumingQueries --- TOP 20 CPU consuming Queries (historical)
14.TOPCPUConsumptionLive  --- Live CPU consuming Queries 

Database level (To be executed per database ):

1. Fragmentationdetails   --- Shows Fragemtation detials of indexes in a database 
2. MissingIndexes         --- Shows the Missing indexes as per SQL server decided by query plans internally 
3. StatisticsDetails      --- Shows Statistics Details per database and last time it was updated  
4. UnusedIndexes          --- Shows deatils of indexes which as not used much frequently or never used  

/* How do I change a SQL timestamp to unix time ? */

According to Wikipedia,
UNIX time is the number of seconds elapsed since 1st Jan 1970
(not including leap seconds).

Bearing that in mind,
it should just be the difference between
1970-01-01 and your time, in seconds:

SELECT time1,
       Datediff(SECOND, '1970-01-01', time1) AS time1_to_unixtime
FROM   mytable;

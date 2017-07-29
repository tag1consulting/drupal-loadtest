#!/usr/bin/env bash

# Pass the script a tag to identify this testrun (e.g. memcache module version being tested)
TAG=$1

if [ "$TAG" == "" ]
then
  echo "You must pass a tag to the script -- will be appeneded to the output directory for this test."
  exit 1
fi

DOMAIN="http://loadtest.dev"

LOCUST=/usr/local/bin/locust
LOCUST_PLAN=/root/drupal-loadtest/locust_testplan.py

RESTART_MYSQL="/usr/local/etc/rc.d/mysql-server restart"
RESTART_APACHE="service apache24 restart"
RESTART_MEMCACHED="service memcached restart"

USERS=100
RAMPUP=10
REQUESTS=50000

DATE=`date +%d-%m-%y--%H:%M:%S-$TAG`
WEBROOT="/var/www/html"
OUTPUT="$WEBROOT/$DATE"

mkdir $OUTPUT

NC="/usr/bin/nc -N"

IPADDR="ConfigureMe"

# This is output by preptest.sh...
SQL_DUMP=/root/drupal_with_test_content.sql.gz
DB_NAME=drupal6loadtest

# Load the database into MySQL so each test starts with the same base data.
echo "Reloading DB, this will likely take a few minutes..."
mysql -e "DROP DATABASE $DB_NAME"
mysql -e "CREATE DATABASE $DB_NAME"
gunzip -c $SQL_DUMP | mysql $DB_NAME

$RESTART_MYSQL 2>&1 > $OUTPUT/mysql_restart.log
$RESTART_APACHE 2>&1 > $OUTPUT/apache_restart.log
$RESTART_MEMCACHED 2>&1 > $OUTPUT/memcached_restart.log

# Run loadtest
echo $LOCUST -f $LOCUST_PLAN --host=$DOMAIN --no-web -c $USERS -r $RAMPUP -n $REQUESTS --only-summary --logfile=$OUTPUT/locust.log
$LOCUST -f $LOCUST_PLAN --host=$DOMAIN --no-web -c $USERS -r $RAMPUP -n $REQUESTS --only-summary --logfile=$OUTPUT/locust.log > $OUTPUT/locust.txt 2>&1

rm -f "$WEBROOT/latest"
ln -s $OUTPUT "$WEBROOT/latest"

# Add .htaccess to override Drupal's default of disabling indexes.
echo "Options +Indexes" > $WEBROOT/latest/.htaccess
echo 'stats' | $NC localhost 11211 > "$WEBROOT/latest/memcached.stats.txt"

SUMMARY="$WEBROOT/latest/summary.tsv"

grep "STAT total_connections" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' > $SUMMARY 2>&1
grep "STAT cmd_get" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT cmd_set" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT get_hits" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT get_misses" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT delete_hits" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT delete_misses" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT incr_hits" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT bytes_read" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT bytes_written" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT evictions" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1
grep "STAT total_items" "$WEBROOT/latest/memcached.stats.txt" | awk '{print "\"" $2 "\"	" $3}' >> $SUMMARY 2>&1

echo >> $SUMMARY 2>&1

GETS=`grep "STAT cmd_get" "$WEBROOT/latest/memcached.stats.txt" | awk '{print $3}' | tr -d '\r\n\f'` >> $SUMMARY 2>&1
HITS=`grep "STAT get_hits" "$WEBROOT/latest/memcached.stats.txt" | awk '{print $3}' | tr -d '\r\n\f'` >> $SUMMARY 2>&1
MISSES=`grep "STAT get_misses" "$WEBROOT/latest/memcached.stats.txt" | awk '{print $3}' | tr -d '\r\n\f'` >> $SUMMARY 2>&1
RATE=`echo "scale=4;$HITS / $GETS * 100" | bc` >> $SUMMARY 2>&1
echo "\"Hit rate\"	$RATE%" >> $SUMMARY 2>&1
RATE=`echo "scale=4;$MISSES / $GETS * 100" | bc` >> $SUMMARY 2>&1
echo "\"Miss rate\"	$RATE%" >> $SUMMARY 2>&1

echo >> $SUMMARY 2>&1

echo "Type	Total	Err	ms (Average)	ms (Max)	Rate" >> $SUMMARY 2>&1

ANON_GET_FRONTPAGE=`grep Anonymous $OUTPUT/locust.txt  | grep Front | head -1 | awk '{print $5}'`
ANON_GET_FRONTPAGE_ERR=`grep Anonymous $OUTPUT/locust.txt  | grep Front | head -1 | awk '{print $6}'`
ANON_GET_FRONTPAGE_AVG=`grep Anonymous $OUTPUT/locust.txt  | grep Front | head -1 | awk '{print $7}'`
ANON_GET_FRONTPAGE_MAX=`grep Anonymous $OUTPUT/locust.txt  | grep Front | head -1 | awk '{print $9}'`
ANON_GET_FRONTPAGE_REQ=`grep Anonymous $OUTPUT/locust.txt  | grep Front | head -1 | awk '{print $12}'`
echo "\"Anon frontpage\"	$ANON_GET_FRONTPAGE	$ANON_GET_FRONTPAGE_ERR	$ANON_GET_FRONTPAGE_AVG	$ANON_GET_FRONTPAGE_MAX	$ANON_GET_FRONTPAGE_REQ" >> $SUMMARY 2>&1

ANON_GET_NODE=`grep Anonymous $OUTPUT/locust.txt  | grep nid | head -1 | awk '{print $4}'`
ANON_GET_NODE_ERR=`grep Anonymous $OUTPUT/locust.txt  | grep nid | head -1 | awk '{print $5}'`
ANON_GET_NODE_AVG=`grep Anonymous $OUTPUT/locust.txt  | grep nid | head -1 | awk '{print $6}'`
ANON_GET_NODE_MAX=`grep Anonymous $OUTPUT/locust.txt  | grep nid | head -1 | awk '{print $8}'`
ANON_GET_NODE_REQ=`grep Anonymous $OUTPUT/locust.txt  | grep nid | head -1 | awk '{print $11}'`
echo "\"Anon node\"	$ANON_GET_NODE	$ANON_GET_NODE_ERR	$ANON_GET_NODE_AVG	$ANON_GET_NODE_MAX	$ANON_GET_NODE_REQ" >> $SUMMARY 2>&1

ANON_GET_PROFILE=`grep Anonymous $OUTPUT/locust.txt  | grep uid | head -1 | awk '{print $4}'`
ANON_GET_PROFILE_ERR=`grep Anonymous $OUTPUT/locust.txt  | grep uid | head -1 | awk '{print $5}'`
ANON_GET_PROFILE_AVG=`grep Anonymous $OUTPUT/locust.txt  | grep uid | head -1 | awk '{print $6}'`
ANON_GET_PROFILE_MAX=`grep Anonymous $OUTPUT/locust.txt  | grep uid | head -1 | awk '{print $8}'`
ANON_GET_PROFILE_REQ=`grep Anonymous $OUTPUT/locust.txt  | grep uid | head -1 | awk '{print $11}'`
echo "\"Anon profile\"	$ANON_GET_PROFILE	$ANON_GET_PROFILE_ERR	$ANON_GET_PROFILE_AVG	$ANON_GET_PROFILE_MAX	$ANON_GET_PROFILE_REQ" >> $SUMMARY 2>&1

AUTH_GET_LOGIN=`grep Auth $OUTPUT/locust.txt  | grep Comment | head -1 | awk '{print $5}'`
AUTH_GET_LOGIN_ERR=`grep Auth $OUTPUT/locust.txt  | grep Comment | head -1 | awk '{print $6}'`
AUTH_GET_LOGIN_AVG=`grep Auth $OUTPUT/locust.txt  | grep Comment | head -1 | awk '{print $7}'`
AUTH_GET_LOGIN_MAX=`grep Auth $OUTPUT/locust.txt  | grep Comment | head -1 | awk '{print $9}'`
AUTH_GET_LOGIN_REQ=`grep Auth $OUTPUT/locust.txt  | grep Comment | head -1 | awk '{print $12}'`
echo "\"Anon load login form\"	$AUTH_GET_LOGIN	$AUTH_GET_LOGIN_ERR	$AUTH_GET_LOGIN_AVG	$AUTH_GET_LOGIN_MAX	$AUTH_GET_LOGIN_REQ" >> $SUMMARY 2>&1

AUTH_POST_LOGIN=`grep Auth $OUTPUT/locust.txt  | grep Posting | head -1 | awk '{print $5}'`
AUTH_POST_LOGIN_ERR=`grep Auth $OUTPUT/locust.txt  | grep Posting | head -1 | awk '{print $6}'`
AUTH_POST_LOGIN_AVG=`grep Auth $OUTPUT/locust.txt  | grep Posting | head -1 | awk '{print $7}'`
AUTH_POST_LOGIN_MAX=`grep Auth $OUTPUT/locust.txt  | grep Posting | head -1 | awk '{print $9}'`
AUTH_POST_LOGIN_REQ=`grep Auth $OUTPUT/locust.txt  | grep Posting | head -1 | awk '{print $12}'`
echo "\"Auth post login\"	$AUTH_POST_LOGIN	$AUTH_POST_LOGIN_ERR	$AUTH_POST_LOGIN_AVG	$AUTH_POST_LOGIN_MAX	$AUTH_POST_LOGIN_REQ" >> $SUMMARY 2>&1

AUTH_GET_NODE=`grep Auth $OUTPUT/locust.txt  | grep nid | head -1 | awk '{print $4}'`
AUTH_GET_NODE_ERR=`grep Auth $OUTPUT/locust.txt  | grep nid | head -1 | awk '{print $5}'`
AUTH_GET_NODE_AVG=`grep Auth $OUTPUT/locust.txt  | grep nid | head -1 | awk '{print $6}'`
AUTH_GET_NODE_MAX=`grep Auth $OUTPUT/locust.txt  | grep nid | head -1 | awk '{print $8}'`
AUTH_GET_NODE_REQ=`grep Auth $OUTPUT/locust.txt  | grep nid | head -1 | awk '{print $11}'`
echo "\"Auth node\"	$AUTH_GET_NODE	$AUTH_GET_NODE_ERR	$AUTH_GET_NODE_AVG	$AUTH_GET_NODE_MAX	$AUTH_GET_NODE_REQ" >> $SUMMARY 2>&1

AUTH_GET_PROFILE=`grep Auth $OUTPUT/locust.txt  | grep uid | head -1 | awk '{print $4}'`
AUTH_GET_PROFILE_ERR=`grep Auth $OUTPUT/locust.txt  | grep uid | head -1 | awk '{print $5}'`
AUTH_GET_PROFILE_AVG=`grep Auth $OUTPUT/locust.txt  | grep uid | head -1 | awk '{print $6}'`
AUTH_GET_PROFILE_MAX=`grep Auth $OUTPUT/locust.txt  | grep uid | head -1 | awk '{print $8}'`
AUTH_GET_PROFILE_REQ=`grep Auth $OUTPUT/locust.txt  | grep uid | head -1 | awk '{print $11}'`
echo "\"Auth profile\"	$AUTH_GET_PROFILE	$AUTH_GET_PROFILE_ERR	$AUTH_GET_PROFILE_AVG	$AUTH_GET_PROFILE_MAX	$AUTH_GET_PROFILE_REQ" >> $SUMMARY 2>&1

AUTH_GET_FRONTPAGE=`grep Auth $OUTPUT/locust.txt  | grep Front | head -1 | awk '{print $5}'`
AUTH_GET_FRONTPAGE_ERR=`grep Auth $OUTPUT/locust.txt  | grep Front | head -1 | awk '{print $6}'`
AUTH_GET_FRONTPAGE_AVG=`grep Auth $OUTPUT/locust.txt  | grep Front | head -1 | awk '{print $7}'`
AUTH_GET_FRONTPAGE_MAX=`grep Auth $OUTPUT/locust.txt  | grep Front | head -1 | awk '{print $9}'`
AUTH_GET_FRONTPAGE_REQ=`grep Auth $OUTPUT/locust.txt  | grep Front | head -1 | awk '{print $12}'`
echo "\"Auth frontpage\"	$AUTH_GET_FRONTPAGE	$AUTH_GET_FRONTPAGE_ERR	$AUTH_GET_FRONTPAGE_AVG	$AUTH_GET_FRONTPAGE_MAX	$AUTH_GET_FRONTPAGE_REQ" >> $SUMMARY 2>&1

AUTH_GET_COMMENT=`grep Auth $OUTPUT/locust.txt  | grep Comment | head -1 | awk '{print $5}'`
AUTH_GET_COMMENT_ERR=`grep Auth $OUTPUT/locust.txt  | grep Comment | head -1 | awk '{print $6}'`
AUTH_GET_COMMENT_AVG=`grep Auth $OUTPUT/locust.txt  | grep Comment | head -1 | awk '{print $7}'`
AUTH_GET_COMMENT_MAX=`grep Auth $OUTPUT/locust.txt  | grep Comment | head -1 | awk '{print $9}'`
AUTH_GET_COMMENT_REQ=`grep Auth $OUTPUT/locust.txt  | grep Comment | head -1 | awk '{print $12}'`
echo "\"Auth comment form\"	$AUTH_GET_COMMENT	$AUTH_GET_COMMENT_ERR	$AUTH_GET_COMMENT_AVG	$AUTH_GET_COMMENT_MAX	$AUTH_GET_COMMENT_REQ" >> $SUMMARY 2>&1

AUTH_POST_COMMENT=`grep Auth $OUTPUT/locust.txt  | grep Posting | head -1 | awk '{print $5}'`
AUTH_POST_COMMENT_ERR=`grep Auth $OUTPUT/locust.txt  | grep Posting | head -1 | awk '{print $6}'`
AUTH_POST_COMMENT_AVG=`grep Auth $OUTPUT/locust.txt  | grep Posting | head -1 | awk '{print $7}'`
AUTH_POST_COMMENT_MAX=`grep Auth $OUTPUT/locust.txt  | grep Posting | head -1 | awk '{print $9}'`
AUTH_POST_COMMENT_REQ=`grep Auth $OUTPUT/locust.txt  | grep Posting | head -1 | awk '{print $12}'`
echo "\"Auth post comment\"	$AUTH_POST_COMMENT	$AUTH_POST_COMMENT_ERR	$AUTH_POST_COMMENT_AVG	$AUTH_POST_COMMENT_MAX	$AUTH_POST_COMMENT_REQ" >> $SUMMARY 2>&1

STATIC_FILE=`grep GET $OUTPUT/locust.txt  | grep Static | head -1 | awk '{print $4}'`
STATIC_FILE_ERR=`grep GET $OUTPUT/locust.txt  | grep Static | head -1 | awk '{print $5}'`
STATIC_FILE_AVG=`grep GET $OUTPUT/locust.txt  | grep Static | head -1 | awk '{print $6}'`
STATIC_FILE_MAX=`grep GET $OUTPUT/locust.txt  | grep Static | head -1 | awk '{print $8}'`
STATIC_FILE_REQ=`grep GET $OUTPUT/locust.txt  | grep Static | head -1 | awk '{print $11}'`
echo "\"Static file\"	$STATIC_FILE	$STATIC_FILE_ERR	$STATIC_FILE_AVG	$STATIC_FILE_MAX	$STATIC_FILE_REQ" >> $SUMMARY 2>&1

TOTAL=`grep Total $OUTPUT/locust.txt  | head -1 | awk '{print $2}'`
TOTAL_ERR=`grep Total $OUTPUT/locust.txt  | head -1 | awk '{print $3}'`
TOTAL_AVG=`grep Total $OUTPUT/locust.txt  | head -1 | awk '{print $99}'`
TOTAL_MAX=`grep Total $OUTPUT/locust.txt  | head -1 | awk '{print $99}'`
TOTAL_REQ=`grep Total $OUTPUT/locust.txt  | head -1 | awk '{print $4}'`
echo "\"Total\"	$TOTAL	$TOTAL_ERR	$TOTAL_AVG	$TOTAL_MAX	$TOTAL_REQ" >> $SUMMARY 2>&1

echo >> $SUMMARY 2>&1

cat $SUMMARY

echo "Complete results can be found in $WEBROOT/latest."
echo "Or at http://$IPADDR/$DATE"
echo "TSV-formatted summary at http://$IPADDR/$DATE/summary.tsv"

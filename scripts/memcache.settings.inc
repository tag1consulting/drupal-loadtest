
// Memcached settings.
$conf['cache_inc'] ='sites/all/modules/memcache/memcache.inc';
$conf['lock_inc'] = 'sites/all/modules/memcache/memcache-lock.inc';
$conf['memcache_stampede_protection'] = TRUE;
// The 'cache_form' bin must be assigned to non-volatile storage.
$conf['memcache_bins']['cache_form'] = 'database';

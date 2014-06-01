
// Memcached settings.
$conf['cache_backends'][] = 'sites/default/modules/memcache/memcache.inc';
$conf['lock_inc'] = 'sites/default/modules/memcache/memcache-lock.inc';
$conf['memcache_stampede_protection'] = TRUE;
$conf['cache_default_class'] = 'MemCacheDrupal';

// The 'cache_form' bin must be assigned no non-volatile storage.
$conf['cache_class_cache_form'] = 'DrupalDatabaseCache';

/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(redis_server(?,?,?), redis, redis).
index(redis_connect(?), redis, redis).
index(redis_connect(?,?,?), redis, redis).
index(redis_disconnect(?), redis, redis).
index(redis_disconnect(?,?), redis, redis).
index(redis(?), redis, redis).
index(redis(?,?), redis, redis).
index(redis(?,?,?), redis, redis).
index(redis_get_list(?,?,?), redis, redis).
index(redis_get_list(?,?,?,?), redis, redis).
index(redis_set_list(?,?,?), redis, redis).
index(redis_get_hash(?,?,?), redis, redis).
index(redis_set_hash(?,?,?), redis, redis).
index(redis_scan(?,?,?), redis, redis).
index(redis_sscan(?,?,?,?), redis, redis).
index(redis_hscan(?,?,?,?), redis, redis).
index(redis_zscan(?,?,?,?), redis, redis).
index(redis_subscribe(?,?,?,?), redis, redis).
index(redis_subscribe(?,?), redis, redis).
index(redis_unsubscribe(?,?), redis, redis).
index(redis_current_subscription(?,?), redis, redis).
index(redis_write(?,?), redis, redis).
index(redis_read(?,?), redis, redis).
index(redis_array_dict(?,?,?), redis, redis).
index(redis_property(?,?), redis, redis).
index(redis_current_command(?,?), redis, redis).
index(redis_current_command(?,?,?), redis, redis).
index(sentinel_slave(?,?,?,?), redis, redis).
index(xstream_set(?,?,?), redis_streams, redis_streams).
index(xadd(?,?,?,?), redis_streams, redis_streams).
index(xlisten(?,?,?), redis_streams, redis_streams).
index(xlisten_group(?,?,?,?,?), redis_streams, redis_streams).
index(xconsumer_stop(?), redis_streams, redis_streams).

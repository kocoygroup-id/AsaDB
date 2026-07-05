/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(stomp_connection(+,+,+,4,-), stomp, stomp).
index(stomp_connection(+,+,+,4,-,+), stomp, stomp).
index(stomp_connection_property(?,?), stomp, stomp).
index(stomp_destroy_connection(?), stomp, stomp).
index(stomp_connect(?), stomp, stomp).
index(stomp_connect(?,?), stomp, stomp).
index(stomp_teardown(?), stomp, stomp).
index(stomp_reconnect(?), stomp, stomp).
index(stomp_send(?,?,?,?), stomp, stomp).
index(stomp_send_json(?,?,?,?), stomp, stomp).
index(stomp_subscribe(?,?,?,?), stomp, stomp).
index(stomp_unsubscribe(?,?), stomp, stomp).
index(stomp_ack(?,?), stomp, stomp).
index(stomp_nack(?,?), stomp, stomp).
index(stomp_ack(?,?,?), stomp, stomp).
index(stomp_nack(?,?,?), stomp, stomp).
index(stomp_transaction(+,0), stomp, stomp).
index(stomp_disconnect(?,?), stomp, stomp).
index(stomp_begin(?,?), stomp, stomp).
index(stomp_commit(?,?), stomp, stomp).
index(stomp_abort(?,?), stomp, stomp).
index(stomp_setup(?,?), stomp, stomp).

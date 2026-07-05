/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(paxos_get(?), paxos, paxos).
index(paxos_get(?,?), paxos, paxos).
index(paxos_get(?,?,?), paxos, paxos).
index(paxos_set(?), paxos, paxos).
index(paxos_set(?,?), paxos, paxos).
index(paxos_set(?,?,?), paxos, paxos).
index(paxos_on_change(?,0), paxos, paxos).
index(paxos_on_change(?,?,0), paxos, paxos).
index(paxos_initialize(?), paxos, paxos).
index(paxos_admin_key(?,?), paxos, paxos).
index(paxos_property(?), paxos, paxos).
index(paxos_quorum_ask(?,?,?,?), paxos, paxos).
index(paxos_replicate_key(?,?,?), paxos, paxos).

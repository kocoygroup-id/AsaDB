/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(protobuf_message(?,?), protobufs, protobufs).
index(protobuf_message(?,?,?), protobufs, protobufs).
index(protobuf_parse_from_codes(?,?,?), protobufs, protobufs).
index(protobuf_serialize_to_codes(?,?,?), protobufs, protobufs).
index(protobuf_field_is_map(?,?), protobufs, protobufs).
index(protobuf_map_pairs(?,?,?), protobufs, protobufs).

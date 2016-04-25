psql_import () {
  docker run -it --link revine_postgres_1:postgres -v $1:/temp --rm postgres sh -c \
    'exec psql -h "$POSTGRES_PORT_5432_TCP_ADDR" -p "$POSTGRES_PORT_5432_TCP_PORT" -U postgres revine_development < /temp/$2'
}

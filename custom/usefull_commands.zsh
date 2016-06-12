psql_import () {
  echo 'Arguments should be $1:container $2:folder_containing_dump $3:dump_file_name'
  docker run -it --link $1:postgres -v $2:/temp --rm postgres sh -c \
    'exec psql -h "$POSTGRES_PORT_5432_TCP_ADDR" -p "$POSTGRES_PORT_5432_TCP_PORT" -U postgres revine_development < /temp/'$3
}

mongo_import () {
  echo 'Arguments should be $1:container $2:folder_containing_dump $3:database_to_import_to'
  docker run -it --link $1:mongo -v $2:/temp --rm mongo mongorestore --host mongo -d $3 /temp
}

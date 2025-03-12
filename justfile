
# Run in debug mode
watch:
    watchexec -c -N -w src/views -w src -- crystal run src/bcv-kemal.cr

debug:
    crystal run src/bcv-kemal.cr

prod:
    KEMAL_ENV=production crystal run src/bcv-kemal.cr --release -O3

build-prod:
    KEMAL_ENV=production crystal build src/bcv-kemal.cr -o bcv-kemal --release -O3

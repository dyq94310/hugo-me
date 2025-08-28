# build web
docker compose --profile build run --rm hugo hugo --minify

#
cp -r public/ ~/docker/nginx-compose/
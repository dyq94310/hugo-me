# build web
docker compose --profile build run --rm hugo hugo --minify

#
echo "cp public site to ngixn"
cp -r public/ ~/docker/nginx-compose/
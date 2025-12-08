# build web
docker compose --profile build run --rm hugo hugo --minify

#
echo "cp public site to ngixn"
rsync -avz --delete  ./public/ /opt/k3s-data/nginx-compose/public/
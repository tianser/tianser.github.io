git checkout dev -- public
ls public/ |xargs -n 1 -i cp public/{} ./ -rf
rm public -rf

git add --all .
git commit -s -m "add post"
git push

git checkout dev

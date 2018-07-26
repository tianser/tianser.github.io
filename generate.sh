git checkout dev -- public
mv -T public/* ./ -bf  
git add --all .
git commit -s -m "add post"
git push

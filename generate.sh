git checkout dev -- public
\mv public/* ./ -bf  
git add --all .
git commit -s -m "add post"
git push

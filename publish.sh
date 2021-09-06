# 自动发布脚本
#!/bin/sh

DATE=`date +"%Y-%m-%d %H:%M:%S"`

hexo clean
hexo g
git add *
git commit -m "${DATE}"
git push

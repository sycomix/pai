#!/bin/bash

# Copyright (c) Microsoft Corporation
# All rights reserved.
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
# documentation files (the "Software"), to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
# to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

pushd $(dirname "$0") > /dev/null

if [ -d "../dependency" ]; then
    rm -rf "../dependency"
fi

mkdir -p "../dependency/package-cache"
ROOT_DIR=$(cd "../dependency/package-cache"; pwd)

if hash sudo 2>/dev/null; then
  # if sudo exists, use `sudo docker` instead of `docker`.
  alias docker='sudo docker'
fi

while IFS= read -r line || [[ -n "$line" ]] ;
do
    start_char=`echo $line | cut -b 1`
    if [ ! "$start_char" == "#" ]; then
      name=`echo $line | cut -d , -f 1`
      os=`echo $line | cut -d , -f 2`
      packages=`echo $line | cut -d , -f 3`
      precommands=`echo $line | cut -d , -f 4`
      echo "name: ${name} os: ${os} packages: ${packages}"
      if [ "$os" == "ubuntu16.04" -o "$os" == "ubuntu18.04" ]; then
        if [ "$os" == "ubuntu16.04" ]; then
          base_image="ubuntu:16.04"
        fi
        if [ "$os" == "ubuntu18.04" ]; then
          base_image="ubuntu:18.04"
        fi
        package_dir=$ROOT_DIR"/${name}-${os}"
        mkdir -p $package_dir
        echo $packages > $package_dir"/packages"
        echo $precommands > $package_dir"/precommands.sh"
        docker run -i -v $package_dir:/mount $base_image \
          /bin/bash  << EOF_DOCKER
                     apt-get update
                     apt-get -y install --print-uris \`cat /mount/packages\` | cut -d " " -f 1-2 | grep http:// > /aptinfo && \
                     cat /aptinfo | cut -d\' -f 2 > /apturl && \
                     apt-get -y install wget && \
                     wget -i /apturl --tries 3 -P /mount && \
                     cat /aptinfo | cut -d " " -f 2 > /mount/order
EOF_DOCKER
      else
        echo "Only os=ubuntu16.04 or os=ubuntu18.04 is supported! Found: $os"
        exit 1
      fi
    fi
done < "package-cache-info"

echo "hello" > "../dependency/x"

popd > /dev/null

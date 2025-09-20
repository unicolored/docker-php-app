#! /bin/bash

docker build -t my-php-starter:8.3 . && docker run -p 8080:80 my-php-starter:8.3

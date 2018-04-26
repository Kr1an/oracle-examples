from node:9.10.0

workdir /app

copy package*.json ./
copy bower*.json ./

run npm install
run ./node_modules/.bin/bower install --allow-root

copy . .

expose 80

cmd ["npm", "start"]

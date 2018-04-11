from node:9.10.0

workdir /app

copy package*.json ./

run npm install

copy . .

expose 80

cmd ["npm", "start"]

FROM node:erbium-buster-slim

WORKDIR /source

# copy depency lists separately to allow for Docker caching
COPY package.json /source/package.json
COPY package-lock.json /source/package-lock.json
RUN npm install

CMD npm run build

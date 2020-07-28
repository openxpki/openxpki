FROM node:erbium-buster-slim

WORKDIR /

# copy depency lists separately to allow for Docker caching
COPY package.json /package.json
COPY package-lock.json /package-lock.json
RUN npm install

WORKDIR /source
CMD npm run build

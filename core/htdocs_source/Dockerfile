FROM node:erbium-buster-slim

WORKDIR /source

# copy depency lists separately to allow for Docker caching
COPY package.json /source/package.json
COPY package-lock.json /source/package-lock.json
RUN npm install

# now copy the rest
COPY . /source

CMD npm run build

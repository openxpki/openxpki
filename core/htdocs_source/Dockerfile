FROM node

RUN npm install -g ember-cli
WORKDIR /source
COPY package.json /source/package.json
RUN npm install 
CMD ember build --environment production
COPY . /source

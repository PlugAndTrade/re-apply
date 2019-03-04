FROM node:8 as build
USER root
RUN apt-get update && apt-get install -y curl git
RUN npm install -g esy@0.4.7 --unsafe-perm=true

WORKDIR /app
COPY . .
RUN esy install
RUN esy build

FROM debian:latest
WORKDIR /usr/local/bin
COPY --from=build /app/_build/default/bin/rapply.exe .

ENTRYPOINT ["/usr/local/bin/rapply.exe"]

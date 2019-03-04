FROM node:8-stretch as build
USER root
RUN apt-get update && apt-get install -y curl git
RUN npm install -g esy@0.4.7 --unsafe-perm=true

ENV KUBE_LATEST_VERSION="v1.13.4"
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
&& chmod +x /usr/local/bin/kubectl

WORKDIR /app
COPY . .
RUN esy install && esy build

FROM debian:latest
COPY --from=build /app/_build/default/bin/rapply.exe /usr/local/bin/rapply
COPY --from=build /usr/local/bin/kubectl /usr/local/bin/kubectl

ENTRYPOINT ["/usr/local/bin/rapply"]
CMD ["--help"]
